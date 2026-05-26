import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _records=[],_summary=[],_ranking=[];
  bool _loading=true; String? _error;
  int _page=1,_totalPages=1,_total=0; double _grandTotal=0;

  @override void initState(){super.initState();_tabs=TabController(length:3,vsync:this);_load();}
  @override void dispose(){_tabs.dispose();super.dispose();}

  Future<void> _load({int page=1}) async {
    setState(()=>_loading=true);
    try {
      final r1=await ApiService.getPayroll(page:page);
      final r2=await ApiService.getPayrollSummary();
      final r3=await ApiService.getPayrollRanking();
      setState((){
        _records=r1['data']??[];_page=page;_totalPages=r1['total_pages']??1;_total=r1['total']??0;_grandTotal=double.tryParse(r1['grand_total_net']?.toString()??'0')??0;
        _summary=r2['data']??[];_ranking=r3['data']??[];_loading=false;
      });
    } catch(e){setState((){_error=e.toString();_loading=false;});}
  }

  @override
  Widget build(BuildContext context) {
    final auth=context.watch<AuthService>();
    return Column(children:[
      Container(color:kSurface,child:TabBar(controller:_tabs,labelColor:kAccent,unselectedLabelColor:kTextMuted,indicatorColor:kAccent,
        tabs:const[Tab(text:'Records'),Tab(text:'Dept Summary'),Tab(text:'Rankings')])),
      if(_loading) const Expanded(child:LoadingIndicator())
      else if(_error!=null) Expanded(child:ErrorView(message:_error!,onRetry:_load))
      else Expanded(child:TabBarView(controller:_tabs,children:[
        // Records
        Column(children:[
          Padding(padding:const EdgeInsets.fromLTRB(12,8,12,0),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
            Text('$_total records',style:const TextStyle(color:kTextMuted,fontSize:12)),
            Text('Grand Total: ${auth.formatMoney(_grandTotal)}',style:const TextStyle(color:kSuccess,fontWeight:FontWeight.w600,fontSize:12)),
          ])),
          Expanded(child:RefreshIndicator(color:kAccent,onRefresh:_load,child:_records.isEmpty?const EmptyView(message:'No records yet.'):ListView.builder(
            padding:const EdgeInsets.all(12),itemCount:_records.length+(_totalPages>1?1:0),
            itemBuilder:(_,i){
              if(i==_records.length) return Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                if(_page>1) TextButton(onPressed:()=>_load(page:_page-1),child:const Text('← Prev',style:TextStyle(color:kAccent))),
                Text('  $_page / $_totalPages  ',style:const TextStyle(color:kTextMuted,fontSize:11)),
                if(_page<_totalPages) TextButton(onPressed:()=>_load(page:_page+1),child:const Text('Next →',style:TextStyle(color:kAccent))),
              ]);
              final r=_records[i];
              return Container(margin:const EdgeInsets.only(bottom:8),decoration:BoxDecoration(color:kCardBg,borderRadius:BorderRadius.circular(10),border:Border.all(color:kBorder)),
                child:ListTile(dense:true,
                  title:Text(r['employee_name']??'',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600,fontSize:13)),
                  subtitle:Text('${r['department_name']} · ${r['payroll_month']}/${r['payroll_year']}',style:const TextStyle(color:kTextMuted,fontSize:11)),
                  trailing:Column(crossAxisAlignment:CrossAxisAlignment.end,mainAxisAlignment:MainAxisAlignment.center,children:[
                    Text(auth.formatMoney(r['net_pay']),style:const TextStyle(color:kSuccess,fontWeight:FontWeight.w600,fontSize:13)),
                    Text('Gross: ${auth.formatMoney(r['gross_pay'])}',style:const TextStyle(color:kTextMuted,fontSize:10)),
                  ])));
            }))),
        ]),
        // Summary
        RefreshIndicator(color:kAccent,onRefresh:_load,child:_summary.isEmpty?const EmptyView(message:'No summary data.'):ListView.builder(
          padding:const EdgeInsets.all(12),itemCount:_summary.length,itemBuilder:(_,i){
            final s=_summary[i];
            return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:kCardBg,borderRadius:BorderRadius.circular(10),border:Border.all(color:kBorder)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(s['department_name']??'',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600)),Text('${s['payroll_month']}/${s['payroll_year']}',style:const TextStyle(color:kTextMuted,fontSize:11))]),
                const SizedBox(height:8),
                Row(children:[_sc('Headcount','${s['employee_count']}'),_sc('Total Net',auth.formatMoney(s['total_net'])),_sc('Avg Net',auth.formatMoney(s['avg_net']))]),
              ]));
          })),
        // Rankings
        RefreshIndicator(color:kAccent,onRefresh:_load,child:_ranking.isEmpty?const EmptyView(message:'Run payroll first.'):ListView.builder(
          padding:const EdgeInsets.all(12),itemCount:_ranking.length,itemBuilder:(_,i){
            final r=_ranking[i];
            final rk=r['pay_rank'];
            final medal=rk==1?'🥇':rk==2?'🥈':rk==3?'🥉':'#$rk';
            return Container(margin:const EdgeInsets.only(bottom:8),decoration:BoxDecoration(color:kCardBg,borderRadius:BorderRadius.circular(10),border:Border.all(color:kBorder)),
              child:ListTile(dense:true,leading:Text(medal,style:const TextStyle(fontSize:22)),
                title:Text(r['employee_name']??'',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600,fontSize:13)),
                subtitle:Text('${r['department_name']} · ${r['pct_of_total']}% of payroll',style:const TextStyle(color:kTextMuted,fontSize:11)),
                trailing:Text(auth.formatMoney(r['net_pay']),style:const TextStyle(color:kSuccess,fontWeight:FontWeight.w600,fontSize:13))));
          })),
      ])),
    ]);
  }
  Widget _sc(String l,String v)=>Expanded(child:Column(children:[Text(v,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600,fontSize:11)),Text(l,style:const TextStyle(color:kTextMuted,fontSize:9))]));
}
