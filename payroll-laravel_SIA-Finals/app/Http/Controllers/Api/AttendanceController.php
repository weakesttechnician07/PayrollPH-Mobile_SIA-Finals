<?php
// ============================================================
// app/Http/Controllers/Api/AttendanceController.php
// ============================================================
namespace App\Http\Controllers\Api;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AttendanceController extends Controller
{
    /** GET /api/attendance?month=&year=&employee_id= */
    public function index(Request $request)
    {
        $query = DB::table('attendance as a')
            ->join('employees as e','a.employee_id','=','e.employee_id')
            ->join('departments as d','e.department_id','=','d.department_id')
            ->select('a.*',DB::raw("CONCAT(e.first_name,' ',e.last_name) as employee_name"),'d.department_name');

        // Employee: own only
        if ($request->user()->role === 'Employee') {
            $query->where('e.email', $request->user()->username);
        }
        if ($request->filled('month'))       $query->where('a.attendance_month',$request->month);
        if ($request->filled('year'))        $query->where('a.attendance_year', $request->year);
        if ($request->filled('employee_id')) $query->where('a.employee_id',     $request->employee_id);

        return response()->json(['success'=>true,'data'=>$query->orderByDesc('a.attendance_year')->orderByDesc('a.attendance_month')->get()]);
    }

    /** POST /api/attendance — Admin+Manager */
    public function store(Request $request)
    {
        if (!in_array($request->user()->role,['Admin','Manager'])) {
            return response()->json(['success'=>false,'message'=>'Admin or Manager access required.'],403);
        }
        $request->validate([
            'employee_id'      => 'required|integer|exists:employees,employee_id',
            'attendance_month' => 'required|integer|between:1,12',
            'attendance_year'  => 'required|integer|min:2000',
            'days_worked'      => 'required|integer|min:0|max:31',
            'days_absent'      => 'required|integer|min:0|max:31',
            'working_days'     => 'required|integer|min:1|max:31',
        ]);
        DB::table('attendance')->updateOrInsert(
            ['employee_id'=>$request->employee_id,'attendance_month'=>$request->attendance_month,'attendance_year'=>$request->attendance_year],
            ['days_worked'=>$request->days_worked,'days_absent'=>$request->days_absent,'working_days'=>$request->working_days]
        );
        return response()->json(['success'=>true,'message'=>'Attendance saved.']);
    }

    /** PUT /api/attendance/{id} — Admin+Manager */
    public function update(Request $request, $id)
    {
        if (!in_array($request->user()->role,['Admin','Manager'])) {
            return response()->json(['success'=>false,'message'=>'Admin or Manager access required.'],403);
        }
        DB::table('attendance')->where('attendance_id',$id)->update([
            'days_worked'  => $request->days_worked,
            'days_absent'  => $request->days_absent,
            'working_days' => $request->working_days ?? 22,
        ]);
        return response()->json(['success'=>true,'message'=>'Attendance updated.']);
    }
}
