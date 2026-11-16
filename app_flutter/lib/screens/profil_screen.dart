import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

const regionsSenegal=[
 {'code':'dakar','label':'Dakar'},{'code':'thies','label':'Thiès'},{'code':'diourbel','label':'Diourbel'},{'code':'fatick','label':'Fatick'},
 {'code':'kaolack','label':'Kaolack'},{'code':'kaffrine','label':'Kaffrine'},{'code':'kolda','label':'Kolda'},{'code':'louga','label':'Louga'},
 {'code':'matam','label':'Matam'},{'code':'saint_louis','label':'Saint-Louis'},{'code':'sedhiou','label':'Sédhiou'},{'code':'tambacounda','label':'Tambacounda'},
 {'code':'kedougou','label':'Kédougou'},{'code':'ziguinchor','label':'Ziguinchor'},
];

class ProfilScreen extends StatefulWidget{const ProfilScreen({super.key});@override State<ProfilScreen> createState()=>_ProfilScreenState();}
class _ProfilScreenState extends State<ProfilScreen>{final api=ApiService();ProfilAgriculteur? profil;bool loading=true;String? error;@override void initState(){super.initState();load();}Future<void>load()async{setState(()=>loading=true);try{profil=ProfilAgriculteur.fromJson(await api.profil());error=null;}catch(e){error=e.toString();}finally{if(mounted)setState(()=>loading=false);}}
 Future<void>edit()async{if(profil==null)return;final ok=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>EditProfilScreen(profil:profil!)));if(ok==true)load();}
 @override Widget build(BuildContext c){if(loading)return const Center(child:CircularProgressIndicator(color:AppColors.primary));if(error!=null)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.person_off_outlined,size:44,color:AppColors.loss),const SizedBox(height:12),Text(error!,textAlign:TextAlign.center),const SizedBox(height:12),FilledButton(onPressed:load,child:const Text('Réessayer'))])));final p=profil!;final initial=(p.nomComplet.isNotEmpty?p.nomComplet:p.username)[0].toUpperCase();return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(18,18,18,30),children:[Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppColors.primary,AppColors.primaryLight]),borderRadius:BorderRadius.circular(24)),child:Row(children:[CircleAvatar(radius:34,backgroundColor:Colors.white.withValues(alpha:.14),child:Text(initial,style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900))),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.nomComplet.isEmpty?p.username:p.nomComplet,style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(p.nomExploitation.isEmpty?'Agriculteur':p.nomExploitation,style:const TextStyle(color:Color(0xFFD2E4DC))),Text(p.region,style:const TextStyle(color:Color(0xFFB8D0C6),fontSize:12))])),IconButton(onPressed:edit,icon:const Icon(Icons.edit_outlined,color:Colors.white))])),const SizedBox(height:16),_Section(title:'Informations personnelles',children:[_Info(icon:Icons.alternate_email_rounded,label:'Identifiant',value:p.username),_Info(icon:Icons.email_outlined,label:'E-mail',value:p.email.isEmpty?'Non renseigné':p.email),_Info(icon:Icons.phone_outlined,label:'Téléphone',value:p.telephone.isEmpty?'Non renseigné':p.telephone),_Info(icon:Icons.location_on_outlined,label:'Région',value:p.region)]),const SizedBox(height:14),_Section(title:'Exploitation',children:[_Info(icon:Icons.agriculture_rounded,label:'Nom de l’exploitation',value:p.nomExploitation.isEmpty?'Non renseigné':p.nomExploitation),const SizedBox(height:8),const Text('Ces informations servent à contextualiser les analyses de risque et les recommandations.',style:TextStyle(fontSize:12,color:AppColors.inkSoft,height:1.45))]),const SizedBox(height:14),Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Évolution future : intelligence artificielle',style:TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:6),const Text('L’intelligence artificielle est une perspective d’évolution de SAMOU MBEYMI. Dans cette version, l’application se concentre sur la gestion des récoltes, le suivi des pertes, les tableaux de bord et les rapports. Une future version pourra exploiter les historiques agricoles pour aider à identifier les périodes et les lots présentant davantage de risques. Aucune prédiction IA n’est présentée ici comme un résultat opérationnel.',style:TextStyle(color:AppColors.inkSoft,fontSize:12,height:1.45))])))]));}}

