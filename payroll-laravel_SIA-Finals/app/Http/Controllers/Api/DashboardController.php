<?php
// ============================================================
// app/Http/Controllers/Api/DashboardController.php
// ============================================================
namespace App\Http\Controllers\Api;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        if ($user->role === 'Employee') {
            // Employee: own dashboard data
            $emp = DB::table('employees as e')->join('departments as d','e.department_id','=','d.department_id')->join('positions as p','e.position_id','=','p.position_id')->select('e.*','p.base_salary','p.position_title','d.department_name')->where('e.email',$user->username)->first();
            if (!$emp) return response()->json(['success'=>true,'data'=>['employee'=>null]]);

            $latestPay = DB::table('payroll_records')->where('employee_id',$emp->employee_id)->orderByDesc('payroll_year')->orderByDesc('payroll_month')->first();
            $latestAtt = DB::table('attendance')->where('employee_id',$emp->employee_id)->orderByDesc('attendance_year')->orderByDesc('attendance_month')->first();
            $totalPay  = DB::table('payroll_records')->where('employee_id',$emp->employee_id)->count();
            $recentPay = DB::table('vw_payroll_detail')->where('email',$user->username)->orderByDesc('payroll_year')->orderByDesc('payroll_month')->limit(5)->get();
            $benefits  = DB::table('pay_components')->get();

            return response()->json(['success'=>true,'data'=>['employee'=>$emp,'latest_pay'=>$latestPay,'latest_attendance'=>$latestAtt,'total_pay_records'=>$totalPay,'recent_payroll'=>$recentPay,'benefits'=>$benefits,'role'=>'Employee']]);
        }

        // Admin/Manager: full stats
        $totalEmp   = DB::table('employees')->where('status','Active')->count();
        $totalRec   = DB::table('payroll_records')->count();
        $totalPaid  = DB::table('payroll_records')->sum('net_pay') ?? 0;
        $lastPay    = DB::table('payroll_records')->max('processed_at');
        $pendingReq = $user->role === 'Admin'
            ? DB::table('requests')->where('status','Pending')->count()
            : DB::table('requests')->where('status','Pending')->where('handled_by','Manager')->count();

        $deptStats  = DB::table('departments as d')
            ->leftJoin('employees as e',function($j){$j->on('e.department_id','=','d.department_id')->where('e.status','Active');})
            ->select('d.department_name',DB::raw('COUNT(e.employee_id) as emp_count'),DB::raw('(SELECT COUNT(*) FROM payroll_records pr JOIN employees e2 ON pr.employee_id=e2.employee_id WHERE e2.department_id=d.department_id) as payroll_count'))
            ->groupBy('d.department_id','d.department_name')->orderByDesc('emp_count')->get();

        $recent = DB::table('vw_payroll_detail')->orderByDesc('processed_at')->limit(5)->get();

        return response()->json(['success'=>true,'data'=>['total_employees'=>$totalEmp,'total_records'=>$totalRec,'total_paid'=>round($totalPaid,2),'last_payroll'=>$lastPay,'dept_stats'=>$deptStats,'recent_payroll'=>$recent,'pending_requests'=>$pendingReq,'role'=>$user->role]]);
    }
}
