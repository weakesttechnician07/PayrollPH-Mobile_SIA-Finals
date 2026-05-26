<?php
// ============================================================
// app/Http/Controllers/Api/EmployeeController.php
// Updated: auto user account on add, pagination, CSV import,
//          own-phone update for Employee role
// ============================================================
namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class EmployeeController extends Controller
{
    /** GET /api/employees?page=1&q=&dept= */
    public function index(Request $request)
    {
        $perPage = 20;
        $page    = max(1, (int)$request->get('page', 1));
        $offset  = ($page - 1) * $perPage;
        $q       = $request->get('q', '');
        $dept    = (int)$request->get('dept', 0);

        $query = DB::table('employees as e')
            ->join('departments as d', 'e.department_id', '=', 'd.department_id')
            ->join('positions as p',   'e.position_id',   '=', 'p.position_id')
            ->select('e.employee_id','e.first_name','e.last_name','e.email','e.phone',
                     'e.hire_date','e.status','e.version','d.department_name',
                     'd.department_id','p.position_title','p.position_id','p.base_salary');

        if ($q) {
            $query->where(function($sub) use ($q) {
                $sub->where('e.first_name','like',"%$q%")
                    ->orWhere('e.last_name','like',"%$q%")
                    ->orWhere('e.email','like',"%$q%");
            });
        }
        if ($dept) $query->where('e.department_id', $dept);

        $total   = $query->count();
        $employees = $query->orderBy('e.last_name')->orderBy('e.first_name')
                           ->limit($perPage)->offset($offset)->get();

        return response()->json([
            'success'      => true,
            'data'         => $employees,
            'total'        => $total,
            'per_page'     => $perPage,
            'current_page' => $page,
            'total_pages'  => (int)ceil($total / $perPage),
        ]);
    }

    /** GET /api/employees/me — Employee's own record */
    public function me(Request $request)
    {
        $user = $request->user();
        $emp  = DB::table('employees as e')
            ->join('departments as d','e.department_id','=','d.department_id')
            ->join('positions as p',  'e.position_id',  '=','p.position_id')
            ->select('e.*','d.department_name','p.position_title','p.base_salary')
            ->where('e.email', $user->username)
            ->first();

        if (!$emp) {
            return response()->json(['success'=>false,'message'=>'No employee record linked to your account.'],404);
        }
        return response()->json(['success'=>true,'data'=>$emp]);
    }

    /** GET /api/employees/{id} */
    public function show($id)
    {
        $emp = DB::table('employees as e')
            ->join('departments as d','e.department_id','=','d.department_id')
            ->join('positions as p',  'e.position_id',  '=','p.position_id')
            ->select('e.*','d.department_name','p.position_title','p.base_salary')
            ->where('e.employee_id',$id)->first();

        if (!$emp) return response()->json(['success'=>false,'message'=>'Not found.'],404);
        return response()->json(['success'=>true,'data'=>$emp]);
    }

    /** POST /api/employees — auto-creates user account */
    public function store(Request $request)
    {
        $request->validate([
            'first_name'    => 'required|string|max:60',
            'last_name'     => 'required|string|max:60',
            'email'         => 'required|email|unique:employees,email',
            'department_id' => 'required|integer|exists:departments,department_id',
            'position_id'   => 'required|integer|exists:positions,position_id',
            'hire_date'     => 'required|date',
        ]);

        DB::beginTransaction();
        try {
            // Insert employee
            $empId = DB::table('employees')->insertGetId([
                'first_name'    => trim($request->first_name),
                'last_name'     => trim($request->last_name),
                'email'         => trim($request->email),
                'phone'         => trim($request->phone ?? ''),
                'department_id' => $request->department_id,
                'position_id'   => $request->position_id,
                'hire_date'     => $request->hire_date,
                'status'        => 'Active',
                'version'       => 0,
            ]);

            // Auto-generate username: firstname.lastname@company.com
            $fn       = strtolower(preg_replace('/\s+/','', $request->first_name));
            $ln       = strtolower(preg_replace('/\s+/','', $request->last_name));
            $baseUser = "$fn.$ln@company.com";
            $username = $baseUser;
            $counter  = 1;
            while (DB::table('users')->where('username',$username)->exists()) {
                $username = str_replace('@company.com', $counter.'@company.com', $baseUser);
                $counter++;
            }

            DB::table('users')->insert([
                'username'  => $username,
                'password'  => Hash::make('password'),
                'full_name' => $request->first_name.' '.$request->last_name,
                'role'      => 'Employee',
                'status'    => 'Active',
            ]);

            DB::commit();

            AuditLog::create([
                'user_id'    => $request->user()->user_id,
                'username'   => $request->user()->username,
                'action'     => 'Add Employee',
                'target'     => 'employees',
                'detail'     => "Added: {$request->first_name} {$request->last_name} | Account: $username",
                'ip_address' => $request->ip(),
            ]);

            return response()->json([
                'success'      => true,
                'message'      => 'Employee added successfully.',
                'employee_id'  => $empId,
                'account'      => ['username' => $username, 'password' => 'password'],
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['success'=>false,'message'=>$e->getMessage()],500);
        }
    }

    /** PUT /api/employees/{id} — Admin+Manager */
    public function update(Request $request, $id)
    {
        if (!in_array($request->user()->role, ['Admin','Manager'])) {
            return response()->json(['success'=>false,'message'=>'Admin or Manager access required.'],403);
        }
        $request->validate([
            'first_name'    => 'required|string|max:60',
            'last_name'     => 'required|string|max:60',
            'email'         => "required|email|unique:employees,email,$id,employee_id",
            'department_id' => 'required|integer|exists:departments,department_id',
            'position_id'   => 'required|integer|exists:positions,position_id',
            'hire_date'     => 'required|date',
            'version'       => 'required|integer',
        ]);

        $affected = DB::table('employees')
            ->where('employee_id',$id)->where('version',$request->version)
            ->update([
                'first_name'    => trim($request->first_name),
                'last_name'     => trim($request->last_name),
                'email'         => trim($request->email),
                'phone'         => trim($request->phone ?? ''),
                'department_id' => $request->department_id,
                'position_id'   => $request->position_id,
                'hire_date'     => $request->hire_date,
                'status'        => $request->status ?? 'Active',
                'version'       => DB::raw('version + 1'),
            ]);

        if ($affected === 0) {
            return response()->json(['success'=>false,'message'=>'Concurrency conflict. Reload and try again.'],409);
        }

        AuditLog::create([
            'user_id'    => $request->user()->user_id,
            'username'   => $request->user()->username,
            'action'     => 'Edit Employee','target'=>'employees',
            'detail'     => "Updated employee_id=$id (mobile)",
            'ip_address' => $request->ip(),
        ]);

        return response()->json(['success'=>true,'message'=>'Employee updated.']);
    }

    /** DELETE /api/employees/{id} — Admin only */
    public function destroy(Request $request, $id)
    {
        if ($request->user()->role !== 'Admin') {
            return response()->json(['success'=>false,'message'=>'Admin access required.'],403);
        }
        if (DB::table('payroll_records')->where('employee_id',$id)->exists()) {
            return response()->json(['success'=>false,'message'=>'Cannot delete: employee has payroll records.'],422);
        }

        // Fetch employee to find the linked auto-created user account
        $emp = DB::table('employees')->where('employee_id',$id)->first();
        if (!$emp) {
            return response()->json(['success'=>false,'message'=>'Employee not found.'],404);
        }

        DB::beginTransaction();
        try {
            // Delete the linked Employee-role user account (auto-generated username pattern)
            $fn       = strtolower(preg_replace('/\s+/', '', $emp->first_name));
            $ln       = strtolower(preg_replace('/\s+/', '', $emp->last_name));
            $autoUser = "$fn.$ln@company.com";
            // Only delete Employee-role accounts — never touch Admin/Manager accounts
            DB::table('users')
                ->where('username', 'like', str_replace('@company.com', '%@company.com', $autoUser))
                ->where('role', 'Employee')
                ->delete();

            DB::table('employees')->where('employee_id',$id)->delete();
            DB::commit();

            AuditLog::create([
                'user_id'    => $request->user()->user_id,
                'username'   => $request->user()->username,
                'action'     => 'Delete Employee',
                'target'     => 'employees',
                'detail'     => "Deleted: {$emp->first_name} {$emp->last_name} (emp_id=$id) + linked user account (mobile)",
                'ip_address' => $request->ip(),
            ]);

            return response()->json(['success'=>true,'message'=>'Employee and linked user account deleted.']);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['success'=>false,'message'=>'Delete failed: '.$e->getMessage()],500);
        }
    }

    /** PUT /api/employees/me/phone — Employee only */
    public function updatePhone(Request $request)
    {
        if ($request->user()->role !== 'Employee') {
            return response()->json(['success'=>false,'message'=>'Employee role only.'],403);
        }
        $request->validate(['phone'=>'required|string|max:20','version'=>'required|integer']);
        $affected = DB::table('employees')
            ->where('email', $request->user()->username)
            ->where('version', $request->version)
            ->update(['phone'=>$request->phone,'version'=>DB::raw('version + 1')]);

        if ($affected === 0) return response()->json(['success'=>false,'message'=>'Update failed or conflict.'],409);
        AuditLog::create(['user_id'=>$request->user()->user_id,'username'=>$request->user()->username,'action'=>'Edit Own Profile','target'=>'employees','detail'=>'Phone updated (mobile)','ip_address'=>$request->ip()]);
        return response()->json(['success'=>true,'message'=>'Phone updated.']);
    }

    /** POST /api/employees/import — CSV bulk import */
    public function importCsv(Request $request)
    {
        if (!in_array($request->user()->role,['Admin','Manager'])) {
            return response()->json(['success'=>false,'message'=>'Admin or Manager access required.'],403);
        }
        $request->validate(['csv'=>'required|string']); // base64 encoded CSV content

        $csvContent = base64_decode($request->csv);
        $lines      = array_filter(explode("\n", $csvContent));
        array_shift($lines); // skip header

        $inserted=0; $skipped=0; $errors=[];
        DB::beginTransaction();
        try {
            foreach ($lines as $lineNum => $line) {
                $row = str_getcsv(trim($line));
                if (count($row) < 6) { $errors[]="Row ".($lineNum+2).": not enough columns"; $skipped++; continue; }
                [$fn,$ln,$email,$phone,$deptName,$posTitle] = array_map('trim',$row);
                $hireDate = isset($row[6]) ? trim($row[6]) : now()->toDateString();

                $deptId = DB::table('departments')->where('department_name',$deptName)->value('department_id');
                if (!$deptId) { $errors[]="Row ".($lineNum+2).": dept '$deptName' not found"; $skipped++; continue; }
                $posId = DB::table('positions')->where('position_title',$posTitle)->value('position_id');
                if (!$posId) { $errors[]="Row ".($lineNum+2).": position '$posTitle' not found"; $skipped++; continue; }
                if (DB::table('employees')->where('email',$email)->exists()) { $errors[]="Row ".($lineNum+2).": email '$email' exists"; $skipped++; continue; }

                $empId = DB::table('employees')->insertGetId(['first_name'=>$fn,'last_name'=>$ln,'email'=>$email,'phone'=>$phone,'department_id'=>$deptId,'position_id'=>$posId,'hire_date'=>$hireDate,'status'=>'Active','version'=>0]);

                // Auto user account
                $baseU = strtolower(preg_replace('/\s+/','',$fn).'.'.preg_replace('/\s+/','',$ln)).'@company.com';
                $uname = $baseU; $c=1;
                while (DB::table('users')->where('username',$uname)->exists()) { $uname=str_replace('@company.com',$c.'@company.com',$baseU); $c++; }
                DB::table('users')->insert(['username'=>$uname,'password'=>Hash::make('password'),'full_name'=>"$fn $ln",'role'=>'Employee','status'=>'Active']);
                $inserted++;
            }
            DB::commit();
            AuditLog::create(['user_id'=>$request->user()->user_id,'username'=>$request->user()->username,'action'=>'CSV Import','target'=>'employees','detail'=>"Imported=$inserted Skipped=$skipped (mobile)",'ip_address'=>$request->ip()]);
            return response()->json(['success'=>true,'message'=>"Imported: $inserted, Skipped: $skipped",'inserted'=>$inserted,'skipped'=>$skipped,'errors'=>$errors]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['success'=>false,'message'=>'Import failed: '.$e->getMessage()],500);
        }
    }

    public function departments() { return response()->json(['success'=>true,'data'=>DB::table('departments')->orderBy('department_name')->get()]); }
    public function positions()   { return response()->json(['success'=>true,'data'=>DB::table('positions')->orderBy('position_title')->get()]); }
}
