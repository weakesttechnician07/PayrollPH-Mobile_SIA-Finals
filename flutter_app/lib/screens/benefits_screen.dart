import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

class BenefitsScreen extends StatefulWidget {
  const BenefitsScreen({super.key});
  @override State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getMyBenefits();
      if (res['success'] == true) setState(() { _data = res['data']; _loading = false; });
      else setState(() { _error = res['message']; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (_loading) return const LoadingIndicator();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final d          = _data!;
    final emp        = d['employee'];
    final allowances = d['allowances'] as List? ?? [];
    final deductions = d['deductions'] as List? ?? [];
    final totalAllow = double.tryParse(d['total_allow'].toString()) ?? 0;
    final totalDeduct= double.tryParse(d['total_deduct'].toString()) ?? 0;
    final basicSal   = double.tryParse(emp['base_salary'].toString()) ?? 0;
    final netPay     = double.tryParse(d['net_pay'].toString()) ?? 0;
    final hist       = d['history'];

    return RefreshIndicator(color: kAccent, onRefresh: _load, child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('My Benefits', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        const Text('Pay components and deduction breakdown', style: TextStyle(color: kTextMuted, fontSize: 12)),
        const SizedBox(height: 16),

        // Employee info card
        Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kAccent.withValues(alpha: 0.3))),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.person_rounded, color: kAccent, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${emp['first_name']} ${emp['last_name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
              Text('${emp['position_title']} — ${emp['department_name']}', style: const TextStyle(color: kTextMuted, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Base Salary', style: TextStyle(color: kTextMuted, fontSize: 10)),
              Text(auth.formatMoney(basicSal), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
            ]),
          ]),
        ),

        // Summary stats
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.3,
          children: [
            StatCard(label: 'Basic',      value: auth.formatMoney(basicSal),   icon: Icons.wallet_rounded),
            StatCard(label: 'Gross Pay',  value: auth.formatMoney(basicSal+totalAllow), icon: Icons.trending_up_rounded, color: kSuccess),
            StatCard(label: 'Est. Net',   value: auth.formatMoney(netPay),     icon: Icons.savings_rounded, color: kBlue),
          ]),
        const SizedBox(height: 16),

        // Allowances
        SectionCard(title: '+ Allowances & Benefits', child: Column(children: [
          ...allowances.map((a) => ListTile(dense: true,
            title: Text(a['component_name']??'', style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: const Text('Benefit / Addition', style: TextStyle(color: kTextMuted, fontSize: 11)),
            trailing: Text('+${auth.formatMoney(a['default_amount'])}', style: const TextStyle(color: kSuccess, fontWeight: FontWeight.w600)),
          )),
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorder)), color: Color(0x152ECC71)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total Allowances', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text('+${auth.formatMoney(totalAllow)}', style: const TextStyle(color: kSuccess, fontWeight: FontWeight.w700)),
            ])),
        ])),

        // Deductions
        SectionCard(title: '− Statutory Deductions', child: Column(children: [
          ...deductions.map((d) => ListTile(dense: true,
            title: Text(d['component_name']??'', style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: const Text('Statutory Deduction', style: TextStyle(color: kTextMuted, fontSize: 11)),
            trailing: Text('-${auth.formatMoney(d['default_amount'])}', style: const TextStyle(color: kDanger, fontWeight: FontWeight.w600)),
          )),
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorder)), color: Color(0x15E74C3C)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total Deductions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text('-${auth.formatMoney(totalDeduct)}', style: const TextStyle(color: kDanger, fontWeight: FontWeight.w700)),
            ])),
        ])),

        // Computation breakdown
        SectionCard(title: 'Monthly Pay Computation', child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          _compRow('Basic Salary',        auth.formatMoney(basicSal),             Colors.white),
          _compRow('+ Allowances',        auth.formatMoney(totalAllow),           kSuccess),
          const Divider(color: kBorder),
          _compRow('= Gross Pay',         auth.formatMoney(basicSal+totalAllow),  Colors.white),
          _compRow('− Deductions',        auth.formatMoney(totalDeduct),          kDanger),
          const Divider(color: kAccent, thickness: 1.5),
          _compRow('Estimated Net Pay',   auth.formatMoney(netPay),               kSuccess, bold: true),
        ]))),

        // History summary
        if (hist != null && (hist['total_records'] ?? 0) > 0)
          SectionCard(title: 'My Payroll Summary', child: Padding(padding: const EdgeInsets.all(16),
            child: Row(children: [
              _summCell('Records', '${hist['total_records']}', Colors.white),
              _summCell('Total Earned', auth.formatMoney(hist['total_earned']), kSuccess),
              _summCell('Avg Net', auth.formatMoney(hist['avg_net']), kBlue),
            ]))),
      ]),
    ));
  }

  Widget _compRow(String label, String value, Color color, {bool bold=false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: kTextMuted, fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
      Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
    ]));

  Widget _summCell(String label, String value, Color color) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    Text(label,  style: const TextStyle(color: kTextMuted, fontSize: 10)),
  ]));
}

// ============================================================
// lib/screens/requests_screen.dart
// ============================================================