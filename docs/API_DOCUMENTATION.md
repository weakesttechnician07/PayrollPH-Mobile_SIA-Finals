# PayrollPH – REST API Documentation
**IT224 – Systems Integration and Architecture**
Base URL: `http://127.0.0.1:8000/api`
Authentication: Bearer Token via Laravel Sanctum

---

## Authentication

All endpoints except `/login` require the header:
```
Authorization: Bearer {token}
```

---

## Endpoint 1 — Login
`POST /api/login`

**Access:** Public (no token required)

**Request Body:**
```json
{ "username": "admin", "password": "password" }
```

**Success Response (200):**
```json
{
  "success": true,
  "token": "1|abcdefgh...",
  "user": {
    "user_id": 1,
    "username": "admin",
    "full_name": "System Administrator",
    "role": "Admin"
  }
}
```

**Error Response (401):**
```json
{ "success": false, "message": "Invalid username or password." }
```

---

## Endpoint 2 — Get Current User
`GET /api/me`

**Access:** All authenticated users

**Response:**
```json
{
  "success": true,
  "user": { "user_id": 1, "username": "admin", "full_name": "System Administrator", "role": "Admin", "status": "Active" }
}
```

---

## Endpoint 3 — Logout
`POST /api/logout`

**Access:** All authenticated users

**Response:**
```json
{ "success": true, "message": "Logged out." }
```

---

## Endpoint 4 — Set Currency Preference
`POST /api/currency`

**Access:** All authenticated users

**Request Body:**
```json
{ "currency": "USD" }
```

**Response:**
```json
{ "success": true, "message": "Currency updated." }
```

---

## Endpoint 5 — Dashboard Stats
`GET /api/dashboard`

**Access:** All authenticated users

**Response (Admin/Manager):**
```json
{
  "success": true,
  "data": {
    "total_employees": 8,
    "total_records": 24,
    "total_paid": 892400.00,
    "last_payroll": "2025-05-01 09:00:00",
    "pending_requests": 2,
    "dept_stats": [
      { "department_name": "IT", "emp_count": 2, "payroll_count": 6 }
    ],
    "recent_payroll": [
      { "employee_name": "Jose Reyes", "department_name": "IT", "payroll_month": 4, "payroll_year": 2025, "net_pay": 63800.00 }
    ]
  }
}
```

**Response (Employee):**
```json
{
  "success": true,
  "data": {
    "employee": { "first_name": "Juan", "last_name": "Dela Cruz", "position_title": "HR Manager", "department_name": "Human Resources" },
    "latest_pay": { "net_pay": 53800.00, "payroll_month": 4, "payroll_year": 2025 },
    "latest_attendance": { "days_worked": 22, "days_present": 22, "days_absent": 0 },
    "total_pay_records": 3,
    "recent_payroll": [],
    "benefits": []
  }
}
```

---

## Endpoint 6 — List Employees (paginated)
`GET /api/employees`