class EditProfilScreen extends StatefulWidget{final ProfilAgriculteur profil;const EditProfilScreen({super.key,required this.profil});@override State<EditProfilScreen> createState()=>_EditProfilScreenState();}
class _EditProfilScreenState extends State<EditProfilScreen>{final api=ApiService();final form=GlobalKey<FormState>();late TextEditingController first,last,email,tel,exploitation;String region='thies';bool saving=false;
 @override void initState(){super.initState();final p=widget.profil;final parts=p.nomComplet.split(' ');first=TextEditingController(text:parts.isNotEmpty?parts.first:'');last=TextEditingController(text:parts.length>1?parts.sublist(1).join(' '):'');email=TextEditingController(text:p.email);tel=TextEditingController(text:p.telephone);exploitation=TextEditingController(text:p.nomExploitation);region=regionsSenegal.firstWhere((r)=>r['label']==p.region,orElse:()=>regionsSenegal[1])['code']!;}
 Future<void>save()async{if(!form.currentState!.validate())return;setState(()=>saving=true);try{await api.modifierProfil(firstName:first.text,lastName:last.text,email:email.text.trim(),telephone:tel.text,region:region,nomExploitation:exploitation.text);if(mounted)Navigator.pop(context,true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState(()=>saving=false);}}
 @override
 Widget build(BuildContext c) {
   return Scaffold(
     appBar: AppBar(title: const Text('Modifier mon profil')),
     body: SingleChildScrollView(
       padding: const EdgeInsets.all(20),
       child: Form(
         key: form,
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
             TextFormField(controller: first, decoration: const InputDecoration(labelText: 'Prénom'), validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null),
             const SizedBox(height: 12),
             TextFormField(controller: last, decoration: const InputDecoration(labelText: 'Nom'), validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null),
             const SizedBox(height: 12),
             TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Adresse e-mail', prefixIcon: Icon(Icons.email_outlined)), validator: (v) { final value = (v ?? '').trim(); if (value.isEmpty) return null; if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'Adresse e-mail invalide'; return null; }),
             const SizedBox(height: 12),
             TextFormField(controller: tel, decoration: const InputDecoration(labelText: 'Téléphone')),
             const SizedBox(height: 12),
             DropdownButtonFormField<String>(
               initialValue: region,
               decoration: const InputDecoration(labelText: 'Région'),
               items: regionsSenegal.map((r) => DropdownMenuItem(value: r['code'], child: Text(r['label']!))).toList(),
               onChanged: (v) => setState(() => region = v!),
             ),
             const SizedBox(height: 12),
             TextFormField(controller: exploitation, decoration: const InputDecoration(labelText: 'Nom de l’exploitation')),
             const SizedBox(height: 24),
             FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save_outlined), label: Text(saving ? 'Enregistrement…' : 'Enregistrer')),
           ],
         ),
       ),
     ),
   );
 }
}
class _Section extends StatelessWidget{final String title;final List<Widget> children;const _Section({required this.title,required this.children});@override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900)),const SizedBox(height:10),...children])));}
class _Info extends StatelessWidget{final IconData icon;final String label,value;const _Info({required this.icon,required this.label,required this.value});@override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[Container(width:36,height:36,decoration:BoxDecoration(color:AppColors.successSoft,borderRadius:BorderRadius.circular(10)),child:Icon(icon,size:18,color:AppColors.primary)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:10,color:AppColors.inkSoft)),const SizedBox(height:2),Text(value,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13))]))]));}
