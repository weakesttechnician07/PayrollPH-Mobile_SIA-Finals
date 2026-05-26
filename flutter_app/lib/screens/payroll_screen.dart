import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});
  @override State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  int _month = DateTime.now().month;
  int _year  = DateTime.now().year;
  Map<String, dynamic>? _preview;
  bool _loadingPreview = false, _processing = false;
  String? _msg; bool _msgOk = true;

  final _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  Future<void> _loadPreview() async {
    setState(() { _loadingPreview = true; _preview = null; _msg = null; });
    try {
      final res = await ApiService.getPayrollPreview(_month, _year);
      setState(() { _preview = res['success']==true ? res['data'] : null; _loadingPreview = false; });
    } catch (e) { setState(() => _loadingPreview = false); }
  }

  Future<void> _process() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: kCardBg,
      title: const Text('Process Payroll', style: TextStyle(color: Colors.white)),
      content: Text('Run payroll for ${_months[_month-1]} $_year?\n\nThis uses a DB transaction (BEGIN → COMMIT/ROLLBACK) and SELECT FOR UPDATE.', style: const TextStyle(color: kTextMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Run', style: TextStyle(color: kAccent))),
      ],
    ));
    if (ok != true) return;
    setState(() { _processing = true; _msg = null; });
    try {
      final res = await ApiService.processPayroll(_month, _year);
      setState(() { _msg = res['message']; _msgOk = res['success']==true; });
      if (res['success']==true) _loadPreview();
    } catch (e) { setState(() { _msg = e.toString(); _msgOk = false; }); }
    finally { setState(() => _processing = false); }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isAdmin) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.lock_rounded, color: kDanger, size: 48),
      const SizedBox(height: 12),
      const Text('Admin access required', style: TextStyle(color: kDanger, fontWeight: FontWeight.w600)),
      const Text('Only Admins can process payroll.', style: TextStyle(color: kTextMuted)),
    ])));

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Process Payroll', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
      const Text('Attendance-aware · Transaction · FOR UPDATE · Admin only', style: TextStyle(color: kTextMuted, fontSize: 11)),
      const SizedBox(height: 16),

      if (_msg != null) Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: (_msgOk?kSuccess:kDanger).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: (_msgOk?kSuccess:kDanger).withValues(alpha: 0.3))),
        child: Text(_msg!, style: TextStyle(color: _msgOk?kSuccess:kDanger, fontSize: 12))),

      SectionCard(title: 'Payroll Period', child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        Row(children: [
          Expanded(child: DropdownButtonFormField<int>(initialValue: _month, dropdownColor: kCardBg,
            style: const TextStyle(color: Colors.white, fontSize: 13), decoration: darkInput('Month'),
            items: List.generate(12, (i) => DropdownMenuItem(value: i+1, child: Text(_months[i]))),
            onChanged: (v) => setState(() { _month = v!; _preview = null; }))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<int>(initialValue: _year, dropdownColor: kCardBg,
            style: const TextStyle(color: Colors.white, fontSize: 13), decoration: darkInput('Year'),
            items: List.generate(5, (i) => DateTime.now().year - i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
            onChanged: (v) => setState(() { _year = v!; _preview = null; }))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _loadPreview,
            icon: const Icon(Icons.preview_rounded, size: 16), label: const Text('Preview'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: kBorder)))),
          const SizedBox(width: 10),
          Expanded(child: PrimaryButton(label: 'Run Payroll', icon: Icons.play_arrow_rounded, onPressed: _process, loading: _processing)),
        ]),
      ]))),

      // No-attendance warning
      if (_preview != null && (_preview!['no_attendance_count'] ?? 0) > 0) Container(
        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: kWarning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: kWarning.withValues(alpha: 0.3))),
        child: Text('⚠ ${_preview!['no_attendance_count']} employee(s) have no attendance record — full salary will be used (22 days assumed).', style: const TextStyle(color: kWarning, fontSize: 11))),

      if (_loadingPreview) const LoadingIndicator()
      else if (_preview != null) SectionCard(
        title: 'Preview — ${_months[_month-1]} $_year',
        trailing: Text('Total: ${auth.formatMoney(_preview!['total_net'])}', style: const TextStyle(color: kSuccess, fontWeight: FontWeight.w600, fontSize: 12)),
        child: Column(children: (_preview!['employees'] as List).map((emp) => Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
          child: ListTile(dense: true,
            title: Text(emp['full_name']??'', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${emp['department_name']} · ${emp['days_present']}/${emp['working_days']} days present', style: const TextStyle(color: kTextMuted, fontSize: 11)),
              if ((emp['days_absent']??0) > 0) Text('Absent: ${emp['days_absent']} days → -${auth.formatMoney(emp['absence_deduction'])}', style: const TextStyle(color: kDanger, fontSize: 10)),
            ]),
            trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(auth.formatMoney(emp['net_pay']), style: const TextStyle(color: kSuccess, fontWeight: FontWeight.w600, fontSize: 12)),
              AppBadge(label: (emp['already_processed']??0) > 0 ? 'Done' : 'Pending',
                color: (emp['already_processed']??0) > 0 ? kWarning : kBlue),
            ]),
          ))) .toList()),
      ),
    ]));
  }
}

// ============================================================
// lib/screens/warehouse_screen.dart — Admin only
// ============================================================