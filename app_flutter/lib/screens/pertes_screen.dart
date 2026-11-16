import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

const typesPerte = [
 {'code':'insectes','label':'Insectes / ravageurs'}, {'code':'moisissure','label':'Moisissure / pourriture'},
 {'code':'transport','label':'Perte pendant le transport'}, {'code':'stockage','label':'Mauvaises conditions de stockage'},
 {'code':'climat','label':'Aléas climatiques'}, {'code':'maladie','label':'Maladie de la plante'}, {'code':'autre','label':'Autre'},
];
const statuts = [{'code':'signalee','label':'Signalée'},{'code':'en_cours','label':'En cours'},{'code':'resolue','label':'Résolue'}];

class PertesScreen extends StatefulWidget { final bool embedded; const PertesScreen({super.key,this.embedded=false}); @override State<PertesScreen> createState()=>_PertesScreenState(); }
class _PertesScreenState extends State<PertesScreen>{
 final api=ApiService();List<Perte> items=[];bool loading=true;String? error;
 @override void initState(){super.initState();load();}
 Future<void> load()async{setState(()=>loading=true);try{final d=await api.pertes();items=d.map((e)=>Perte.fromJson(e)).toList();}catch(e){error=e.toString();}finally{if(mounted)setState(()=>loading=false);}}
 Future<void> deleteItem(Perte p)async{final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('Supprimer le signalement ?'),content:Text('${p.typePerteDisplay} — ${p.quantitePerdueKg.toStringAsFixed(1)} kg'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Supprimer'))]));if(ok!=true)return;try{await api.supprimerPerte(p.id);load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
 Color color(String s)=>s=='resolue'?AppColors.primary:s=='en_cours'?AppColors.accent:AppColors.loss;
 @override
 Widget build(BuildContext c) {
   return Scaffold(
     appBar: widget.embedded ? null : AppBar(
       title: const Text('Pertes signalées'),
       actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
     ),
     body: loading
       ? const Center(child: CircularProgressIndicator())
       : error != null
         ? Center(child: Text(error!))
         : items.isEmpty
           ? const Center(child: Text('Aucune perte signalée.'))
           : RefreshIndicator(
               onRefresh: load,
               child: ListView.separated(
                 padding: const EdgeInsets.all(16),
                 itemCount: items.length,
                 separatorBuilder: (_, __) => const SizedBox(height: 10),
                 itemBuilder: (context, index) {
                   final item = items[index];
                   final itemColor = color(item.statut);
                   return Card(
                     child: ListTile(
                       leading: CircleAvatar(
                         backgroundColor: itemColor.withValues(alpha: .12),
                         child: Icon(Icons.warning_amber_rounded, color: itemColor),
                       ),
                       title: Text(item.typePerteDisplay, style: const TextStyle(fontWeight: FontWeight.w900)),
                       subtitle: Text('${item.cultureNom} • ${item.quantitePerdueKg.toStringAsFixed(1)} kg\n${item.dateSignalement}'),
                       isThreeLine: true,
                       trailing: PopupMenuButton<String>(
                         onSelected: (value) async {
                           if (value == 'edit') {
                             final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => SignalerPerteScreen(existing: item)));
                             if (ok == true) load();
                           } else {
                             await deleteItem(item);
                           }
                         },
                         itemBuilder: (_) => const [
                           PopupMenuItem(value: 'edit', child: Text('Modifier')),
                           PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                         ],
                       ),
                     ),
                   );
                 },
               ),
             ),
     floatingActionButton: FloatingActionButton.extended(
       backgroundColor: AppColors.loss,
       onPressed: () async {
         final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => const SignalerPerteScreen()));
         if (ok == true) load();
       },
       icon: const Icon(Icons.add),
       label: const Text('Signaler'),
     ),
   );
 }
}

