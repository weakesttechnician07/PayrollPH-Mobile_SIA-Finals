<?php

// ============================================================
// app/Http/Controllers/Api/UserController.php
// ============================================================

namespace App\Http\Controllers\Api;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class UserController extends Controller
{
    private function adminOnly(Request $request) {
        if ($request->user()->role !== 'Admin') return response()->json(['success'=>false,'message'=>'Admin only.'],403);
        return null;
    }

    public function index(Request $request) {
        if ($e=$this->adminOnly($request)) return $e;
        return response()->json(['success'=>true,'data'=>DB::table('users')->select('user_id','username','full_name','role','status','created_at')->orderBy('role')->orderBy('username')->get()]);
    }

    public function store(Request $request) {
        if ($e=$this->adminOnly($request)) return $e;
        $request->validate(['username'=>'required|unique:users,username','password'=>'required|min:6','full_name'=>'required','role'=>'required|in:Admin,Manager,Employee']);
        DB::table('users')->insert(['username'=>$request->username,'password'=>Hash::make($request->password),'full_name'=>$request->full_name,'role'=>$request->role,'status'=>'Active']);
        AuditLog::create(['user_id'=>$request->user()->user_id,'username'=>$request->user()->username,'action'=>'Add User','target'=>'users','detail'=>"Created: {$request->username} ({$request->role}) mobile",'ip_address'=>$request->ip()]);
        return response()->json(['success'=>true,'message'=>'User created.'],201);
    }

    public function update(Request $request, $id) {
        if ($e=$this->adminOnly($request)) return $e;
        if ($request->user()->user_id == $id && $request->role !== 'Admin') return response()->json(['success'=>false,'message'=>'Cannot change own role.'],422);
        DB::table('users')->where('user_id',$id)->update(['full_name'=>$request->full_name,'role'=>$request->role,'status'=>$request->status]);
        AuditLog::create(['user_id'=>$request->user()->user_id,'username'=>$request->user()->username,'action'=>'Edit User','target'=>'users','detail'=>"Updated user_id=$id (mobile)",'ip_address'=>$request->ip()]);
        return response()->json(['success'=>true,'message'=>'User updated.']);
    }

    public function resetPassword(Request $request, $id) {
        if ($e=$this->adminOnly($request)) return $e;
        $request->validate(['password'=>'required|min:6']);
        DB::table('users')->where('user_id',$id)->update(['password'=>Hash::make($request->password)]);
        AuditLog::create(['user_id'=>$request->user()->user_id,'username'=>$request->user()->username,'action'=>'Reset Password','target'=>'users','detail'=>"Password reset for user_id=$id (mobile)",'ip_address'=>$request->ip()]);
        return response()->json(['success'=>true,'message'=>'Password reset.']);
    }

    // ── DELETE /api/users/{id} — Admin only ──────────────────
    public function destroy(Request $request, $id) {
        if ($e=$this->adminOnly($request)) return $e;

        // Block self-deletion — admin cannot delete their own account
        if ($request->user()->user_id == $id) {
            return response()->json(['success'=>false,'message'=>'You cannot delete your own account.'],422);
        }

        // Fetch user details before deleting (for audit log)
        $user = DB::table('users')->where('user_id',$id)->first();
        if (!$user) {
            return response()->json(['success'=>false,'message'=>'User not found.'],404);
        }

        DB::table('users')->where('user_id',$id)->delete();

        AuditLog::create([
            'user_id'    => $request->user()->user_id,
            'username'   => $request->user()->username,
            'action'     => 'Delete User',
            'target'     => 'users',
            'detail'     => "Deleted user: {$user->username} ({$user->role}) (mobile)",
            'ip_address' => $request->ip(),
        ]);

        return response()->json(['success'=>true,'message'=>"User '{$user->username}' deleted successfully."]);
    }

    public function auditLog(Request $request) {
        if ($e=$this->adminOnly($request)) return $e;
        $query = DB::table('vw_audit_log');
        if ($request->filled('username')) $query->where('username','like',"%{$request->username}%");
        if ($request->filled('action'))   $query->where('action','like',"%{$request->action}%");
        return response()->json(['success'=>true,'data'=>$query->orderBy('logged_at','desc')->limit(100)->get()]);
    }
}
