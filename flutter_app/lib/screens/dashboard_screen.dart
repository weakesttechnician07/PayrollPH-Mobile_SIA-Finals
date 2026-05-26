// ============================================================
// lib/screens/dashboard_screen.dart
// Employee: own net pay, attendance, benefits, recent payroll
// Admin/Manager: full stats, dept breakdown, recent records,
//                pending requests badge
// ============================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getDashboard();
      if (res['success'] == true) setState(() { _data = res['data']; _loading = false; });
      else setState(() { _error = res['message']; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final auth = context.watch<AuthService>();
    final d    = _data!;

    if (auth.isEmployee) return _buildEmployeeDashboard(d, auth);
    return _buildAdminManagerDashboard(d, auth);
  }

  // ── Employee Dashboard ────────────────────────────────────
  Widget _buildEmployeeDashboard(Map d, AuthService auth) {
    final emp        = d['employee'];
    final latestPay  = d['latest_pay'];
    final latestAtt  = d['latest_attendance'];
    final totalRec   = d['total_pay_records'] ?? 0;
    final recentPay  = d['recent_payroll'] as List? ?? [];
    final benefits   = d['benefits'] as List? ?? [];
    final totalAllow = benefits.where((b) => b['component_type']=='Allowance').fold(0.0,(s,b)=>s+(double.tryParse(b['default_amount'].toString())??0));
    final totalDeduct= benefits.where((b) => b['component_type']=='Deduction').fold(0.0,(s,b)=>s+(double.tryParse(b['default_amount'].toString())??0));

    if (emp == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.warning_amber_rounded, color: kWarning, size: 48),
        const SizedBox(height: 12),
        const Text('No employee record linked to your account.', textAlign: TextAlign.center, style: TextStyle(color: kTextMuted)),
        const Text('Contact your Admin.', style: TextStyle(color: kTextMuted, fontSize: 12)),
      ])));
    }

    return RefreshIndicator(color: kAccent, onRefresh: _load, child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.person_rounded, color: kAccent)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Welcome, ${(emp['first_name'] ?? '').split(' ').first}!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('${emp['position_title']} — ${emp['department_name']}', style: const TextStyle(color: kTextMuted, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 16),

        // Stat cards
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.4,
          children: [
            StatCard(label: 'Latest Net Pay', icon: Icons.savings_rounded, color: kAccent,
              value: latestPay != null ? auth.formatMoney(latestPay['net_pay']) : '—',
              subtitle: latestPay != null ? 'Month ${latestPay['payroll_month']}/${latestPay['payroll_year']}' : null),
            StatCard(label: 'Days Worked', icon: Icons.calendar_today_rounded, color: kBlue,
              value: latestAtt != null ? '${latestAtt['days_worked']}' : '—',
              subtitle: latestAtt != null ? '${latestAtt['days_present']} present' : null),
            StatCard(label: 'Absences', icon: Icons.event_busy_rounded, color: kDanger,
              value: latestAtt != null ? '${latestAtt['days_absent']}' : '—'),
            StatCard(label: 'Total Records', icon: Icons.receipt_rounded, color: kSuccess,
              value: '$totalRec'),
          ],
        ),
        const SizedBox(height: 16),

        // Pay components summary
        SectionCard(
          title: 'Pay Components',
          trailing: TextButton(onPressed: () {}, child: const Text('View all', style: TextStyle(color: kAccent, fontSize: 11))),
          child: Column(children: [
            ...benefits.map((b) => ListTile(dense: true,
              title: Text(b['component_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
              trailing: Text(
                '${b['component_type']=='Allowance'?'+':'-'}${auth.formatMoney(b['default_amount'])}',
                style: TextStyle(color: b['component_type']=='Allowance' ? kSuccess : kDanger, fontWeight: FontWeight.w600, fontSize: 12)),
            )),
            Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorder))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Net Adjustment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                Text('${totalAllow-totalDeduct>=0?'+':''}${auth.formatMoney(totalAllow-totalDeduct)}',
                  style: TextStyle(color: totalAllow-totalDeduct>=0?kSuccess:kDanger, fontWeight: FontWeight.w700, fontSize: 12)),
              ])),
          ]),
        ),

        // Recent payroll
        SectionCard(
          title: 'My Recent Payroll',
          child: recentPay.isEmpty
            ? const Padding(padding: EdgeInsets.all(16), child: EmptyView(message: 'No payroll records yet.'))
            : Column(children: recentPay.map((r) => ListTile(dense: true,
              title: Text('Month ${r['payroll_month']}/${r['payroll_year']}', style: const TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: Text('Basic: ${auth.formatMoney(r['basic_salary'])}', style: const TextStyle(color: kTextMuted, fontSize: 11)),
              trailing: Text(auth.formatMoney(r['net_pay']), style: const TextStyle(color: kSuccess, fontWeight: FontWeight.w600, fontSize: 13)),
            )).toList()),
        ),
      ]),
    ));
  }

  // ── Admin/Manager Dashboard ───────────────────────────────
  Widget _buildAdminManagerDashboard(Map d, AuthService auth) {
    final deptStats  = d['dept_stats']    as List? ?? [];
    final recent     = d['recent_payroll'] as List? ?? [];
    final pending    = d['pending_requests'] ?? 0;

    return RefreshIndicator(color: kAccent, onRefresh: _load, child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 16),

        // Pending requests alert
        if (pending > 0) Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kWarning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: kWarning.withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.notifications_active_rounded, color: kWarning, size: 18),
            const SizedBox(width: 10),
            Text('$pending pending request${pending!=1?'s':''} awaiting review', style: const TextStyle(color: kWarning, fontSize: 12)),
          ]),
        ),

        // Stat grid
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.4,
          children: [
            StatCard(label: 'Active Employees', value: '${d['total_employees']}', icon: Icons.people_rounded),
            StatCard(label: 'Payroll Records',  value: '${d['total_records']}',   icon: Icons.receipt_rounded, color: kBlue),
            StatCard(label: 'Total Net Pay',    value: auth.formatMoney(d['total_paid']), icon: Icons.savings_rounded, color: kSuccess),
            StatCard(label: 'Last Payroll',     value: d['last_payroll']!=null ? d['last_payroll'].toString().substring(0,10) : 'None', icon: Icons.calendar_today_rounded, color: kWarning),
          ],
        ),
        const SizedBox(height: 16),

        // Dept breakdown
        SectionCard(title: 'Department Breakdown', child: Column(children: deptStats.map((dept) => ListTile(dense: true,
          title: Text(dept['department_name']??'', style: const TextStyle(color: Colors.white, fontSize: 13)),
          trailing: Text('${dept['emp_count']} emp · ${dept['payroll_count']} runs', style: const TextStyle(color: kTextMuted, fontSize: 11)),
        )).toList())),

        // Recent payroll
        SectionCard(title: 'Recent Payroll Records', child: recent.isEmpty
          ? const Padding(padding: EdgeInsets.all(16), child: EmptyView(message: 'No records yet.'))
          : Column(children: recent.map((r) => ListTile(dense: true,
            title: Text(r['employee_name']??'', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text('${r['department_name']} · ${r['payroll_month']}/${r['payroll_year']}', style: const TextStyle(color: kTextMuted, fontSize: 11)),
            trailing: Text(auth.formatMoney(r['net_pay']), style: const TextStyle(color: kSuccess, fontWeight: FontWeight.w600, fontSize: 13)),
          )).toList()),
        ),
      ]),
    ));
  }
}
