<?php
// ============================================================
// app/Http/Controllers/Api/PayrollController.php
// Updated: attendance-based prorated salary, pagination
// ============================================================
namespace App\Http\Controllers\Api;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PayrollController extends Controller
{
    /** GET /api/payroll?page=1&dept=&year=&month= */
    public function index(Request $request)
    {
        $perPage = 20;
        $page    = max(1,(int)$request->get('page',1));
        $offset  = ($page-1)*$perPage;

        $query = DB::table('vw_payroll_detail as pd');
        if ($request->user()->role === 'Employee') {
            $query->where(function($q) use ($request) {
                $q->where('pd.employee_name',$request->user()->full_name)
                  ->orWhere('pd.email',$request->user()->username);
            });
        }
        if ($request->filled('dept')) {
            $dn = DB::table('departments')->where('department_id',$request->dept)->value('department_name');
            if ($dn) $query->where('pd.department_name',$dn);
        }
        if ($request->filled('year'))  $query->where('pd.payroll_year', $request->year);
        if ($request->filled('month')) $query->where('pd.payroll_month',$request->month);

        $total     = $query->count();
        $records   = $query->orderByDesc('pd.payroll_year')->orderByDesc('pd.payroll_month')->orderBy('pd.employee_name')
                           ->limit($perPage)->offset($offset)->get();
        $grandTotal= (clone $query)->sum('net_pay');

        return response()->json(['success'=>true,'data'=>$records,'total'=>$total,'per_page'=>$perPage,'current_page'=>$page,'total_pages'=>(int)ceil($total/$perPage),'grand_total_net'=>round($grandTotal,2)]);
    }

    /** GET /api/payroll/preview?month=&year= — attendance-aware */
    public function preview(Request $request)
    {
        $request->validate(['month'=>'required|integer|between:1,12','year'=>'required|integer|min:2000']);
        $month = $request->month; $year = $request->year;

        $employees = DB::table('employees as e')
            ->join('positions as p',  'e.position_id',  '=','p.position_id')
            ->join('departments as d','e.department_id','=','d.department_id')
            ->leftJoin('attendance as a', function($j) use ($month,$year) {
                $j->on('a.employee_id','=','e.employee_id')
                  ->where('a.attendance_month',$month)->where('a.attendance_year',$year);
            })
            ->select(
                'e.employee_id',DB::raw("CONCAT(e.first_name,' ',e.last_name) as full_name"),
                'd.department_name','p.position_title','p.base_salary',
                DB::raw('COALESCE(a.working_days,22) as working_days'),
                DB::raw('COALESCE(a.days_worked,22)  as days_worked'),
                DB::raw('COALESCE(a.days_absent,0)   as days_absent'),
                DB::raw('COALESCE(a.days_present,22) as days_present'),
                DB::raw('ROUND(p.base_salary/COALESCE(a.working_days,22)*COALESCE(a.days_present,22),2) as prorated_salary'),
                DB::raw('ROUND(p.base_salary/COALESCE(a.working_days,22)*COALESCE(a.days_absent,0),2)  as absence_deduction'),
                DB::raw('(a.attendance_month IS NOT NULL) as has_attendance'),
                DB::raw("(SELECT COUNT(*) FROM payroll_records pr2 WHERE pr2.employee_id=e.employee_id AND pr2.payroll_month=$month AND pr2.payroll_year=$year) as already_processed")
            )
            ->where('e.status','Active')
            ->orderBy('d.department_name')->orderBy('e.last_name')->get();

        $totalAllow  = DB::table('pay_components')->where('component_type','Allowance')->sum('default_amount');
        $totalDeduct = DB::table('pay_components')->where('component_type','Deduction')->sum('default_amount');
        $components  = DB::table('pay_components')->get();

        $employees = $employees->map(function($emp) use ($totalAllow,$totalDeduct) {
            $emp->gross_pay = round($emp->prorated_salary + $totalAllow, 2);
            $emp->net_pay   = round($emp->prorated_salary + $totalAllow - $totalDeduct, 2);
            $emp->total_allowance = $totalAllow;
            $emp->total_deduction = $totalDeduct;
            return $emp;
        });

        return response()->json(['success'=>true,'data'=>['month'=>$month,'year'=>$year,'employees'=>$employees,'components'=>$components,'total_allowance'=>$totalAllow,'total_deduction'=>$totalDeduct,'total_net'=>$employees->sum('net_pay'),'no_attendance_count'=>$employees->where('has_attendance',0)->count()]]);
    }

