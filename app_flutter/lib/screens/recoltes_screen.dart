import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class RecoltesScreen extends StatefulWidget {
  final bool embedded;
  const RecoltesScreen({super.key, this.embedded = false});
  @override State<RecoltesScreen> createState() => _RecoltesScreenState();
}

class _RecoltesScreenState extends State<RecoltesScreen> {
  final api = ApiService(); List<Recolte> items=[]; bool loading=true; String? error;
  @override void initState(){super.initState(); load();}
  Future<void> load() async { setState(()=>loading=true); try{final d=await api.recoltes(); items=d.map((e)=>Recolte.fromJson(e)).toList();}catch(e){error=e.toString();}finally{if(mounted)setState(()=>loading=false);} }
  Future<void> supprimer(Recolte r) async {
    final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('Supprimer la récolte ?'),content:Text('${r.cultureNom} — ${r.quantiteKg.toStringAsFixed(1)} kg sera supprimée.'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Supprimer'))]));
    if(ok!=true)return; try{await api.supprimerRecolte(r.id);await load(); if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Récolte supprimée.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
  }
  @override Widget build(BuildContext context){
    return Scaffold(appBar:widget.embedded?null:AppBar(title:const Text('Mes récoltes'),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Text(error!)):items.isEmpty?const _EmptyHarvest():RefreshIndicator(onRefresh:load,child:ListView.separated(padding:const EdgeInsets.all(16),itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(height:10),itemBuilder:(c,i){final r=items[i];final risk=r.pourcentagePerte>12?AppColors.loss:r.pourcentagePerte>5?AppColors.accent:AppColors.primary;return Card(clipBehavior:Clip.antiAlias,child:Padding(padding:const EdgeInsets.all(10),child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[ClipRRect(borderRadius:BorderRadius.circular(13),child:SizedBox(width:76,height:76,child:_photoCulture(r.cultureNom).isNotEmpty ? Image.asset(_photoCulture(r.cultureNom),fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:AppColors.successSoft,child:const Icon(Icons.eco_rounded,color:AppColors.primary,size:30))) : Container(color:AppColors.successSoft,alignment:Alignment.center,child:const Icon(Icons.eco_rounded,color:AppColors.primary,size:32)))),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(r.cultureNom,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:15)),const SizedBox(height:5),Text('${r.quantiteKg.toStringAsFixed(1)} kg • ${r.dateRecolte}',style:const TextStyle(color:AppColors.inkSoft,fontSize:12)),if(r.lieuStockage.isNotEmpty)Padding(padding:const EdgeInsets.only(top:3),child:Text(r.lieuStockage,style:const TextStyle(color:AppColors.inkSoft,fontSize:11))),const SizedBox(height:5),Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),decoration:BoxDecoration(color:risk.withValues(alpha:.10),borderRadius:BorderRadius.circular(20)),child:Text(r.pourcentagePerte>12?'Action recommandée':r.pourcentagePerte>5?'À surveiller':'Bonne maîtrise',style:TextStyle(color:risk,fontSize:10,fontWeight:FontWeight.w700)))])),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${r.pourcentagePerte.toStringAsFixed(1)}%',style:TextStyle(color:risk,fontWeight:FontWeight.w900)),PopupMenuButton<String>(onSelected:(v)async{if(v=='history'){await Navigator.push(context,MaterialPageRoute(builder:(_)=>HistoriqueRecolteScreen(recolte:r)));}else if(v=='edit'){final ok=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>AjouterRecolteScreen(existing:r)));if(ok==true)load();}else if(v=='delete'){await supprimer(r);}},itemBuilder:(_)=>const[PopupMenuItem(value:'history',child:Text('Historique / traçabilité')),PopupMenuItem(value:'edit',child:Text('Modifier')),PopupMenuItem(value:'delete',child:Text('Supprimer'))])])])));})));
  }
}


String _photoCulture(String nom) {
  final n = nom.toLowerCase();
  if (n.contains('oignon')) return 'assets/images/produit-oignon.jpg';
  if (n.contains('tomate')) return 'assets/images/produit-tomate.jpg';
  if (n.contains('pomme de terre') || n.contains('pomme-de-terre') || n.contains('pomme')) return 'assets/images/produit-pomme-de-terre.jpg';
  if (n.contains('carotte')) return 'assets/images/produit-carotte.jpg';
  if (n.contains('chou')) return 'assets/images/produit-chou.jpg';
  if (n.contains('poivron') || n.contains('piment')) return 'assets/images/produit-poivron.jpg';
  // Les cultures sans photo dédiée gardent un pictogramme neutre.
  return ''; 
}

class _EmptyHarvest extends StatelessWidget{const _EmptyHarvest();@override Widget build(BuildContext c)=>Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.agriculture_outlined,size:58,color:AppColors.primary.withValues(alpha:.45)),const SizedBox(height:14),const Text('Aucune récolte enregistrée',style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),const SizedBox(height:6),const Text('Commencez par enregistrer une récolte pour alimenter vos indicateurs.',textAlign:TextAlign.center,style:TextStyle(color:AppColors.inkSoft)),const SizedBox(height:18)])));}

