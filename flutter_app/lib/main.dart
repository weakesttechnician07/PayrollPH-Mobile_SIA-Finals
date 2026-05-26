// ============================================================
// lib/main.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(MultiProvider(providers: [ChangeNotifierProvider(create: (_) => AuthService())], child: const PayrollApp()));
}

class PayrollApp extends StatelessWidget {
  const PayrollApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayrollPH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE94560), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        cardColor: const Color(0xFF1A2744),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF16213E), foregroundColor: Color(0xFFE8EAF0), elevation: 0),
      ),
      home: Consumer<AuthService>(builder: (_, auth, __) => auth.isLoggedIn ? const MainScreen() : const LoginScreen()),
    );
  }
}
