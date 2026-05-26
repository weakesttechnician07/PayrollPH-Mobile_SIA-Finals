import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List _emps=[]; List _depts=[]; List _pos=[];
  bool _loading=true; String? _error;
  int _page=1; int _totalPages=1; int _total=0;
  final _srch = TextEditingController();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load({int page=1}) async {
    setState(()=>_loading=true);
    try {
      final auth = context.read<AuthService>();
      if (auth.isEmployee) {
        final res = await ApiService.getMyEmployee();
        setState((){_emps=res['success']==true&&res['data']!=null?[res['data']]:[];_loading=false;});
      } else {
        final res  = await ApiService.getEmployees(page:page,q:_srch.text);
        final deps = await ApiService.getDepartments();
        final pos  = await ApiService.getPositions();
        setState((){_emps=res['data']??[];_depts=deps['data']??[];_pos=pos['data']??[];_page=page;_totalPages=res['total_pages']??1;_total=res['total']??0;_loading=false;});
      }
    } catch(e){setState((){_error=e.toString();_loading=false;});}
  }

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg),backgroundColor:ok?kSuccess:kDanger));

  void _showForm({Map? emp}) {
    final auth=context.read<AuthService>();
    if(emp!=null && !auth.canEdit) return;
    final fn=TextEditingController(text:emp?['first_name']??'');
    final ln=TextEditingController(text:emp?['last_name']??'');
    final em=TextEditingController(text:emp?['email']??'');
    final ph=TextEditingController(text:emp?['phone']??'');
    final hd=TextEditingController(text:emp?['hire_date']??'');
    int? deptId=emp!=null?(emp['department_id'] as num?)?.toInt():null;
    int? posId =emp!=null?(emp['position_id']  as num?)?.toInt():null;
    String status=emp?['status']??'Active'; bool saving=false;

    showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:kCardBg,
      shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(16))),
      builder:(ctx)=>StatefulBuilder(builder:(ctx,setS)=>Padding(
        padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(ctx).viewInsets.bottom+20),
        child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(emp!=null?'Edit Employee':'Add Employee',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:Colors.white)),
          const SizedBox(height:14),
          Row(children:[Expanded(child:TextField(controller:fn,style:const TextStyle(color:Colors.white),decoration:darkInput('First Name'))),const SizedBox(width:10),Expanded(child:TextField(controller:ln,style:const TextStyle(color:Colors.white),decoration:darkInput('Last Name')))]),
          const SizedBox(height:10),
          TextField(controller:em,style:const TextStyle(color:Colors.white),decoration:darkInput('Email'),keyboardType:TextInputType.emailAddress),
          const SizedBox(height:10),
          TextField(controller:ph,style:const TextStyle(color:Colors.white),decoration:darkInput('Phone')),
          const SizedBox(height:10),
          DropdownButtonFormField<int>(initialValue:deptId,dropdownColor:kCardBg,style:const TextStyle(color:Colors.white,fontSize:13),decoration:darkInput('Department'),
            items:_depts.map<DropdownMenuItem<int>>((d)=>DropdownMenuItem(value:(d['department_id'] as num).toInt(),child:Text(d['department_name']))).toList(),
            onChanged:(v)=>setS(()=>deptId=v)),
          const SizedBox(height:10),
          DropdownButtonFormField<int>(initialValue:posId,dropdownColor:kCardBg,style:const TextStyle(color:Colors.white,fontSize:13),decoration:darkInput('Position'),
            items:_pos.map<DropdownMenuItem<int>>((p)=>DropdownMenuItem(value:(p['position_id'] as num).toInt(),child:Text(p['position_title']))).toList(),
            onChanged:(v)=>setS(()=>posId=v)),
          const SizedBox(height:10),
          TextField(controller:hd,style:const TextStyle(color:Colors.white),decoration:darkInput('Hire Date (YYYY-MM-DD)')),
          if(emp!=null)...[const SizedBox(height:10),DropdownButtonFormField<String>(initialValue:status,dropdownColor:kCardBg,style:const TextStyle(color:Colors.white,fontSize:13),decoration:darkInput('Status'),items:['Active','Inactive'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(v)=>setS(()=>status=v!))],
          const SizedBox(height:20),
          PrimaryButton(label:emp!=null?'Update':'Add Employee',loading:saving,onPressed:()async{
            setS(()=>saving=true);
            final data={'first_name':fn.text,'last_name':ln.text,'email':em.text,'phone':ph.text,'department_id':deptId,'position_id':posId,'hire_date':hd.text,'status':status,'version':emp?['version']??0};
            final res=emp!=null?await ApiService.updateEmployee((emp['employee_id'] as num).toInt(),data):await ApiService.addEmployee(data);
            if(ctx.mounted){
              Navigator.pop(ctx);
              _snack(res['message']??'',res['success']==true);
              if(res['success']==true){
                if(emp==null && res['account']!=null) {
                  showDialog(context:this.context,builder:(_)=>AlertDialog(backgroundColor:kCardBg,title:const Text('Account Created',style:TextStyle(color:Colors.white)),
                    content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
                      const Text('Employee added with auto-generated account:',style:TextStyle(color:kTextMuted,fontSize:12)),
                      const SizedBox(height:8),
                      Text('Username: ${res['account']['username']}',style:const TextStyle(color:Colors.white,fontSize:13)),
                      Text('Password: ${res['account']['password']}',style:const TextStyle(color:kAccent,fontSize:13)),
                    ]),
                    actions:[TextButton(onPressed:()=>Navigator.pop(this.context),child:const Text('OK'))],
                  ));
                }
                _load();
              }
            }
          }),
        ])))));
  }

  void _showPhoneEdit(Map emp) {
    final ph=TextEditingController(text:emp['phone']??''); bool saving=false;
    showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:kCardBg,
      shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(16))),
      builder:(ctx)=>StatefulBuilder(builder:(ctx,setS)=>Padding(
        padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(ctx).viewInsets.bottom+20),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('Edit My Profile',style:TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:Colors.white)),
          const SizedBox(height:8),
          Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:kAccent.withValues(alpha: 0.1),borderRadius:BorderRadius.circular(8),border:Border.all(color:kAccent.withValues(alpha: 0.3))),
            child:const Text('You can only update your phone number. Use Requests for name or email changes.',style:TextStyle(color:kAccent,fontSize:11))),
          const SizedBox(height:14),
          TextField(controller:ph,style:const TextStyle(color:Colors.white),decoration:darkInput('Phone Number'),keyboardType:TextInputType.phone),
          const SizedBox(height:16),
          PrimaryButton(label:'Update Phone',loading:saving,onPressed:()async{
            setS(()=>saving=true);
            final res=await ApiService.updateMyPhone(ph.text,emp['version']??0);
            if(ctx.mounted){Navigator.pop(ctx);_snack(res['message']??'',res['success']==true);if(res['success']==true)_load();}
          }),
        ]))));
  }

  Future<void> _delete(Map emp) async {
    final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(backgroundColor:kCardBg,title:const Text('Delete Employee',style:TextStyle(color:Colors.white)),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Delete ${emp["first_name"]} ${emp["last_name"]}?',style:const TextStyle(color:kTextMuted,fontSize:13)),const SizedBox(height:8),Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:kDanger.withValues(alpha: 0.1),borderRadius:BorderRadius.circular(6),border:Border.all(color:kDanger.withValues(alpha: 0.3))),child:const Text('This will also delete their linked user account.',style:TextStyle(color:kDanger,fontSize:11)))]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),TextButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Delete',style:TextStyle(color:kDanger)))]));
    if(ok!=true)return;
    final res=await ApiService.deleteEmployee((emp['employee_id'] as num).toInt());
    _snack(res['message']??'',res['success']==true);
    if(res['success']==true)_load();
  }

  @override
  Widget build(BuildContext context) {
    final auth=context.watch<AuthService>();
    return Scaffold(backgroundColor:Colors.transparent,
      body:Column(children:[
        if(!auth.isEmployee) Padding(padding:const EdgeInsets.fromLTRB(12,12,12,0),
          child:TextField(controller:_srch,style:const TextStyle(color:Colors.white),
            decoration:darkInput('Search…',suffix:IconButton(icon:const Icon(Icons.search,color:kTextMuted),onPressed:()=>_load())),
            onSubmitted:(_)=>_load())),
        if(!auth.isEmployee) Padding(padding:const EdgeInsets.fromLTRB(12,6,12,0),
          child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
            Text('$_total employees',style:const TextStyle(color:kTextMuted,fontSize:12)),
            if(_totalPages>1) Text('Page $_page of $_totalPages',style:const TextStyle(color:kTextMuted,fontSize:12)),
          ])),
        if(_loading) const Expanded(child:LoadingIndicator())
        else if(_error!=null) Expanded(child:ErrorView(message:_error!,onRetry:_load))
        else if(_emps.isEmpty) const Expanded(child:EmptyView(message:'No employees found.'))
        else Expanded(child:RefreshIndicator(color:kAccent,onRefresh:_load,child:ListView.builder(
          padding:const EdgeInsets.all(12),
          itemCount:_emps.length+(_totalPages>1?1:0),
          itemBuilder:(_,i){
            if(i==_emps.length) return Row(mainAxisAlignment:MainAxisAlignment.center,children:[
              if(_page>1) TextButton(onPressed:()=>_load(page:_page-1),child:const Text('← Prev',style:TextStyle(color:kAccent))),
              if(_page<_totalPages) TextButton(onPressed:()=>_load(page:_page+1),child:const Text('Next →',style:TextStyle(color:kAccent))),
            ]);
            final emp=_emps[i];
            final isOwn=auth.isEmployee;
            return Container(margin:const EdgeInsets.only(bottom:8),
              decoration:BoxDecoration(color:kCardBg,borderRadius:BorderRadius.circular(10),border:Border.all(color:isOwn?kAccent.withValues(alpha: 0.4):kBorder)),
              child:ListTile(
                title:Row(children:[Expanded(child:Text('${emp['first_name']} ${emp['last_name']}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600,fontSize:13))),if(isOwn)const AppBadge(label:'You',color:kAccent)]),
                subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(emp['email']??'',style:const TextStyle(color:kTextMuted,fontSize:11)),
                  Text('${emp['department_name']} · ${emp['position_title']}',style:const TextStyle(color:kTextMuted,fontSize:11)),
                  if(isOwn) Text('📞 ${emp['phone']??'—'}',style:const TextStyle(color:kTextMuted,fontSize:11)),
                ]),
                trailing:isOwn
                  ? OutlinedButton(onPressed:()=>_showPhoneEdit(emp),child:const Text('Edit Phone',style:TextStyle(fontSize:11)),style:OutlinedButton.styleFrom(foregroundColor:kAccent,side:const BorderSide(color:kAccent),padding:const EdgeInsets.symmetric(horizontal:8,vertical:4)))
                  : Row(mainAxisSize:MainAxisSize.min,children:[
                      if(auth.canEdit) IconButton(icon:const Icon(Icons.edit_outlined,color:kTextMuted,size:18),onPressed:()=>_showForm(emp:emp)),
                      if(auth.isAdmin) IconButton(icon:const Icon(Icons.delete_outline,color:kDanger,size:18),onPressed:()=>_delete(emp)),
                    ]),
              ));
          }))),
      ]),
      floatingActionButton:!auth.isEmployee?FloatingActionButton.extended(onPressed:()=>_showForm(),backgroundColor:kAccent,icon:const Icon(Icons.person_add_rounded),label:const Text('Add Employee')):null,
    );
  }
}

// ============================================================
// lib/screens/history_screen.dart (with pagination)
// ============================================================