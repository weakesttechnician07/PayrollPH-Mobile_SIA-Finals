// ============================================================
// lib/screens/main_screen.dart
// Role-based bottom navigation + currency toggle in AppBar
// Admin:    Dashboard, Employees, Payroll, History, Warehouse, Requests, Users
// Manager:  Dashboard, Employees, History, Requests
// Employee: Dashboard, My Profile, My Benefits, My History, My Requests
// ============================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import 'dashboard_screen.dart';
import 'employees_screen.dart';
import 'payroll_screen.dart';
import 'history_screen.dart';
import 'warehouse_screen.dart';
import 'requests_screen.dart';
import 'users_screen.dart';
import 'benefits_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthService>();
    final isAdmin  = auth.isAdmin;
    final isMgr    = auth.isManager;
    final isEmp    = auth.isEmployee;
    final pending  = auth.pendingCount;

    // ── Screens per role ──────────────────────────────────────
    final List<Widget> screens;
    final List<BottomNavigationBarItem> items;

    if (isEmp) {
      screens = [
        const DashboardScreen(),
        const EmployeesScreen(),
        const BenefitsScreen(),
        const HistoryScreen(),
        const RequestsScreen(),
      ];
      items = [
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded),        label: 'Dashboard'),
        const BottomNavigationBarItem(icon: Icon(Icons.person_rounded),            label: 'My Profile'),
        const BottomNavigationBarItem(icon: Icon(Icons.card_giftcard_rounded),     label: 'Benefits'),
        const BottomNavigationBarItem(icon: Icon(Icons.history_rounded),           label: 'My Payroll'),
        BottomNavigationBarItem(
          icon: Stack(children: [
            const Icon(Icons.inbox_rounded),
            if (pending > 0) Positioned(right: 0, top: 0, child: PendingBadge(count: pending)),
          ]),
          label: 'Requests',
        ),
      ];
    } else if (isMgr) {
      screens = [
        const DashboardScreen(),
        const EmployeesScreen(),
        const HistoryScreen(),
        const RequestsScreen(),
      ];
      items = [
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded),  label: 'Dashboard'),
        const BottomNavigationBarItem(icon: Icon(Icons.people_rounded),      label: 'Employees'),
        const BottomNavigationBarItem(icon: Icon(Icons.history_rounded),     label: 'History'),
        BottomNavigationBarItem(
          icon: Stack(children: [
            const Icon(Icons.inbox_rounded),
            if (pending > 0) Positioned(right: 0, top: 0, child: PendingBadge(count: pending)),
          ]),
          label: 'Requests',
        ),
      ];
    } else {
      // Admin
      screens = [
        const DashboardScreen(),
        const EmployeesScreen(),
        const PayrollScreen(),
        const HistoryScreen(),
        const WarehouseScreen(),
        const RequestsScreen(),
        const UsersScreen(),
      ];
      items = [
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded),    label: 'Dashboard'),
        const BottomNavigationBarItem(icon: Icon(Icons.people_rounded),        label: 'Employees'),
        const BottomNavigationBarItem(icon: Icon(Icons.payments_rounded),      label: 'Payroll'),
        const BottomNavigationBarItem(icon: Icon(Icons.history_rounded),       label: 'History'),
        const BottomNavigationBarItem(icon: Icon(Icons.storage_rounded),       label: 'Warehouse'),
        BottomNavigationBarItem(
          icon: Stack(children: [
            const Icon(Icons.inbox_rounded),
            if (pending > 0) Positioned(right: 0, top: 0, child: PendingBadge(count: pending)),
          ]),
          label: 'Requests',
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.shield_rounded),        label: 'Users'),
      ];
    }

    final safeIndex = _index.clamp(0, screens.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.account_balance_wallet_rounded, color: kAccent, size: 20),
          const SizedBox(width: 8),
          const Text('PayrollPH', style: TextStyle(fontWeight: FontWeight.w700, color: kAccent)),
        ]),
        actions: [
          // Currency toggle
          GestureDetector(
            onTap: () => auth.toggleCurrency(),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(auth.currency == 'PHP' ? '₱' : '\$',
                  style: const TextStyle(color: kAccent, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 4),
                Text(auth.currency, style: const TextStyle(color: kTextMuted, fontSize: 11)),
              ]),
            ),
          ),
          // Role badge + logout
          PopupMenuButton<Object>(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(isAdmin ? '👑' : isMgr ? '🏢' : '👤', style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(auth.role, style: TextStyle(
                  color: isAdmin ? kAccent : isMgr ? kBlue : kSuccess,
                  fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
            itemBuilder: (_) => <PopupMenuEntry<Object>>[
              PopupMenuItem<Object>(
                enabled: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(auth.user?['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                  Text(auth.user?['username'] ?? '', style: const TextStyle(color: kTextMuted, fontSize: 11)),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<Object>(
                onTap: () async {
                  final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                    backgroundColor: kCardBg,
                    title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                    content: const Text('Are you sure?', style: TextStyle(color: kTextMuted)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out', style: TextStyle(color: kDanger))),
                    ],
                  ));
                  if (confirm == true && context.mounted) auth.logout();
                },
                child: const Row(children: [Icon(Icons.logout, color: kDanger, size: 16), SizedBox(width: 8), Text('Sign Out', style: TextStyle(color: kDanger))]),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: screens[safeIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (i) {
          setState(() => _index = i);
          // Refresh pending count when switching to requests
          if (i == items.indexWhere((item) => item.label == 'Requests')) {
            auth.refreshPending();
          }
        },
        backgroundColor: kSurface,
        selectedItemColor: kAccent,
        unselectedItemColor: kTextMuted,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: items,
      ),
    );
  }
}