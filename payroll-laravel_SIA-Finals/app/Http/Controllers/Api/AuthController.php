<?php
// ============================================================
// app/Http/Controllers/Api/AuthController.php
// ============================================================
namespace App\Http\Controllers\Api;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $request->validate(['username'=>'required','password'=>'required']);
        $user = User::where('username',$request->username)->where('status','Active')->first();
        if (!$user || !Hash::check($request->password,$user->password)) {
            return response()->json(['success'=>false,'message'=>'Invalid username or password.'],401);
        }
        $user->tokens()->delete();
        $token = $user->createToken('payroll-mobile')->plainTextToken;
        try { AuditLog::create(['user_id'=>$user->user_id,'username'=>$user->username,'action'=>'Login','target'=>'System','detail'=>'Mobile login','ip_address'=>$request->ip()]); } catch(\Exception $e){}
        return response()->json(['success'=>true,'token'=>$token,'user'=>['user_id'=>$user->user_id,'username'=>$user->username,'full_name'=>$user->full_name,'role'=>$user->role,'currency'=>$user->currency ?? 'PHP']]);
    }

    public function logout(Request $request)
    {
        try { AuditLog::create(['user_id'=>$request->user()->user_id,'username'=>$request->user()->username,'action'=>'Logout','target'=>'System','detail'=>'Mobile logout','ip_address'=>$request->ip()]); } catch(\Exception $e){}
        $request->user()->currentAccessToken()->delete();
        return response()->json(['success'=>true,'message'=>'Logged out.']);
    }

    public function me(Request $request)
    {
        $u = $request->user();
        return response()->json(['success'=>true,'user'=>['user_id'=>$u->user_id,'username'=>$u->username,'full_name'=>$u->full_name,'role'=>$u->role,'status'=>$u->status,'currency'=>$u->currency ?? 'PHP']]);
    }

    public function setCurrency(Request $request)
    {
        $request->validate(['currency'=>'required|in:PHP,USD']);
        \Illuminate\Support\Facades\DB::table('users')->where('user_id',$request->user()->user_id)->update(['currency'=>$request->currency]);
        return response()->json(['success'=>true,'currency'=>$request->currency]);
    }
}
