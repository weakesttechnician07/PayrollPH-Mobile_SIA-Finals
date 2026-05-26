<?php
// ============================================================
// routes/api.php — PayrollPH REST API (Updated v2)
// New: requests, benefits, attendance, CSV import, pagination
// ============================================================

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\EmployeeController;
use App\Http\Controllers\Api\PayrollController;
use App\Http\Controllers\Api\WarehouseController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\RequestController;
use App\Http\Controllers\Api\AttendanceController;
use App\Http\Controllers\Api\BenefitsController;

// ── Public ───────────────────────────────────────────────────
Route::post('/login',  [AuthController::class, 'login']);

// ── Protected (Sanctum Bearer token) ─────────────────────────
Route::middleware('auth:sanctum')->group(function () {

    // Auth
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me',      [AuthController::class, 'me']);

    // Currency preference
    Route::post('/currency', [AuthController::class, 'setCurrency']);

    // Dashboard
    Route::get('/dashboard', [DashboardController::class, 'index']);

    // Employees (paginated, AJAX search)
    Route::get('/employees',              [EmployeeController::class, 'index']);     // ?page=1&q=&dept=
    Route::get('/employees/me',           [EmployeeController::class, 'me']);        // Employee own record
    Route::get('/employees/{id}',         [EmployeeController::class, 'show']);
    Route::post('/employees',             [EmployeeController::class, 'store']);     // auto-creates user account
    Route::put('/employees/{id}',         [EmployeeController::class, 'update']);    // Admin+Manager
    Route::delete('/employees/{id}',      [EmployeeController::class, 'destroy']);   // Admin only
    Route::put('/employees/me/phone',     [EmployeeController::class, 'updatePhone']); // Employee own phone
    Route::post('/employees/import',      [EmployeeController::class, 'importCsv']); // CSV bulk import

    // Dropdowns
    Route::get('/departments', [EmployeeController::class, 'departments']);
    Route::get('/positions',   [EmployeeController::class, 'positions']);

    // Payroll (paginated)
    Route::get('/payroll',          [PayrollController::class, 'index']);     // ?page=1&dept=&year=&month=
    Route::get('/payroll/preview',  [PayrollController::class, 'preview']);   // attendance-aware preview
    Route::post('/payroll/process', [PayrollController::class, 'process']);   // Admin only, prorated
    Route::get('/payroll/ranking',  [PayrollController::class, 'ranking']);
    Route::get('/payroll/summary',  [PayrollController::class, 'summary']);
    Route::get('/payroll/export',   [PayrollController::class, 'export']);    // CSV download

    // Attendance
    Route::get('/attendance',       [AttendanceController::class, 'index']);
    Route::post('/attendance',      [AttendanceController::class, 'store']);  // Admin+Manager
    Route::put('/attendance/{id}',  [AttendanceController::class, 'update']); // Admin+Manager

    // Benefits (Employee view of pay components)
    Route::get('/benefits',         [BenefitsController::class, 'index']);    // own breakdown
    Route::get('/benefits/all',     [BenefitsController::class, 'all']);      // all components

    // Requests
    Route::get('/requests',         [RequestController::class, 'index']);     // role-filtered
    Route::post('/requests',        [RequestController::class, 'store']);     // Employee submit
    Route::put('/requests/{id}',    [RequestController::class, 'review']);    // Manager/Admin approve/reject
    Route::get('/requests/pending-count', [RequestController::class, 'pendingCount']); // badge count

    // Warehouse (Admin only)
    Route::get('/warehouse/facts',     [WarehouseController::class, 'facts']);
    Route::get('/warehouse/mart',      [WarehouseController::class, 'mart']);
    Route::get('/warehouse/quarterly', [WarehouseController::class, 'quarterly']);
    Route::post('/warehouse/etl',      [WarehouseController::class, 'runEtl']);

    // Users & Audit (Admin only)
    Route::get('/users',              [UserController::class, 'index']);
    Route::post('/users',             [UserController::class, 'store']);
    Route::put('/users/{id}',         [UserController::class, 'update']);
    Route::delete('/users/{id}',      [UserController::class, 'destroy']);    // ← ADDED: delete user
    Route::post('/users/{id}/reset',  [UserController::class, 'resetPassword']);
    Route::get('/audit-log',          [UserController::class, 'auditLog']);
});