    /** POST /api/payroll/process — Admin only, prorated, transaction */
    public function process(Request $request)
    {
        if ($request->user()->role !== 'Admin') return response()->json(['success'=>false,'message'=>'Admin only.'],403);
        $request->validate(['month'=>'required|integer|between:1,12','year'=>'required|integer|min:2000']);
        $month=(int)$request->month; $year=(int)$request->year;

        DB::beginTransaction();
        try {
            $employees = DB::select("
                SELECT e.employee_id, e.version, p.base_salary,
                       COALESCE(a.working_days,22) as working_days,
                       COALESCE(a.days_present,22) as days_present,
                       COALESCE(a.days_absent,0)   as days_absent
                FROM employees e
                JOIN positions p ON e.position_id=p.position_id
                LEFT JOIN attendance a ON a.employee_id=e.employee_id AND a.attendance_month=? AND a.attendance_year=?
                WHERE e.status='Active' FOR UPDATE
            ",[$month,$year]);

            if (empty($employees)) { DB::rollBack(); return response()->json(['success'=>false,'message'=>'No active employees.'],422); }

            $totalAllow  = DB::table('pay_components')->where('component_type','Allowance')->sum('default_amount');
            $totalDeduct = DB::table('pay_components')->where('component_type','Deduction')->sum('default_amount');
            $inserted=0; $skipped=0;

            foreach ($employees as $emp) {
                if (DB::table('payroll_records')->where('employee_id',$emp->employee_id)->where('payroll_month',$month)->where('payroll_year',$year)->exists()) { $skipped++; continue; }
                $workingDays = max(1,(int)$emp->working_days);
                $proratedPay = round($emp->base_salary / $workingDays * max(0,(int)$emp->days_present), 2);
                DB::table('payroll_records')->insert(['employee_id'=>$emp->employee_id,'payroll_month'=>$month,'payroll_year'=>$year,'basic_salary'=>$proratedPay,'total_allowance'=>$totalAllow,'total_deduction'=>$totalDeduct]);
                $inserted++;
            }
            DB::commit();
            AuditLog::create(['user_id'=>$request->user()->user_id,'username'=>$request->user()->username,'action'=>'Process Payroll','target'=>'payroll_records','detail'=>"Month=$month Year=$year Inserted=$inserted Skipped=$skipped (mobile)",'ip_address'=>$request->ip()]);
            return response()->json(['success'=>true,'message'=>"Payroll processed: $inserted saved, $skipped skipped.",'inserted'=>$inserted,'skipped'=>$skipped]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['success'=>false,'message'=>'Rolled back: '.$e->getMessage()],500);
        }
    }

    /** GET /api/payroll/ranking */
    public function ranking(Request $request)
    {
        $latest = DB::table('payroll_records')->select('payroll_year','payroll_month')->orderByDesc('payroll_year')->orderByDesc('payroll_month')->first();
        $month  = $request->get('month',$latest->payroll_month ?? date('n'));
        $year   = $request->get('year', $latest->payroll_year  ?? date('Y'));
        $data   = DB::table('vw_payroll_ranking')->where('payroll_year',$year)->where('payroll_month',$month)->orderBy('pay_rank')->get();
        return response()->json(['success'=>true,'data'=>$data]);
    }

    /** GET /api/payroll/summary */
    public function summary(Request $request)
    {
        $query = DB::table('vw_dept_payroll_summary');
        if ($request->filled('year')) $query->where('payroll_year',$request->year);
        return response()->json(['success'=>true,'data'=>$query->orderByDesc('payroll_year')->orderByDesc('payroll_month')->orderBy('department_name')->get()]);
    }
}
