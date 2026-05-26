<?php
// ============================================================
// app/Http/Controllers/Api/BenefitsController.php
// ============================================================
namespace App\Http\Controllers\Api;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class BenefitsController extends Controller
{
    /** GET /api/benefits — Employee's own pay breakdown */
    public function index(Request $request)
    {
        $user = $request->user();
        $emp  = DB::table('employees as e')
            ->join('positions as p','e.position_id','=','p.position_id')
            ->join('departments as d','e.department_id','=','d.department_id')
            ->select('e.*','p.base_salary','p.position_title','d.department_name')
            ->where('e.email',$user->username)->first();

        if (!$emp) return response()->json(['success'=>false,'message'=>'No employee record found.'],404);

        $components  = DB::table('pay_components')->orderByDesc('component_type')->orderBy('component_name')->get();
        $allowances  = $components->where('component_type','Allowance');
        $deductions  = $components->where('component_type','Deduction');
        $totalAllow  = $allowances->sum('default_amount');
        $totalDeduct = $deductions->sum('default_amount');

        // Payroll history summary
        $hist = DB::table('payroll_records')
            ->where('employee_id',$emp->employee_id)
            ->selectRaw('COUNT(*) as total_records, COALESCE(SUM(net_pay),0) as total_earned, COALESCE(AVG(net_pay),0) as avg_net')
            ->first();

        return response()->json(['success'=>true,'data'=>[
            'employee'    => $emp,
            'components'  => $components,
            'allowances'  => $allowances->values(),
            'deductions'  => $deductions->values(),
            'total_allow' => $totalAllow,
            'total_deduct'=> $totalDeduct,
            'gross_pay'   => $emp->base_salary + $totalAllow,
            'net_pay'     => $emp->base_salary + $totalAllow - $totalDeduct,
            'history'     => $hist,
        ]]);
    }

    /** GET /api/benefits/all — all pay components (any role) */
    public function all()
    {
        return response()->json(['success'=>true,'data'=>DB::table('pay_components')->orderByDesc('component_type')->orderBy('component_name')->get()]);
    }
}