class SignalerPerteScreen extends StatefulWidget { final Recolte? recolteInitiale; final double? quantiteInitiale; final Perte? existing; const SignalerPerteScreen({super.key,this.recolteInitiale,this.quantiteInitiale,this.existing}); @override State<SignalerPerteScreen> createState()=>_SignalerPerteScreenState(); }
class _SignalerPerteScreenState extends State<SignalerPerteScreen>{
 final api=ApiService();final form=GlobalKey<FormState>();final q=TextEditingController(),desc=TextEditingController();List<Recolte> recoltes=[];Recolte? recolte;String type='insectes',statut='signalee';bool loading=false,loadingData=true;
 @override void initState(){super.initState();final p=widget.existing;if(p!=null){q.text=p.quantitePerdueKg.toString();type=p.typePerte;statut=p.statut;}else if(widget.quantiteInitiale!=null)q.text=widget.quantiteInitiale!.toStringAsFixed(1);load();}
 Future<void> load()async{try{final d=await api.recoltes();recoltes=d.map((e)=>Recolte.fromJson(e)).toList();if(widget.existing!=null){for(final r in recoltes){if(r.id==widget.existing!.recolte){recolte=r;break;}}}else if(widget.recolteInitiale!=null){for(final r in recoltes){if(r.id==widget.recolteInitiale!.id){recolte=r;break;}}}}catch(_){}finally{if(mounted)setState(()=>loadingData=false);}}
 Future<void> save()async{if(!form.currentState!.validate()||recolte==null)return;setState(()=>loading=true);try{final n=double.parse(q.text);if(widget.existing==null){await api.signalerPerte(recolteId:recolte!.id,typePerte:type,quantitePerdueKg:n,description:desc.text);}else{await api.modifierPerte(widget.existing!.id,recolteId:recolte!.id,typePerte:type,quantitePerdueKg:n,description:desc.text,statut:statut);}if(mounted)Navigator.pop(context,true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState(()=>loading=false);}}
 @override
 Widget build(BuildContext c) {
   return Scaffold(
     appBar: AppBar(title: Text(widget.existing == null ? 'Signaler une perte' : 'Modifier le signalement')),
     body: loadingData
       ? const Center(child: CircularProgressIndicator())
       : recoltes.isEmpty
         ? const Center(child: Text('Enregistrez d’abord une récolte.'))
         : SingleChildScrollView(
             padding: const EdgeInsets.all(20),
             child: Form(
               key: form,
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   DropdownButtonFormField<Recolte>(
                     initialValue: recolte,
                     decoration: const InputDecoration(labelText: 'Récolte concernée'),
                     items: recoltes.map((r) => DropdownMenuItem(value: r, child: Text('${r.cultureNom} • ${r.dateRecolte}'))).toList(),
                     onChanged: (v) => setState(() => recolte = v),
                     validator: (v) => v == null ? 'Choisissez une récolte' : null,
                   ),
                   const SizedBox(height: 14),
                   DropdownButtonFormField<String>(
                     initialValue: type,
                     decoration: const InputDecoration(labelText: 'Cause'),
                     items: typesPerte.map((t) => DropdownMenuItem(value: t['code'], child: Text(t['label']!))).toList(),
                     onChanged: (v) => setState(() => type = v!),
                   ),
                   const SizedBox(height: 14),
                   TextFormField(
                     controller: q,
                     keyboardType: const TextInputType.numberWithOptions(decimal: true),
                     decoration: const InputDecoration(labelText: 'Quantité perdue (kg)', prefixIcon: Icon(Icons.remove_circle_outline)),
                     validator: (v) {
                       final n = double.tryParse(v ?? '');
                       if (n == null || n <= 0) return 'Quantité invalide';
                       if (recolte != null && n > recolte!.quantiteKg) return 'La perte dépasse la récolte';
                       return null;
                     },
                   ),
                   if (widget.existing != null) Padding(
                     padding: const EdgeInsets.only(top: 14),
                     child: DropdownButtonFormField<String>(
                       initialValue: statut,
                       decoration: const InputDecoration(labelText: 'Statut'),
                       items: statuts.map((x) => DropdownMenuItem(value: x['code'], child: Text(x['label']!))).toList(),
                       onChanged: (v) => setState(() => statut = v!),
                     ),
                   ),
                   const SizedBox(height: 14),
                   TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
                   const SizedBox(height: 22),
                   FilledButton.icon(
                     style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
                     onPressed: loading ? null : save,
                     icon: const Icon(Icons.check_rounded),
                     label: Text(widget.existing == null ? 'Signaler la perte' : 'Enregistrer les modifications'),
                   ),
                 ],
               ),
             ),
           ),
   );
 }
}