**Access:** All authenticated users

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| page | integer | Page number (default: 1, 20 per page) |
| q | string | Search by name or email |
| dept | integer | Filter by department_id |

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "employee_id": 1,
      "first_name": "Juan", "last_name": "Dela Cruz",
      "email": "juan.delacruz@company.com", "phone": "09171234567",
      "department_id": 1, "department_name": "Human Resources",
      "position_id": 1, "position_title": "HR Manager",
      "base_salary": 55000.00, "hire_date": "2020-03-15",
      "status": "Active", "version": 2
    }
  ],
  "total": 8,
  "per_page": 20,
  "current_page": 1,
  "total_pages": 1
}
```

---

## Endpoint 7 — Get Own Employee Record
`GET /api/employees/me`

**Access:** Employee role only

**Response:** Same as single employee object, linked by the logged-in user's username/email.

---

## Endpoint 8 — Get Single Employee
`GET /api/employees/{id}`

**Access:** All authenticated users

**Response:** Single employee object or `404` if not found.

---

## Endpoint 9 — Add Employee ⭐
`POST /api/employees`

**Access:** Admin and Manager

**Request Body:**
```json
{
  "first_name": "Maria", "last_name": "Cruz",
  "email": "maria.cruz@company.com", "phone": "09181234567",
  "department_id": 2, "position_id": 3,
  "hire_date": "2025-05-01"
}
```

**Response (201):**
```json
{
  "success": true,
  "message": "Employee added successfully.",
  "employee_id": 9,
  "account": { "username": "maria.cruz@mycompany.com", "password": "password" }
}
```

> Auto-creates a linked user account with role `Employee` and default password `password`.

---

## Endpoint 10 — Update Employee
`PUT /api/employees/{id}`

**Access:** Admin and Manager (403 for Employee)

**Request Body:** Same as add, plus `version` (optimistic locking) and `status`.

**Conflict Response (409):**
```json
{ "success": false, "message": "Concurrency conflict. Reload and try again." }
```

---

## Endpoint 11 — Delete Employee
`DELETE /api/employees/{id}`

**Access:** Admin only

**Description:** Also deletes the linked auto-created user account (Employee role only). Wrapped in a database transaction — if either delete fails, both roll back.

**Blocked Response (422):**
```json
{ "success": false, "message": "Cannot delete: employee has payroll records." }
```

**Success Response:**
```json
{ "success": true, "message": "Employee and linked user account deleted." }
```

---

## Endpoint 12 — Update Own Phone Number
`PUT /api/employees/me/phone`

**Access:** Employee role only

**Request Body:**
```json
{ "phone": "09991234567", "version": 2 }
```

**Response:**
```json
{ "success": true, "message": "Phone updated." }
```

---

## Endpoint 13 — CSV Bulk Import
`POST /api/employees/import`

**Access:** Admin and Manager

**Request Body:**
```json
{ "csv": "<base64-encoded CSV content>" }
```

**Response:**
```json
{ "success": true, "message": "Imported: 5, Skipped: 1", "inserted": 5, "skipped": 1, "errors": ["Row 3: email exists"] }
```

---

## Endpoint 14 — List Departments
`GET /api/departments`

**Access:** All authenticated users

---

## Endpoint 15 — List Positions
`GET /api/positions`

**Access:** All authenticated users

---

## Endpoint 16 — List Payroll Records (paginated)
`GET /api/payroll`

**Access:** All authenticated users

**Query Parameters:** `page`, `dept`, `year`, `month`

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "payroll_id": 1, "employee_name": "Juan Dela Cruz",
      "department_name": "HR", "position_title": "HR Manager",
      "payroll_month": 4, "payroll_year": 2025,
      "basic_salary": 55000.00, "total_allowance": 3500.00,
      "total_deduction": 4700.00, "gross_pay": 58500.00,
      "net_pay": 53800.00, "processed_at": "2025-04-01 09:00:00"
    }
  ],
  "grand_total_net": 438400.00
}
```

---

## Endpoint 17 — Payroll Preview (attendance-aware)
`GET /api/payroll/preview?month=5&year=2025`

**Access:** All authenticated users

**Response:**
```json
{
  "success": true,
  "data": {
    "month": 5, "year": 2025,
    "total_net": 438400.00,
    "no_attendance_count": 2,
    "employees": [
      {
        "full_name": "Juan Dela Cruz",
        "department_name": "HR",
        "days_present": 20, "working_days": 22, "days_absent": 2,
        "absence_deduction": 5000.00,
        "net_pay": 48800.00,
        "already_processed": 0
      }
    ]
  }
}
```

> `no_attendance_count` — number of employees with no attendance record; full 22-day salary assumed for these.

---

## Endpoint 18 — Process Payroll ⭐
`POST /api/payroll/process`

**Access:** Admin only

**Request Body:**
```json
{ "month": 5, "year": 2025 }
```

