import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _users=[], _logs=[];
  bool _loading=true; String? _error;
  int? _currentUserId; // for self-protection on delete

  @override void initState(){super.initState();_tabs=TabController(length:2,vsync:this);_load();}
  @override void dispose(){_tabs.dispose();super.dispose();}

  Future<void> _load() async {
    setState(()=>_loading=true);
    try {
      final r1=await ApiService.getUsers();
      final r2=await ApiService.getAuditLog();
      final me=await ApiService.getMe();
      setState((){
        _users=r1['data']??[];
        _logs=r2['data']??[];
        _currentUserId=(me['data']?['user_id'] as num?)?.toInt();
        _loading=false;
      });
    } catch(e){setState((){_error=e.toString();_loading=false;});}
  }

  void _snack(String msg, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content:Text(msg), backgroundColor:ok?kSuccess:kDanger));

  void _showAddUser() {
    final unCtrl=TextEditingController(); final fnCtrl=TextEditingController(); final pwCtrl=TextEditingController();
    String role='Employee'; bool saving=false;
    showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:kCardBg,
      shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(16))),
      builder:(ctx)=>StatefulBuilder(builder:(ctx,setS)=>Padding(
        padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(ctx).viewInsets.bottom+20),
        child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Add New User',style:TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:Colors.white)),
          const SizedBox(height:14),
          TextField(controller:fnCtrl,style:const TextStyle(color:Colors.white),decoration:darkInput('Full Name')),
          const SizedBox(height:10),
          TextField(controller:unCtrl,style:const TextStyle(color:Colors.white),decoration:darkInput('Username')),
          const SizedBox(height:10),
          TextField(controller:pwCtrl,obscureText:true,style:const TextStyle(color:Colors.white),decoration:darkInput('Password (min 6 chars)')),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(value:role,dropdownColor:kCardBg,style:const TextStyle(color:Colors.white,fontSize:13),decoration:darkInput('Role'),
            items:['Employee','Manager','Admin'].map((r)=>DropdownMenuItem(value:r,child:Text(r))).toList(),
            onChanged:(v)=>setS(()=>role=v!)),
          const SizedBox(height:16),
          PrimaryButton(label:'Create User',loading:saving,onPressed:()async{
            setS(()=>saving=true);
            final res=await ApiService.addUser({'username':unCtrl.text,'full_name':fnCtrl.text,'password':pwCtrl.text,'role':role});
            if(ctx.mounted){Navigator.pop(ctx);_snack(res['message']??'',res['success']==true);if(res['success']==true)_load();}
          }),
        ]))));
  }

  // ── Edit User ────────────────────────────────────────────
  void _showEditUser(Map user) {
    final fnCtrl=TextEditingController(text:user['full_name']??'');
    String role=user['role']??'Employee';
    String status=user['status']??'Active';
    bool saving=false;
    final isSelf=(user['user_id'] as num?)?.toInt()==_currentUserId;

    showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:kCardBg,
      shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(16))),
      builder:(ctx)=>StatefulBuilder(builder:(ctx,setS)=>Padding(
        padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(ctx).viewInsets.bottom+20),
        child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Edit User — ${user['username']}',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:Colors.white)),
          const SizedBox(height:14),
          TextField(controller:fnCtrl,style:const TextStyle(color:Colors.white),decoration:darkInput('Full Name')),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(
            value:role,dropdownColor:kCardBg,
            style:const TextStyle(color:Colors.white,fontSize:13),
            decoration:darkInput('Role'),
            items:['Employee','Manager','Admin'].map((r)=>DropdownMenuItem(value:r,child:Text(r))).toList(),
            onChanged:isSelf?null:(v)=>setS(()=>role=v!), // can't change own role
          ),
          if(isSelf) Padding(
            padding:const EdgeInsets.only(top:4),
            child:Text('You cannot change your own role.',style:TextStyle(color:kDanger,fontSize:11))),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(value:status,dropdownColor:kCardBg,style:const TextStyle(color:Colors.white,fontSize:13),decoration:darkInput('Status'),
            items:['Active','Inactive'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),
            onChanged:(v)=>setS(()=>status=v!)),
          const SizedBox(height:16),
          PrimaryButton(label:'Save Changes',loading:saving,onPressed:()async{
            setS(()=>saving=true);
            final res=await ApiService.updateUser(
              (user['user_id'] as num).toInt(),
              {'full_name':fnCtrl.text,'role':role,'status':status},
            );
            if(ctx.mounted){Navigator.pop(ctx);_snack(res['message']??'',res['success']==true);if(res['success']==true)_load();}
          }),
        ]))));
  }

  void _showResetPw(Map user) {
    final pwCtrl=TextEditingController(); bool saving=false;
    showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:kCardBg,
      shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(16))),
      builder:(ctx)=>StatefulBuilder(builder:(ctx,setS)=>Padding(
        padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(ctx).viewInsets.bottom+20),
        child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Reset Password — ${user['username']}',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:Colors.white)),
          const SizedBox(height:14),
          TextField(controller:pwCtrl,obscureText:true,style:const TextStyle(color:Colors.white),decoration:darkInput('New Password (min 6 chars)')),
          const SizedBox(height:16),
          PrimaryButton(label:'Reset Password',loading:saving,onPressed:()async{
            setS(()=>saving=true);
            final res=await ApiService.resetPassword((user['user_id'] as num).toInt(),pwCtrl.text);
            if(ctx.mounted){Navigator.pop(ctx);_snack(res['message']??'',res['success']==true);}
          }),
        ]))));
  }

  // ── Delete User ──────────────────────────────────────────
  Future<void> _deleteUser(Map user) async {
    final ok=await showDialog<bool>(
      context:context,
      builder:(_)=>AlertDialog(
        backgroundColor:kCardBg,
        title:const Text('Delete User',style:TextStyle(color:Colors.white)),
        content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Delete user "${user['username']}"?',style:const TextStyle(color:kTextMuted,fontSize:13)),
          const SizedBox(height:8),
          Container(
            padding:const EdgeInsets.all(8),
            decoration:BoxDecoration(color:kDanger.withOpacity(0.1),borderRadius:BorderRadius.circular(6),border:Border.all(color:kDanger.withOpacity(0.3))),
            child:const Text('This action cannot be undone. Audit log entries will be preserved.',style:TextStyle(color:kDanger,fontSize:11)),
          ),
        ]),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),
          TextButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Delete',style:TextStyle(color:kDanger))),
        ],
      ),
    );
    if(ok!=true)return;
    final res=await ApiService.deleteUser((user['user_id'] as num).toInt());
    _snack(res['message']??'',res['success']==true);
    if(res['success']==true)_load();
  }

  @override
  Widget build(BuildContext context) {
    final actionColors={
      'Login':kSuccess,'Logout':kWarning,
      'Add Employee':kBlue,'Edit Employee':kWarning,'Delete Employee':kDanger,
      'Add User':kBlue,'Edit User':kWarning,'Delete User':kDanger,  // ← added Edit User + Delete User
      'Reset Password':kWarning,
      'Process Payroll':kPurple,'Run ETL':const Color(0xFFFD79A8),
      'Submit Request':kBlue,'Review Request':kSuccess,
      'CSV Import':kBlue,
    };
    return Column(children:[
      Container(color:kSurface,child:TabBar(controller:_tabs,labelColor:kAccent,unselectedLabelColor:kTextMuted,indicatorColor:kAccent,tabs:const[Tab(text:'Users'),Tab(text:'Audit Log')])),
      if(_loading) const Expanded(child:LoadingIndicator())
      else if(_error!=null) Expanded(child:ErrorView(message:_error!,onRetry:_load))
      else Expanded(child:TabBarView(controller:_tabs,children:[
        // ── Users tab ────────────────────────────────────
        RefreshIndicator(color:kAccent,onRefresh:_load,child:ListView.builder(
          padding:const EdgeInsets.fromLTRB(12,12,12,80),itemCount:_users.length,itemBuilder:(_,i){
            final u=_users[i];
            final isSelf=(u['user_id'] as num?)?.toInt()==_currentUserId;
            final roleColor=u['role']=='Admin'?kAccent:u['role']=='Manager'?kBlue:kSuccess;
            return Container(margin:const EdgeInsets.only(bottom:8),
              decoration:BoxDecoration(
                color:kCardBg,borderRadius:BorderRadius.circular(10),
                border:Border.all(color:isSelf?kAccent.withOpacity(0.4):kBorder)),
              child:ListTile(
                title:Row(children:[
                  Expanded(child:Text(u['username']??'',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600,fontSize:13))),
                  if(isSelf) const AppBadge(label:'You',color:kAccent),
                ]),
                subtitle:Text(u['full_name']??'',style:const TextStyle(color:kTextMuted,fontSize:11)),
                trailing:Row(mainAxisSize:MainAxisSize.min,children:[
                  AppBadge(label:u['role']??'',color:roleColor),
                  const SizedBox(width:4),
                  StatusBadge(status:u['status']??'Active'),
                  const SizedBox(width:2),
                  // Edit button
                  IconButton(
                    icon:const Icon(Icons.edit_outlined,color:kTextMuted,size:18),
                    onPressed:()=>_showEditUser(u),
                    tooltip:'Edit user',
                  ),
                  // Reset password button
                  IconButton(
                    icon:const Icon(Icons.key_rounded,color:kWarning,size:18),
                    onPressed:()=>_showResetPw(u),
                    tooltip:'Reset password',
                  ),
                  // Delete button — disabled for own account
                  IconButton(
                    icon:Icon(Icons.delete_outline,
                      color:isSelf?kTextMuted.withOpacity(0.3):kDanger,size:18),
                    onPressed:isSelf?null:()=>_deleteUser(u),
                    tooltip:isSelf?'Cannot delete your own account':'Delete user',
                  ),
                ]),
              ));
          })),
        // ── Audit Log tab ─────────────────────────────────
        RefreshIndicator(color:kAccent,onRefresh:_load,child:_logs.isEmpty
          ?const EmptyView(message:'No audit entries yet.')
          :ListView.builder(
            padding:const EdgeInsets.all(12),itemCount:_logs.length,itemBuilder:(_,i){
              final l=_logs[i];
              final color=actionColors[l['action']] ?? kTextMuted;
              return Container(margin:const EdgeInsets.only(bottom:6),
                decoration:BoxDecoration(color:kCardBg,borderRadius:BorderRadius.circular(8),border:Border.all(color:kBorder)),
                child:ListTile(dense:true,
                  leading:AppBadge(label:l['action']??'',color:color),
                  title:Text(l['username']??'',style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w600)),
                  subtitle:Text(l['detail']??'',style:const TextStyle(color:kTextMuted,fontSize:10),overflow:TextOverflow.ellipsis),
                  trailing:Text(
                    (l['logged_at']?.toString().length ?? 0)>=16?l['logged_at'].toString().substring(5,16):'',
                    style:const TextStyle(color:kTextMuted,fontSize:10))));
            })),
      ])),
      Padding(padding:const EdgeInsets.all(12),child:PrimaryButton(label:'+ Add User',icon:Icons.person_add_rounded,onPressed:_showAddUser)),
    ]);
  }
}