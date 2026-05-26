import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _requests = [];
  bool _loading  = true;
  String? _error;
  String _status = 'Pending';

  @override void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); _load(); }
  @override void dispose()   { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getRequests(status: _status);
      setState(() { _requests = res['data'] ?? []; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  void _switchTab(int i) {
    _status = ['Pending','Approved','Rejected'][i];
    _load();
  }

  void _showSubmitSheet() {
    String type = 'Leave - Sick';
    final detCtrl = TextEditingController();
    bool saving = false;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(ctx).viewInsets.bottom+20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('New Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(initialValue: type, dropdownColor: kCardBg,
            style: const TextStyle(color: Colors.white, fontSize: 13), decoration: darkInput('Request Type'),
            items: ['Leave - Sick','Leave - Vacation','Absence Excuse','Name Change','Email Change','Other']
              .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setS(() => type = v!)),
          const SizedBox(height: 10),
          TextField(controller: detCtrl, maxLines: 4, style: const TextStyle(color: Colors.white),
            decoration: darkInput('Details', hint: 'Describe your request in detail (min. 10 characters)…')),
          const SizedBox(height: 6),
          Text('→ Will be reviewed by: ${['Name Change','Email Change','Other'].contains(type)?"Admin":"Manager"}',
            style: const TextStyle(color: kTextMuted, fontSize: 11)),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Submit Request', loading: saving, onPressed: () async {
            setS(() => saving = true);
            final res = await ApiService.submitRequest(type, detCtrl.text);
            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']??''), backgroundColor: res['success']==true?kSuccess:kDanger));
              if (res['success']==true) { context.read<AuthService>().refreshPending(); _load(); }
            }
          }),
        ]),
      )));
  }

  Future<void> _review(Map req, String action) async {
    final noteCtrl = TextEditingController();
    final confirm  = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: kCardBg,
      title: Text(action=='approve'?'Approve Request':'Reject Request', style: const TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${req['request_type']} from ${req['employee_name']}', style: const TextStyle(color: kTextMuted)),
        const SizedBox(height: 12),
        TextField(controller: noteCtrl, style: const TextStyle(color: Colors.white), decoration: darkInput('Note (optional)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: Text(action=='approve'?'Approve':'Reject', style: TextStyle(color: action=='approve'?kSuccess:kDanger))),
      ],
    ));
    if (confirm != true) return;
    final res = await ApiService.reviewRequest(req['request_id'], action, note: noteCtrl.text);
    if (mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(res['message']??''), backgroundColor: res['success']==true?kSuccess:kDanger));
      if (res['success']==true) { context.read<AuthService>().refreshPending(); _load(); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthService>();
    final isEmp  = auth.isEmployee;
    return Scaffold(backgroundColor: Colors.transparent,
      body: Column(children: [
        Container(color: kSurface, child: TabBar(controller: _tabs, labelColor: kAccent, unselectedLabelColor: kTextMuted, indicatorColor: kAccent,
          onTap: _switchTab,
          tabs: const [Tab(text: 'Pending'), Tab(text: 'Approved'), Tab(text: 'Rejected')])),
        if (_loading) const Expanded(child: LoadingIndicator())
        else if (_error != null) Expanded(child: ErrorView(message: _error!, onRetry: _load))
        else if (_requests.isEmpty) Expanded(child: EmptyView(message: 'No ${_status.toLowerCase()} requests.'))
        else Expanded(child: RefreshIndicator(color: kAccent, onRefresh: _load, child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _requests.length,
          itemBuilder: (_, i) {
            final r   = _requests[i];
            final col = r['status']=='Pending' ? kWarning : r['status']=='Approved' ? kSuccess : kDanger;
            return Container(margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: col.withValues(alpha: 0.35))),
              child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  AppBadge(label: r['request_type']??'', color: r['request_type']?.contains('Leave')??false ? kBlue : kPurple),
                  Text(r['created_at']?.toString().substring(0,10)??'', style: const TextStyle(color: kTextMuted, fontSize: 10)),
                ]),
                const SizedBox(height: 8),
                if (!isEmp) ...[
                  Text(r['employee_name']??'', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(r['department_name']??'', style: const TextStyle(color: kTextMuted, fontSize: 11)),
                  const SizedBox(height: 6),
                ],
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(6)),
                  child: Text(r['details']??'', style: const TextStyle(color: Colors.white, fontSize: 12))),
                const SizedBox(height: 8),
                Text('Reviewed by: ${r['handled_by']}', style: const TextStyle(color: kTextMuted, fontSize: 11)),
                if (r['status']=='Pending' && !isEmp) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: ElevatedButton.icon(onPressed: () => _review(r, 'approve'), icon: const Icon(Icons.check, size: 14), label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(backgroundColor: kSuccess, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8)))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _review(r, 'reject'), icon: const Icon(Icons.close, size: 14, color: kDanger), label: const Text('Reject', style: TextStyle(color: kDanger)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: kDanger), padding: const EdgeInsets.symmetric(vertical: 8)))),
                  ]),
                ] else if (r['status'] != 'Pending') ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(r['status']=='Approved' ? Icons.check_circle_outline : Icons.cancel_outlined, color: col, size: 14),
                    const SizedBox(width: 4),
                    Text('${r['status']} by ${r['reviewer_name']??''}', style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                  if (r['review_note']!=null && r['review_note'].toString().isNotEmpty)
                    Text('"${r['review_note']}"', style: const TextStyle(color: kTextMuted, fontSize: 11, fontStyle: FontStyle.italic)),
                ] else ...[
                  const SizedBox(height: 6),
                  Text('Awaiting ${r['handled_by']} review…', style: const TextStyle(color: kWarning, fontSize: 11)),
                ],
              ])));
          }
        ))),
      ]),
      floatingActionButton: isEmp ? FloatingActionButton.extended(onPressed: _showSubmitSheet, backgroundColor: kAccent, icon: const Icon(Icons.add), label: const Text('New Request')) : null,
    );
  }
}

// ============================================================
// lib/screens/employees_screen.dart (condensed)
// ============================================================