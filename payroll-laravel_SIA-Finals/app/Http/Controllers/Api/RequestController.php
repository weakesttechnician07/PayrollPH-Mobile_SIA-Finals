<?php
// ============================================================
// app/Http/Controllers/Api/RequestController.php
// Employee: submit requests
// Manager: approve/reject leave & absence
// Admin:   approve/reject all requests
// ============================================================
namespace App\Http\Controllers\Api;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RequestController extends Controller
{
    private function handledBy(string $type): string {
        return in_array($type,['Name Change','Email Change','Other']) ? 'Admin' : 'Manager';
    }

    /** GET /api/requests?status=Pending */
    public function index(Request $request)
    {
        $status = $request->get('status','Pending');
        $query  = DB::table('vw_requests')->where('status',$status);

        if ($request->user()->role === 'Employee') {
            $emp = DB::table('employees')->where('email',$request->user()->username)->first();
            if (!$emp) return response()->json(['success'=>true,'data'=>[]]);
            $query->where('employee_id',$emp->employee_id);
        } elseif ($request->user()->role === 'Manager') {
            $query->where('handled_by','Manager');
        }

        return response()->json(['success'=>true,'data'=>$query->get()]);
    }

    /** GET /api/requests/pending-count */
    public function pendingCount(Request $request)
    {
        $role = $request->user()->role;
        if ($role === 'Admin') {
            $count = DB::table('requests')->where('status','Pending')->count();
        } elseif ($role === 'Manager') {
            $count = DB::table('requests')->where('status','Pending')->where('handled_by','Manager')->count();
        } else {
            $emp   = DB::table('employees')->where('email',$request->user()->username)->first();
            $count = $emp ? DB::table('requests')->where('employee_id',$emp->employee_id)->where('status','Pending')->count() : 0;
        }
        return response()->json(['success'=>true,'count'=>$count]);
    }

    /** POST /api/requests — Employee submits */
    public function store(Request $request)
    {
        if ($request->user()->role !== 'Employee') {
            return response()->json(['success'=>false,'message'=>'Employee role only.'],403);
        }
        $request->validate([
            'request_type' => 'required|in:Leave - Sick,Leave - Vacation,Absence Excuse,Name Change,Email Change,Other',
            'details'      => 'required|string|min:10',
        ]);
        $emp = DB::table('employees')->where('email',$request->user()->username)->first();
        if (!$emp) return response()->json(['success'=>false,'message'=>'No employee record linked.'],404);

        DB::table('requests')->insert([
            'employee_id'  => $emp->employee_id,
            'request_type' => $request->request_type,
            'details'      => $request->details,
            'handled_by'   => $this->handledBy($request->request_type),
            'status'       => 'Pending',
            'created_at'   => now(),
        ]);
        AuditLog::create(['user_id'=>$request->user()->user_id,'username'=>$request->user()->username,'action'=>'Submit Request','target'=>'requests','detail'=>"Type={$request->request_type}",'ip_address'=>$request->ip()]);
        return response()->json(['success'=>true,'message'=>'Request submitted. Your '.$this->handledBy($request->request_type).' will review it.'],201);
    }

    /** PUT /api/requests/{id} — Manager/Admin review */
    public function review(Request $request, $id)
    {
        if ($request->user()->role === 'Employee') {
            return response()->json(['success'=>false,'message'=>'Not authorized.'],403);
        }
        $request->validate([
            'action'      => 'required|in:approve,reject',
            'review_note' => 'nullable|string',
        ]);
        $req = DB::table('requests')->where('request_id',$id)->first();
        if (!$req) return response()->json(['success'=>false,'message'=>'Request not found.'],404);
        if ($req->status !== 'Pending') return response()->json(['success'=>false,'message'=>'Already reviewed.'],422);
        if ($request->user()->role === 'Manager' && $req->handled_by !== 'Manager') {
            return response()->json(['success'=>false,'message'=>'This request requires Admin approval.'],403);
        }

        $newStatus = $request->action === 'approve' ? 'Approved' : 'Rejected';
        DB::beginTransaction();
        try {
            DB::table('requests')->where('request_id',$id)->update([
                'status'        => $newStatus,
                'reviewed_by'   => $request->user()->user_id,
                'reviewer_name' => $request->user()->full_name,
                'review_note'   => $request->review_note,
                'reviewed_at'   => now(),
            ]);
            // If approved leave/absence → reduce days_absent
            if ($newStatus==='Approved' && in_array($req->request_type,['Leave - Sick','Leave - Vacation','Absence Excuse'])) {
                DB::table('attendance')
                    ->where('employee_id',$req->employee_id)
                    ->where('attendance_month',now()->month)
                    ->where('attendance_year', now()->year)
                    ->update(['days_absent'=>DB::raw('GREATEST(0, days_absent - 1)')]);
            }
            DB::commit();
            AuditLog::create(['user_id'=>$request->user()->user_id,'username'=>$request->user()->username,'action'=>'Review Request','target'=>'requests','detail'=>"req_id=$id status=$newStatus",'ip_address'=>$request->ip()]);
            return response()->json(['success'=>true,'message'=>"Request #$id $newStatus."]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['success'=>false,'message'=>$e->getMessage()],500);
        }
    }
}
