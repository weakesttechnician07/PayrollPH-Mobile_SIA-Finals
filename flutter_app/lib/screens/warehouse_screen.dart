import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});
  @override State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _facts=[], _mart=[], _quarterly=[];
  Map _counts={};
  bool _loading=true, _etlLoading=false;
  String? _error, _etlMsg; bool _etlOk=true;

  @override void initState(){super.initState();_tabs=TabController(length:3,vsync:this);_load();}
  @override void dispose(){_tabs.dispose();super.dispose();}

  Future<void> _load() async {
    setState(()=>_loading=true);
    try {
      final r1=await ApiService.getWarehouseFacts();
      final r2=await ApiService.getWarehouseMart();
      final r3=await ApiService.getWarehouseQuarterly();
      setState((){_facts=r1['data']??[];_counts=r1['counts']??{};_mart=r2['data']??[];_quarterly=r3['data']??[];_loading=false;});
    } catch(e){setState((){_error=e.toString();_loading=false;});}
  }

  Future<void> _runEtl() async {
    setState(()=>_etlLoading=true);
    try {
      final res=await ApiService.runEtl();
      setState((){_etlMsg=res['message'];_etlOk=res['success']==true;});
      if(res['success']==true)_load();
    } catch(e){setState((){_etlMsg=e.toString();_etlOk=false;});}
    finally{setState(()=>_etlLoading=false);}
  }

  @override
  Widget build(BuildContext context) {
    final auth=context.watch<AuthService>();
    if(!auth.isAdmin) return const Center(child:Padding(padding:EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.lock_rounded,color:kDanger,size:48),SizedBox(height:12),Text('Admin access required',style:TextStyle(color:kDanger))])));

    return Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:Column(children:[
        if(_etlMsg!=null) Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(10),
          decoration:BoxDecoration(color:(_etlOk?kSuccess:kDanger).withValues(alpha: 0.1),borderRadius:BorderRadius.circular(8),border:Border.all(color:(_etlOk?kSuccess:kDanger).withValues(alpha: 0.3))),
          child:Text(_etlMsg!,style:TextStyle(color:_etlOk?kSuccess:kDanger,fontSize:12))),
        PrimaryButton(label:'Run ETL (sp_run_etl)',icon:Icons.refresh_rounded,onPressed:_runEtl,loading:_etlLoading),
        const SizedBox(height:10),
        Row(children:[
          _dimCard('📊','fact_payroll','FACT','${_counts['fact_count']??0}',true),const SizedBox(width:6),
          _dimCard('📅','dim_date','DIM','${_counts['dim_date']??0}',false),const SizedBox(width:6),
          _dimCard('👤','dim_emp','DIM','${_counts['dim_emp']??0}',false),const SizedBox(width:6),
          _dimCard('🏢','dim_dept','DIM','${_counts['dim_dept']??0}',false),
        ]),
      ])),
      Container(color:kSurface,child:TabBar(controller:_tabs,labelColor:kAccent,unselectedLabelColor:kTextMuted,indicatorColor:kAccent,
        tabs:const[Tab(text:'Fact Table'),Tab(text:'Data Mart'),Tab(text:'Quarterly')])),
      if(_loading) const Expanded(child:LoadingIndicator())
      else if(_error!=null) Expanded(child:ErrorView(message:_error!,onRetry:_load))
      else Expanded(child:TabBarView(controller:_tabs,children:[
        RefreshIndicator(color:kAccent,onRefresh:_load,child:_facts.isEmpty?const EmptyView(message:'No data. Run ETL first.'):ListView.builder(
          padding:const EdgeInsets.all(12),itemCount:_facts.length,itemBuilder:(_,i){
            final f=_facts[i];
            return Container(margin:const EdgeInsets.only(bottom:8),decoration:BoxDecoration(color:kCardBg,borderRadius:BorderRadius.circular(10),border:Border.all(color:kBorder)),
              child:ListTile(dense:true,title:Text(f['full_name']??'',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600,fontSize:13)),
                subtitle:Text('${f['department']} · ${f['month_name']} ${f['year']} · Q${f['quarter']}',style:const TextStyle(color:kTextMuted,fontSize:11)),
                trailing:Text(auth.formatMoney(f['net_pay']),style:const TextStyle(color:kSuccess,fontWeight:FontWeight.w600))));
          })),
        RefreshIndicator(color:kAccent,onRefresh:_load,child:_mart.isEmpty?const EmptyView(message:'No mart data.'):ListView.builder(
          padding:const EdgeInsets.all(12),itemCount:_mart.length,itemBuilder:(_,i){
            final m=_mart[i];
            return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:kCardBg,borderRadius:BorderRadius.circular(10),border:Border.all(color:kBorder)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(m['department_name']??'',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600)),Text('${m['payroll_month']}/${m['payroll_year']}',style:const TextStyle(color:kTextMuted,fontSize:11))]),
                const SizedBox(height:6),
                Row(children:[_sc('Headcount','${m['employee_count']}'),_sc('Total Net',auth.formatMoney(m['total_net'])),_sc('Avg Net',auth.formatMoney(m['avg_net']))]),
              ]));
          })),
        RefreshIndicator(color:kAccent,onRefresh:_load,child:_quarterly.isEmpty?const EmptyView(message:'No quarterly data.'):ListView.builder(
          padding:const EdgeInsets.all(12),itemCount:_quarterly.length,itemBuilder:(_,i){
            final q=_quarterly[i];
            return Container(margin:const EdgeInsets.only(bottom:8),decoration:BoxDecoration(color:kCardBg,borderRadius:BorderRadius.circular(10),border:Border.all(color:kBorder)),
              child:ListTile(dense:true,
                leading:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:kAccent.withValues(alpha: 0.15),borderRadius:BorderRadius.circular(8)),child:Text('Q${q['quarter']}',style:const TextStyle(color:kAccent,fontWeight:FontWeight.w800,fontSize:16))),
                title:Text('${q['year']} · Q${q['quarter']}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600)),
                subtitle:Text('${q['record_count']} records · Avg: ${auth.formatMoney(q['avg_net'])}',style:const TextStyle(color:kTextMuted,fontSize:11)),
                trailing:Text(auth.formatMoney(q['total_net']),style:const TextStyle(color:kSuccess,fontWeight:FontWeight.w600,fontSize:13))));
          })),
      ])),
    ]);
  }

  Widget _dimCard(String icon,String name,String type,String rows,bool isFact)=>Expanded(child:Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:kCardBg,borderRadius:BorderRadius.circular(8),border:Border.all(color:isFact?kAccent:kBorder,width:isFact?1.5:1)),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(icon,style:const TextStyle(fontSize:14)),const SizedBox(height:2),Text(name,style:TextStyle(color:isFact?kAccent:Colors.white,fontSize:8,fontWeight:FontWeight.w700),textAlign:TextAlign.center,overflow:TextOverflow.ellipsis),Text('$rows rows',style:const TextStyle(color:kTextMuted,fontSize:7))])));
  Widget _sc(String l,String v)=>Expanded(child:Column(children:[Text(v,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600,fontSize:11)),Text(l,style:const TextStyle(color:kTextMuted,fontSize:9))]));
}

// ============================================================
// lib/screens/users_screen.dart — Admin only
// ============================================================