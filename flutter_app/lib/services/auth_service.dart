// ============================================================
// lib/services/auth_service.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  bool _isLoggedIn = false;
  Map<String, dynamic>? _user;
  String _currency = 'PHP';
  int _pendingCount = 0;

  bool get isLoggedIn   => _isLoggedIn;
  Map<String, dynamic>? get user => _user;
  String get role       => _user?['role'] ?? 'Employee';
  String get currency   => _currency;
  int    get pendingCount => _pendingCount;
  bool   get isAdmin    => role == 'Admin';
  bool   get isManager  => role == 'Manager';
  bool   get isEmployee => role == 'Employee';
  bool   get canEdit    => role == 'Admin' || role == 'Manager';

  AuthService() { _checkLogin(); }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      try {
        final res = await ApiService.getMe();
        if (res['success'] == true) {
          _user      = res['user'];
          _currency  = res['user']['currency'] ?? 'PHP';
          _isLoggedIn = true;
          notifyListeners();
          _refreshPendingCount();
        } else {
          await prefs.remove('auth_token');
        }
      } catch (_) { await prefs.remove('auth_token'); }
    }
  }

  Future<String?> login(String username, String password) async {
    try {
      final res = await ApiService.login(username, password);
      if (res['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', res['token']);
        _user      = res['user'];
        _currency  = res['user']['currency'] ?? 'PHP';
        _isLoggedIn = true;
        notifyListeners();
        _refreshPendingCount();
        return null;
      }
      return res['message'] ?? 'Login failed.';
    } catch (e) {
      return 'Connection error. Is the Laravel server running?';
    }
  }

  Future<void> logout() async {
    try { await ApiService.logout(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _user        = null;
    _isLoggedIn  = false;
    _pendingCount = 0;
    notifyListeners();
  }

  Future<void> toggleCurrency() async {
    _currency = _currency == 'PHP' ? 'USD' : 'PHP';
    notifyListeners();
    try { await ApiService.setCurrency(_currency); } catch (_) {}
  }

  Future<void> _refreshPendingCount() async {
    try {
      final res = await ApiService.getPendingCount();
      if (res['success'] == true) {
        _pendingCount = res['count'] ?? 0;
        notifyListeners();
      }
    } catch (_) {}
  }

  void refreshPending() => _refreshPendingCount();

  // Format money with currency toggle
  String formatMoney(dynamic amount, {double usdRate = 56.0}) {
    final val = double.tryParse(amount.toString()) ?? 0.0;
    if (_currency == 'USD') {
      return '\$${(val / usdRate).toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';
    }
    return '₱${val.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';
  }
}
