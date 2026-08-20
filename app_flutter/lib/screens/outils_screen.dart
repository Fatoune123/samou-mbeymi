import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class OutilsScreen extends StatefulWidget {
  const OutilsScreen({super.key});
  @override State<OutilsScreen> createState()=>_OutilsScreenState();
}
class _OutilsScreenState extends State<OutilsScreen>{
  final api=ApiService(); bool loading=true; String? error; Map<String,dynamic>? data; List<dynamic> stockages=[];
  @override void initState(){super.initState();load();}
  Future<void> load() async{setState(()=>loading=true);try{final d=await api.tableauBord();final s=await api.stockages();if(mounted)setState(() { data=d; stockages=s; });}catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>loading=false);}}
  @override Widget build(BuildContext context){if(loading)return const Center(child:CircularProgressIndicator());if(error!=null)return Center(child:Text(error!));final d=data!;return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(18),children:[_card('📊','Rapport de pilotage','Production ${d['total_recolte_kg']} kg · pertes ${d['total_perte_kg']} kg · taux ${d['taux_perte']}%'),const SizedBox(height:12),_card('🤖','Machine Learning','Risque global : ${d['niveau_risque']}'),const SizedBox(height:20),const Text('Points de stockage',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:10),...stockages.map((s)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.warehouse_outlined)),title:Text('${s['nom']}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${s['region_display']} · ${s['capacite_kg']} kg'),trailing:const Icon(Icons.chevron_right))))]));}
  Widget _card(String icon,String title,String text)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[Container(width:46,height:46,decoration:BoxDecoration(color:AppColors.successSoft,borderRadius:BorderRadius.circular(14)),child:Center(child:Text(icon,style:const TextStyle(fontSize:22)))),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(text,style:const TextStyle(color:AppColors.inkSoft,fontSize:12))]))]));
}
