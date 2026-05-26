// ============================================================
// lib/services/api_service.dart
// All API calls — updated v2 with requests, attendance,
// benefits, CSV import, pagination, currency
// ============================================================
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Android emulator: 10.0.2.2 | Real device: your local IP
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  // static const String baseUrl = 'http://192.168.205.219:8000/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (auth) {
      final token = await _getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  // ── Auth ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(Uri.parse('$baseUrl/login'), headers: await _headers(auth: false), body: jsonEncode({'username': username, 'password': password}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> logout() async {
    final res = await http.post(Uri.parse('$baseUrl/logout'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(Uri.parse('$baseUrl/me'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> setCurrency(String currency) async {
    final res = await http.post(Uri.parse('$baseUrl/currency'), headers: await _headers(), body: jsonEncode({'currency': currency}));
    return jsonDecode(res.body);
  }

  // ── Dashboard ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboard() async {
    final res = await http.get(Uri.parse('$baseUrl/dashboard'), headers: await _headers());
    return jsonDecode(res.body);
  }

  // ── Employees ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getEmployees({int page = 1, String q = '', int dept = 0}) async {
    final uri = Uri.parse('$baseUrl/employees').replace(queryParameters: {'page': '$page', 'q': q, 'dept': '$dept'});
    final res  = await http.get(uri, headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getMyEmployee() async {
    final res = await http.get(Uri.parse('$baseUrl/employees/me'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getEmployee(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/employees/$id'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> addEmployee(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/employees'), headers: await _headers(), body: jsonEncode(data));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateEmployee(int id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/employees/$id'), headers: await _headers(), body: jsonEncode(data));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteEmployee(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/employees/$id'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateMyPhone(String phone, int version) async {
    final res = await http.put(Uri.parse('$baseUrl/employees/me/phone'), headers: await _headers(), body: jsonEncode({'phone': phone, 'version': version}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> importCsv(String base64Csv) async {
    final res = await http.post(Uri.parse('$baseUrl/employees/import'), headers: await _headers(), body: jsonEncode({'csv': base64Csv}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getDepartments() async {
    final res = await http.get(Uri.parse('$baseUrl/departments'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getPositions() async {
    final res = await http.get(Uri.parse('$baseUrl/positions'), headers: await _headers());
    return jsonDecode(res.body);
  }

  // ── Payroll ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> getPayroll({int page = 1, int? dept, int? year, int? month}) async {
    final params = {'page': '$page'};
    if (dept  != null) params['dept']  = '$dept';
    if (year  != null) params['year']  = '$year';
    if (month != null) params['month'] = '$month';
    final uri = Uri.parse('$baseUrl/payroll').replace(queryParameters: params);
    final res = await http.get(uri, headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getPayrollPreview(int month, int year) async {
    final uri = Uri.parse('$baseUrl/payroll/preview').replace(queryParameters: {'month': '$month', 'year': '$year'});
    final res = await http.get(uri, headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> processPayroll(int month, int year) async {
    final res = await http.post(Uri.parse('$baseUrl/payroll/process'), headers: await _headers(), body: jsonEncode({'month': month, 'year': year}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getPayrollRanking({int? month, int? year}) async {
    final params = <String, String>{};
    if (month != null) params['month'] = '$month';
    if (year  != null) params['year']  = '$year';
    final uri = Uri.parse('$baseUrl/payroll/ranking').replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri, headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getPayrollSummary({int? year}) async {
    var uri = Uri.parse('$baseUrl/payroll/summary');
    if (year != null) uri = uri.replace(queryParameters: {'year': '$year'});
    final res = await http.get(uri, headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> exportPayroll({int? month, int? year}) async {
    final params = <String, String>{};
    if (month != null) params['month'] = '$month';
    if (year  != null) params['year']  = '$year';
    final uri = Uri.parse('$baseUrl/payroll/export').replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri, headers: await _headers());
    return jsonDecode(res.body);
  }

  // ── Attendance ────────────────────────────────────────────
  static Future<Map<String, dynamic>> getAttendance({int? month, int? year, int? employeeId}) async {
    final params = <String, String>{};
    if (month      != null) params['month']       = '$month';
    if (year       != null) params['year']        = '$year';
    if (employeeId != null) params['employee_id'] = '$employeeId';
    final uri = Uri.parse('$baseUrl/attendance').replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri, headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> saveAttendance(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/attendance'), headers: await _headers(), body: jsonEncode(data));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateAttendance(int id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/attendance/$id'), headers: await _headers(), body: jsonEncode(data));
    return jsonDecode(res.body);
  }

  // ── Benefits ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> getMyBenefits() async {
    final res = await http.get(Uri.parse('$baseUrl/benefits'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getAllComponents() async {
    final res = await http.get(Uri.parse('$baseUrl/benefits/all'), headers: await _headers());
    return jsonDecode(res.body);
  }

  // ── Requests ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> getRequests({String status = 'Pending'}) async {
    final uri = Uri.parse('$baseUrl/requests').replace(queryParameters: {'status': status});
    final res = await http.get(uri, headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> submitRequest(String type, String details) async {
    final res = await http.post(Uri.parse('$baseUrl/requests'), headers: await _headers(), body: jsonEncode({'request_type': type, 'details': details}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> reviewRequest(int id, String action, {String? note}) async {
    final res = await http.put(Uri.parse('$baseUrl/requests/$id'), headers: await _headers(), body: jsonEncode({'action': action, 'review_note': note ?? ''}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getPendingCount() async {
    final res = await http.get(Uri.parse('$baseUrl/requests/pending-count'), headers: await _headers());
    return jsonDecode(res.body);
  }

  // ── Warehouse ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getWarehouseFacts()     async { final res = await http.get(Uri.parse('$baseUrl/warehouse/facts'),     headers: await _headers()); return jsonDecode(res.body); }
  static Future<Map<String, dynamic>> getWarehouseMart()      async { final res = await http.get(Uri.parse('$baseUrl/warehouse/mart'),      headers: await _headers()); return jsonDecode(res.body); }
  static Future<Map<String, dynamic>> getWarehouseQuarterly() async { final res = await http.get(Uri.parse('$baseUrl/warehouse/quarterly'), headers: await _headers()); return jsonDecode(res.body); }
  static Future<Map<String, dynamic>> runEtl()                async { final res = await http.post(Uri.parse('$baseUrl/warehouse/etl'),     headers: await _headers()); return jsonDecode(res.body); }

  // ── Users & Audit ─────────────────────────────────────────
  static Future<Map<String, dynamic>> getUsers()    async { final res = await http.get(Uri.parse('$baseUrl/users'), headers: await _headers()); return jsonDecode(res.body); }
  static Future<Map<String, dynamic>> getAuditLog({String? username, String? action}) async {
    final params = <String, String>{};
    if (username != null) params['username'] = username;
    if (action   != null) params['action']   = action;
    final uri = Uri.parse('$baseUrl/audit-log').replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri, headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> addUser(Map<String, dynamic> data)        async { final res = await http.post(Uri.parse('$baseUrl/users'),             headers: await _headers(), body: jsonEncode(data)); return jsonDecode(res.body); }
  static Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> d) async { final res = await http.put(Uri.parse('$baseUrl/users/$id'),          headers: await _headers(), body: jsonEncode(d));    return jsonDecode(res.body); }
  static Future<Map<String, dynamic>> resetPassword(int id, String pw)           async { final res = await http.post(Uri.parse('$baseUrl/users/$id/reset'),   headers: await _headers(), body: jsonEncode({'password': pw})); return jsonDecode(res.body); }

  // ── DELETE /api/users/{id} — Admin only, added to match backend ──
  static Future<Map<String, dynamic>> deleteUser(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/users/$id'), headers: await _headers());
    return jsonDecode(res.body);
  }
}
