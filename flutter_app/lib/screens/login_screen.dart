// ============================================================
// lib/screens/login_screen.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false, _obscure = true;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final err = await context.read<AuthService>().login(_userCtrl.text.trim(), _passCtrl.text);
    if (mounted) setState(() { _loading = false; _error = err; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.account_balance_wallet_rounded, color: kAccent, size: 56),
      const SizedBox(height: 12),
      const Text('PayrollPH', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: kAccent)),
      const Text('IT221 + WebSys + SIA', style: TextStyle(color: kTextMuted, fontSize: 12)),
      const SizedBox(height: 36),
      if (_error != null) ...[
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kDanger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: kDanger.withValues(alpha: 0.3))),
          child: Row(children: [const Icon(Icons.warning_amber, color: kDanger, size: 16), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: kDanger, fontSize: 12)))])),
        const SizedBox(height: 16),
      ],
      TextField(controller: _userCtrl, style: const TextStyle(color: Colors.white), decoration: darkInput('Username', hint: 'Enter username')),
      const SizedBox(height: 12),
      TextField(controller: _passCtrl, obscureText: _obscure, style: const TextStyle(color: Colors.white),
        decoration: darkInput('Password', hint: 'Enter password',
          suffix: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: kTextMuted, size: 18), onPressed: () => setState(() => _obscure = !_obscure))),
        onSubmitted: (_) => _login()),
      const SizedBox(height: 24),
      PrimaryButton(label: 'Sign In', icon: Icons.login, onPressed: _login, loading: _loading),
      const SizedBox(height: 16),
      const Text('Default: admin / password', style: TextStyle(color: kTextMuted, fontSize: 11)),
    ])))));
  }
}