class AjouterRecolteScreen extends StatefulWidget{
  final Recolte? existing; const AjouterRecolteScreen({super.key,this.existing});
  @override State<AjouterRecolteScreen> createState()=>_AjouterRecolteScreenState();
}
class _AjouterRecolteScreenState extends State<AjouterRecolteScreen>{
  final form=GlobalKey<FormState>(); final api=ApiService(); final q=TextEditingController(),lieu=TextEditingController(),notes=TextEditingController(); List<Culture> cultures=[]; Culture? culture; DateTime date=DateTime.now(); bool loading=false,loadingCultures=true,analysing=false; Map<String,dynamic>? prediction;
  @override void initState(){super.initState();final r=widget.existing;if(r!=null){q.text=r.quantiteKg.toString();lieu.text=r.lieuStockage;notes.text=r.notes;date=DateTime.tryParse(r.dateRecolte)??DateTime.now();}loadCultures();}
  Future<void> loadCultures()async{try{final d=await api.cultures();cultures=d.map((e)=>Culture.fromJson(e)).toList();if(widget.existing!=null) for(final x in cultures){if(x.id==widget.existing!.culture){culture=x;break;}}}catch(e){}finally{if(mounted)setState(()=>loadingCultures=false);}}
  Future<void> analyse()async{if(culture==null||q.text.isEmpty)return;setState(()=>analysing=true);try{prediction=await api.predireRisque(culture:culture!.nom,quantiteKg:double.tryParse(q.text)??0,dateRecolte:'${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}',lieuStockage:lieu.text);}catch(_){}finally{if(mounted)setState(()=>analysing=false);}}
  Future<void> save()async{if(!form.currentState!.validate()||culture==null)return;setState(()=>loading=true);try{final ds='${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';if(widget.existing==null){await api.ajouterRecolte(cultureId:culture!.id,quantiteKg:double.parse(q.text),dateRecolte:ds,lieuStockage:lieu.text,notes:notes.text);}else{await api.modifierRecolte(widget.existing!.id,cultureId:culture!.id,quantiteKg:double.parse(q.text),dateRecolte:ds,lieuStockage:lieu.text,notes:notes.text);}if(mounted)Navigator.pop(context,true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState(()=>loading=false);}}
  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Nouvelle récolte' : 'Modifier la récolte')),
      body: loadingCultures
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<Culture>(
                    initialValue: culture,
                    decoration: const InputDecoration(labelText: 'Culture'),
                    items: cultures.map((x) => DropdownMenuItem(value: x, child: Text(x.nom))).toList(),
                    onChanged: (v) => setState(() => culture = v),
                    validator: (v) => v == null ? 'Choisissez une culture' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: q,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantité récoltée (kg)', prefixIcon: Icon(Icons.scale_outlined)),
                    validator: (v) { final n = double.tryParse(v ?? ''); return n == null || n <= 0 ? 'Quantité invalide' : null; },
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Date : ${date.day}/${date.month}/${date.year}'),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(context: c, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (picked != null) setState(() => date = picked);
                    },
                  ),
                  TextFormField(controller: lieu, decoration: const InputDecoration(labelText: 'Lieu de stockage', prefixIcon: Icon(Icons.warehouse_outlined))),
                  const SizedBox(height: 14),
                  TextFormField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: analysing ? null : analyse,
                    icon: analysing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                    label: const Text('Analyser le risque avec l’IA'),
                  ),
                  if (prediction != null) Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Card(
                      color: AppColors.successSoft,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Risque prédit : ${prediction!['risque_affiche']}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
                            const SizedBox(height: 5),
                            Text(prediction!['recommandation'] ?? '', style: const TextStyle(color: AppColors.inkSoft)),
                            ...(prediction!['facteurs'] as List? ?? []).map((x) => Text('• $x', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: loading ? null : save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(widget.existing == null ? 'Enregistrer la récolte' : 'Enregistrer les modifications'),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}


class HistoriqueRecolteScreen extends StatefulWidget {
  final Recolte recolte;
  const HistoriqueRecolteScreen({super.key, required this.recolte});

  @override
  State<HistoriqueRecolteScreen> createState() => _HistoriqueRecolteScreenState();
}

class _HistoriqueRecolteScreenState extends State<HistoriqueRecolteScreen> {
  final api = ApiService();
  List<dynamic> events = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      events = await api.evenementsTraceabilite(widget.recolte.id);
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addEvent() async {
    final formKey = GlobalKey<FormState>();
    final description = TextEditingController();
    final lieu = TextEditingController(text: widget.recolte.lieuStockage);
    final quantite = TextEditingController();
    String type = 'stockage';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter un événement'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type d’événement'),
                    items: const [
                      DropdownMenuItem(value: 'stockage', child: Text('Mise en stockage')),
                      DropdownMenuItem(value: 'deplacement', child: Text('Déplacement')),
                      DropdownMenuItem(value: 'controle', child: Text('Contrôle du lot')),
                      DropdownMenuItem(value: 'mise_a_jour', child: Text('Mise à jour')),
                      DropdownMenuItem(value: 'autre', child: Text('Autre')),
                    ],
                    onChanged: (v) { if (v != null) setDialogState(() => type = v); },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Description'),
                    minLines: 2,
                    maxLines: 3,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Description obligatoire' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: lieu,
                    decoration: const InputDecoration(labelText: 'Lieu'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: quantite,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantité concernée (kg, facultatif)'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = double.tryParse(v.replaceAll(',', '.'));
                      return n == null || n <= 0 ? 'Quantité invalide' : null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    try {
      final q = quantite.text.trim().isEmpty
          ? null
          : double.parse(quantite.text.replaceAll(',', '.'));
      await api.ajouterEvenementTraceabilite(
        recolteId: widget.recolte.id,
        typeEvenement: type,
        description: description.text.trim(),
        lieu: lieu.text.trim(),
        quantiteKg: q,
      );
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Événement ajouté à l’historique.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      description.dispose();
      lieu.dispose();
      quantite.dispose();
    }
  }

  String labelType(Map<String, dynamic> event) =>
      (event['type_evenement_display'] ?? event['type_evenement'] ?? 'Événement').toString();

  @override
  Widget build(BuildContext context) {
    final r = widget.recolte;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traçabilité du lot'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addEvent,
        icon: const Icon(Icons.add),
        label: const Text('Événement'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.qr_code_2)),
              title: Text(r.cultureNom, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${r.quantiteKg.toStringAsFixed(2)} kg • Récolte du ${r.dateRecolte}'),
              trailing: Text('#${r.id}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(error!)))
                    : events.isEmpty
                        ? const Center(child: Text('Aucun événement enregistré.'))
                        : RefreshIndicator(
                            onRefresh: load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                              itemCount: events.length,
                              itemBuilder: (context, index) {
                                final e = events[index] as Map<String, dynamic>;
                                final date = DateTime.tryParse('${e['date_evenement'] ?? ''}')?.toLocal();
                                final dateLabel = date == null
                                    ? ''
                                    : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                final q = e['quantite_kg'];
                                return Card(
                                  child: ListTile(
                                    leading: const CircleAvatar(child: Icon(Icons.history)),
                                    title: Text(labelType(e), style: const TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: Text([
                                      if ((e['description'] ?? '').toString().isNotEmpty) e['description'].toString(),
                                      if ((e['lieu'] ?? '').toString().isNotEmpty) 'Lieu : ${e['lieu']}',
                                      if (q != null) 'Quantité : $q kg',
                                      if (dateLabel.isNotEmpty) dateLabel,
                                      if ((e['auteur_nom'] ?? '').toString().isNotEmpty) 'Par : ${e['auteur_nom']}',
                                    ].join('\n')),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