**Description:** Wraps all INSERT statements in a MySQL transaction (`DB::beginTransaction()` → `DB::commit()` / `DB::rollBack()`). Uses `SELECT FOR UPDATE` for pessimistic concurrency control. `UNIQUE KEY (employee_id, payroll_month, payroll_year)` prevents duplicate processing at the DB level.

**Response:**
```json
{ "success": true, "message": "Payroll processed: 8 saved, 0 skipped.", "inserted": 8, "skipped": 0 }
```

---

## Endpoint 19 — Pay Rankings (Window Functions)
`GET /api/payroll/ranking?month=4&year=2025`

**Access:** All authenticated users

**Response:**
```json
{
  "success": true,
  "data": [
    { "pay_rank": 1, "employee_name": "Jose Reyes", "department_name": "IT", "net_pay": 63800, "dept_total_net": 104100, "pct_of_total": 14.55 }
  ]
}
```

---

## Endpoint 20 — Department Payroll Summary
`GET /api/payroll/summary?year=2025`

**Access:** All authenticated users

---

## Endpoint 21 — Export Payroll CSV
`GET /api/payroll/export?month=4&year=2025`

**Access:** All authenticated users

**Response:** CSV file download with payroll records for the specified period.

---

## Endpoint 22 — List Attendance
`GET /api/attendance`

**Access:** All authenticated users

**Query Parameters:** `month`, `year`, `employee_id`

---

## Endpoint 23 — Add/Save Attendance
`POST /api/attendance`

**Access:** Admin and Manager

**Request Body:**
```json
{ "employee_id": 1, "attendance_month": 5, "attendance_year": 2025, "days_worked": 22, "days_absent": 2 }
```

**Response:**
```json
{ "success": true, "message": "Attendance saved." }
```

---

## Endpoint 24 — Update Attendance
`PUT /api/attendance/{id}`

**Access:** Admin and Manager

**Request Body:** Same as add attendance.

---

## Endpoint 25 — Get Own Benefits Breakdown
`GET /api/benefits`

**Access:** All authenticated users (returns own breakdown)

**Response:**
```json
{
  "success": true,
  "data": {
    "employee": { "first_name": "Juan", "base_salary": 55000.00 },
    "allowances": [ { "component_name": "Meal Allowance", "default_amount": 1500.00 } ],
    "deductions": [ { "component_name": "SSS", "default_amount": 1200.00 } ],
    "total_allow": 3500.00,
    "total_deduct": 4700.00,
    "net_pay": 53800.00,
    "history": { "total_records": 3, "total_earned": 161400.00, "avg_net": 53800.00 }
  }
}
```

---

## Endpoint 26 — List All Pay Components
`GET /api/benefits/all`

**Access:** All authenticated users

---

## Endpoint 27 — List Requests
`GET /api/requests`

**Access:** All authenticated users (role-filtered — Employee sees own only)

**Query Parameters:** `status` (Pending / Approved / Rejected)

---

## Endpoint 28 — Submit Request
`POST /api/requests`

**Access:** Employee only

**Request Body:**
```json
{ "request_type": "Leave - Sick", "details": "Fever and flu symptoms, doctor's certificate attached." }
```

**Response:**
```json
{ "success": true, "message": "Request submitted." }
```

---

## Endpoint 29 — Review Request (Approve / Reject)
`PUT /api/requests/{id}`

**Access:** Manager and Admin

**Request Body:**
```json
{ "action": "approve", "review_note": "Approved. Get well soon." }
```

**Response:**
```json
{ "success": true, "message": "Request approved." }
```

---

## Endpoint 30 — Pending Request Count (Badge)
`GET /api/requests/pending-count`

**Access:** Admin and Manager

**Response:**
```json
{ "success": true, "count": 3 }
```

---

## Endpoint 31 — Warehouse Fact Table
`GET /api/warehouse/facts`

**Access:** Admin only

---

## Endpoint 32 — Data Mart
`GET /api/warehouse/mart`

**Access:** Admin only

---

## Endpoint 33 — Quarterly Aggregation
`GET /api/warehouse/quarterly`

