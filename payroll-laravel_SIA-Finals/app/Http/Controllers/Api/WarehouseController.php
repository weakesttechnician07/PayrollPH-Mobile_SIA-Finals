<?php
// ============================================================
// app/Http/Controllers/Api/WarehouseController.php
// ============================================================
namespace App\Http\Controllers\Api;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class WarehouseController extends Controller
{
    public function facts()
    {
        $facts = DB::table('fact_payroll as fp')
            ->join('dim_date as dd',       'fp.date_key','=','dd.date_key')
            ->join('dim_employee as de',   'fp.emp_key', '=','de.emp_key')
            ->join('dim_department as dm', 'fp.dept_key','=','dm.dept_key')
            ->select('fp.fact_id','dd.month_name','dd.year','dd.quarter','de.full_name','de.department','de.position','fp.basic_salary','fp.gross_pay','fp.net_pay','fp.etl_loaded_at')
            ->orderByDesc('dd.year')->orderByDesc('dd.month')->limit(50)->get();

        $counts = ['fact_count'=>DB::table('fact_payroll')->count(),'fact_total'=>DB::table('fact_payroll')->sum('net_pay'),'dim_emp'=>DB::table('dim_employee')->count(),'dim_dept'=>DB::table('dim_department')->count(),'dim_date'=>DB::table('dim_date')->count()];
        return response()->json(['success'=>true,'data'=>$facts,'counts'=>$counts]);
    }

    public function mart()
    {
        return response()->json(['success'=>true,'data'=>DB::table('vw_dept_payroll_summary')->orderByDesc('payroll_year')->orderByDesc('payroll_month')->orderBy('department_name')->get()]);
    }

    public function quarterly()
    {
        $data = DB::table('fact_payroll as fp')->join('dim_date as dd','fp.date_key','=','dd.date_key')
            ->select('dd.year','dd.quarter',DB::raw('COUNT(fp.fact_id) as record_count'),DB::raw('SUM(fp.net_pay) as total_net'),DB::raw('AVG(fp.net_pay) as avg_net'))
            ->groupBy('dd.year','dd.quarter')->orderByDesc('dd.year')->orderByDesc('dd.quarter')->get();
        return response()->json(['success'=>true,'data'=>$data]);
    }

    public function runEtl(Request $request)
    {
        if ($request->user()->role !== 'Admin') return response()->json(['success'=>false,'message'=>'Admin only.'],403);
        try {
            DB::statement('CALL sp_run_etl()');
            AuditLog::create(['user_id'=>$request->user()->user_id,'username'=>$request->user()->username,'action'=>'Run ETL','target'=>'fact_payroll','detail'=>'ETL executed (mobile)','ip_address'=>$request->ip()]);
            return response()->json(['success'=>true,'message'=>'ETL completed successfully.']);
        } catch (\Exception $e) {
            return response()->json(['success'=>false,'message'=>'ETL failed: '.$e->getMessage()],500);
        }
    }
}