**Access:** Admin only

---

## Endpoint 34 — Run ETL ⭐
`POST /api/warehouse/etl`

**Access:** Admin only

**Description:** Calls the MySQL stored procedure `sp_run_etl()` which performs Extract-Transform-Load into the star schema (dim_date, dim_employee, dim_department, fact_payroll). Full-reload strategy inside a single transaction.

**Response:**
```json
{ "success": true, "message": "ETL completed successfully." }
```

---

## Endpoint 35 — List Users
`GET /api/users`

**Access:** Admin only

---

## Endpoint 36 — Add User
`POST /api/users`

**Access:** Admin only

**Request Body:**
```json
{ "username": "manager2", "full_name": "Manager Two", "password": "secret123", "role": "Manager" }
```

> Role must be one of: `Admin`, `Manager`, `Employee`

---

## Endpoint 37 — Update User
`PUT /api/users/{id}`

**Access:** Admin only (cannot demote own role)

**Request Body:**
```json
{ "full_name": "Updated Name", "role": "Manager", "status": "Active" }
```

---

## Endpoint 38 — Delete User ⭐
`DELETE /api/users/{id}`

**Access:** Admin only

**Description:** Admin cannot delete their own account (returns 422). Audit log entries for the deleted user are preserved with `user_id` set to NULL.

**Self-deletion Response (422):**
```json
{ "success": false, "message": "You cannot delete your own account." }
```

**Success Response:**
```json
{ "success": true, "message": "User 'manager2' deleted successfully." }
```

---

## Endpoint 39 — Reset Password
`POST /api/users/{id}/reset`

**Access:** Admin only

**Request Body:**
```json
{ "password": "newpassword123" }
```

---

## Endpoint 40 — Audit Log
`GET /api/audit-log`

**Access:** Admin only

**Query Parameters:** `username`, `action`

**Response:**
```json
{
  "success": true,
  "data": [
    { "log_id": 18, "username": "admin", "role": "Admin", "action": "Process Payroll", "target": "payroll_records", "detail": "Month=5 Year=2025 Inserted=8", "ip_address": "127.0.0.1", "logged_at": "2025-05-01 09:12:00" }
  ]
}
```

---

## Role Access Summary

| Endpoint Group | Admin | Manager | Employee |
|---|---|---|---|
| Login / Logout / Me / Currency | ✅ | ✅ | ✅ |
| Dashboard | ✅ Full stats | ✅ Full stats | ✅ Own data only |
| Employees — View / Search | ✅ | ✅ | ✅ Own only |
| Employees — Add / Edit | ✅ | ✅ | ❌ |
| Employees — Delete | ✅ | ❌ | ❌ |
| Employee — Own Phone Update | ❌ | ❌ | ✅ |
| CSV Import | ✅ | ✅ | ❌ |
| Payroll — View / Preview / Rankings | ✅ | ✅ | ✅ Own only |
| Payroll — Process | ✅ | ❌ | ❌ |
| Payroll — Export | ✅ | ✅ | ✅ |
| Attendance — View | ✅ | ✅ | ✅ |
| Attendance — Add / Edit | ✅ | ✅ | ❌ |
| Benefits | ✅ | ✅ | ✅ Own only |
| Requests — View | ✅ | ✅ | ✅ Own only |
| Requests — Submit | ❌ | ❌ | ✅ |
| Requests — Review (Approve/Reject) | ✅ | ✅ | ❌ |
| Warehouse / ETL | ✅ | ❌ | ❌ |
| Users — View / Add / Edit / Delete | ✅ | ❌ | ❌ |
| Audit Log | ✅ | ❌ | ❌ |

---

## Error Codes Summary

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 401 | Unauthenticated (no/invalid token) |
| 403 | Forbidden (wrong role) |
| 404 | Not found |
| 409 | Conflict (optimistic lock violation) |
| 422 | Unprocessable (validation or integrity error) |
| 500 | Server error (transaction rolled back, ETL failed) |
