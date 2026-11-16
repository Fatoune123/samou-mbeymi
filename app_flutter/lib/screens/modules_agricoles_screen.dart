import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ModulesAgricolesScreen extends StatefulWidget {
  const ModulesAgricolesScreen({super.key});

  @override
  State<ModulesAgricolesScreen> createState() => _ModulesAgricolesScreenState();
}

class _ModulesAgricolesScreenState extends State<ModulesAgricolesScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabs;
  bool _loading = true;
  String? _loadError;
  List<Recolte> _recoltes = [];
  Map<String, dynamic>? _engrais;
  Map<int, Map<String, dynamic>> _conseils = {};
  Map<int, Map<String, dynamic>> _risques = {};
  bool _questionLoading = false;
  String? _answer;
  final _questionController = TextEditingController();
  List<Map<String, String>> _fournisseurs = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _charger();
    _chargerFournisseursLocaux();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final recoltesData = await _api.recoltes();
      final engraisData = await _api.catalogueEngrais();
      if (!mounted) return;
      setState(() {
        _recoltes = recoltesData
            .map((e) => Recolte.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _engrais = engraisData;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chargerFournisseursLocaux() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('samou_fournisseurs_locaux_v1');
    if (raw == null || !mounted) return;
    try {
      final decoded = jsonDecode(raw) as List;
      setState(() => _fournisseurs = decoded
          .map((e) => Map<String, String>.from(e as Map))
          .toList());
    } catch (_) {
      // Ignore une ancienne valeur locale invalide sans toucher aux données serveur.
    }
  }

  Future<void> _sauverFournisseursLocaux() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('samou_fournisseurs_locaux_v1', jsonEncode(_fournisseurs));
  }

  Future<void> _chargerConseils(Recolte recolte) async {
    try {
      final conseil = await _api.conseilsConservation(recolte.cultureNom);
      if (mounted) setState(() => _conseils[recolte.id] = conseil);
    } catch (e) {
      _message('Impossible de charger les conseils : $e');
    }
  }

  Future<void> _analyserRisque(Recolte recolte) async {
    try {
      final result = await _api.predireRisque(
        culture: recolte.cultureNom,
        quantiteKg: recolte.quantiteKg,
        dateRecolte: recolte.dateRecolte,
        lieuStockage: recolte.lieuStockage,
      );
      if (mounted) setState(() => _risques[recolte.id] = result);
    } catch (e) {
      _message('Analyse de risque indisponible : $e');
    }
  }

  Future<void> _poserQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      _message('Écris d’abord ta question agricole.');
      return;
    }
    setState(() {
      _questionLoading = true;
      _answer = null;
    });
    try {
      final result = await _api.conseillerAgricole(
        question: 'Question phytosanitaire pour un producteur de Sangalkam au Sénégal : $question. '
            'Indique les limites du diagnostic à distance et ne prescris pas de pesticide sans identification fiable.',
        langue: 'fr-FR',
      );
      if (mounted) setState(() => _answer = (result['answer'] ?? result['detail'] ?? 'Aucune réponse.').toString());
    } catch (e) {
      if (mounted) setState(() => _answer = 'Conseiller indisponible : $e\n\nConsulte un technicien agricole pour confirmer le diagnostic.');
    } finally {
      if (mounted) setState(() => _questionLoading = false);
    }
  }

  Future<void> _signalerPertePhytosanitaire() async {
    if (_recoltes.isEmpty) {
      _message('Ajoute d’abord une récolte pour pouvoir signaler une perte.');
      return;
    }
    Recolte selected = _recoltes.first;
    String type = 'maladie';
    final quantity = TextEditingController(text: '1');
    final description = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Signaler une perte phytosanitaire'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Ce formulaire enregistre une perte réelle en kg, pas seulement un symptôme observé.'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Recolte>(
                    value: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Récolte concernée'),
                    items: _recoltes.map((r) => DropdownMenuItem(value: r, child: Text('${r.cultureNom} · ${r.quantiteKg} kg'))).toList(),
                    onChanged: (v) { if (v != null) setDialogState(() => selected = v); },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type de problème'),
                    items: const [
                      DropdownMenuItem(value: 'maladie', child: Text('Maladie de la plante')),
                      DropdownMenuItem(value: 'insectes', child: Text('Insectes / ravageurs')),
                      DropdownMenuItem(value: 'moisissure', child: Text('Moisissure / pourriture')),
                    ],
                    onChanged: (v) { if (v != null) setDialogState(() => type = v); },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: quantity,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantité réellement perdue (kg)'),
                    validator: (v) { final n = double.tryParse((v ?? '').replaceAll(',', '.')); if (n == null || n <= 0) return 'Saisis une quantité supérieure à zéro.'; if (n > selected.quantiteKg) return 'La quantité dépasse la récolte.'; return null; },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Symptômes observés / notes')),
                ]),
              ),
            ),
          ),
        actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
            FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true); }, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      quantity.dispose();
      description.dispose();
      return;
    }
    try {
      await _api.signalerPerte(
        recolteId: selected.id,
        typePerte: type,
        quantitePerdueKg: double.parse(quantity.text.replaceAll(',', '.')),
        description: description.text.trim(),
      );
      _message('Perte enregistrée dans SAMOU MBEY.');
      await _charger();
    } catch (e) {
      _message('Échec du signalement : $e');
    } finally {
      quantity.dispose();
      description.dispose();
    }
  }

  Future<void> _ajouterFournisseur() async {
    final name = TextEditingController();
    final zone = TextEditingController(text: 'Sangalkam');
    final phone = TextEditingController();
    final products = TextEditingController(text: 'Engrais');
    final price = TextEditingController();
    final key = GlobalKey<FormState>();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajouter un point de vente'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nom du fournisseur'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: zone,
                    decoration: const InputDecoration(labelText: 'Localité'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone / contact'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: products,
                    decoration: const InputDecoration(labelText: 'Produits proposés'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: price,
                    decoration: const InputDecoration(labelText: 'Prix / disponibilité (facultatif)'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enregistré uniquement sur cet appareil. Vérifie le contact, les prix et le stock auprès du vendeur.',
                    style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(dialogContext, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (save == true) {
      setState(() => _fournisseurs.insert(0, {'nom': name.text.trim(), 'zone': zone.text.trim(), 'telephone': phone.text.trim(), 'produits': products.text.trim(), 'prix': price.text.trim()}));
      await _sauverFournisseursLocaux();
      _message('Fournisseur enregistré localement.');
    }
    name.dispose(); zone.dispose(); phone.dispose(); products.dispose(); price.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modules agricoles'),
        bottom: TabBar(controller: _tabs, isScrollable: true, tabs: const [
          Tab(icon: Icon(Icons.warehouse_outlined), text: 'Conservation'),
          Tab(icon: Icon(Icons.health_and_safety_outlined), text: 'Phytosanitaire'),
          Tab(icon: Icon(Icons.grass_outlined), text: 'Engrais'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_loadError!), const SizedBox(height: 12), FilledButton(onPressed: _charger, child: const Text('Réessayer'))])))
              : TabBarView(controller: _tabs, children: [_conservationTab(), _phytosanitaireTab(), _engraisTab()]),
    );
  }

  Widget _conservationTab() => RefreshIndicator(
    onRefresh: _charger,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      _intro(Icons.shield_moon_outlined, 'Conserver les récoltes', 'Conseils pratiques et analyse indicative du risque pour les récoltes déjà enregistrées.'),
      if (_recoltes.isEmpty) const _EmptyState(text: 'Aucune récolte enregistrée. Ajoute une récolte avant de lancer les conseils personnalisés.'),
      ..._recoltes.map((r) {
        final conseil = _conseils[r.id];
        final risque = _risques[r.id];
        return Card(margin: const EdgeInsets.only(top: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.cultureNom, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 4),
          Text('${r.quantiteKg} kg · récolte du ${r.dateRecolte}'),
          Text('Stockage : ${r.lieuStockage.isEmpty ? 'non renseigné' : r.lieuStockage}', style: const TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => _chargerConseils(r), icon: const Icon(Icons.tips_and_updates_outlined), label: const Text('Conseils de stockage')),
            FilledButton.tonalIcon(onPressed: () => _analyserRisque(r), icon: const Icon(Icons.analytics_outlined), label: const Text('Analyser le risque')),
          ]),
          if (conseil != null) ...[
            const Divider(height: 24),
            ...((conseil['conseils'] as List? ?? []).map((e) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success), const SizedBox(width: 8), Expanded(child: Text(e.toString()))])))),
            if ((conseil['alerte'] ?? '').toString().isNotEmpty) Text('À surveiller : ${conseil['alerte']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text((conseil['note_duree'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ],
          if (risque != null) ...[
            const Divider(height: 24),
            const Text('Résultat du modèle de risque', style: TextStyle(fontWeight: FontWeight.w900)),
            Text(risque.entries.where((e) => e.key != 'variables').map((e) => '${e.key.replaceAll('_', ' ')} : ${e.value}').join('\n')),
            const Text('Estimation indicative : vérifier les conditions réelles et inspecter régulièrement le lot.', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ],
        ])));
      }),
      const SizedBox(height: 12),
      const _Note(text: 'SAMOU MBEY ne donne pas de durée chiffrée de conservation sans données fiables sur la variété, la maturité et les conditions de stockage.'),
    ]),
  );

  Widget _phytosanitaireTab() => ListView(padding: const EdgeInsets.all(16), children: [
    _intro(Icons.health_and_safety_outlined, 'Prévention phytosanitaire', 'Observe les symptômes, documente-les et demande une confirmation technique avant tout traitement.'),
    const _BulletCard(title: 'Surveillance de la parcelle', items: ['Inspecter régulièrement les feuilles, tiges et fruits.', 'Photographier les symptômes et noter la date et la parcelle.', 'Nettoyer les outils et limiter le déplacement de résidus suspects.', 'Faire confirmer le diagnostic par un technicien agricole.']),
    const SizedBox(height: 12),
    const _BulletCard(title: 'Sécurité des traitements', items: ['Utiliser uniquement des produits homologués pour le problème identifié.', 'Respecter l’étiquette, les protections et le délai avant récolte.', 'Ne pas mélanger des produits sans instruction officielle.']),
    const SizedBox(height: 16),
    const Text('Poser une question au conseiller agricole', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
    const SizedBox(height: 8),
    TextField(controller: _questionController, minLines: 2, maxLines: 4, decoration: const InputDecoration(hintText: 'Ex. : les feuilles de mes tomates ont des taches brunes…')),
    const SizedBox(height: 10),
    FilledButton.icon(onPressed: _questionLoading ? null : _poserQuestion, icon: _questionLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.support_agent), label: Text(_questionLoading ? 'Analyse en cours…' : 'Demander un conseil')),
    if (_answer != null) Card(margin: const EdgeInsets.only(top: 12), child: Padding(padding: const EdgeInsets.all(16), child: SelectableText(_answer!))),
    const SizedBox(height: 12),
    OutlinedButton.icon(onPressed: _signalerPertePhytosanitaire, icon: const Icon(Icons.report_gmailerrorred_outlined), label: const Text('Enregistrer une perte liée à une maladie / ravageur')),
    const SizedBox(height: 8),
    const _Note(text: 'Une photo seule ne confirme pas toujours une maladie. Le conseiller IA ne remplace pas un diagnostic de terrain et ne prescrit pas de pesticide.'),
  ]);

  Widget _engraisTab() {
    final families = (_engrais?['familles'] as List? ?? []);
    return ListView(padding: const EdgeInsets.all(16), children: [
      _intro(Icons.grass_outlined, 'Engrais et fournisseurs', 'Garde les coordonnées des points de vente rencontrés à Sangalkam et confirme les stocks avant déplacement.'),
      ...families.map((item) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: const CircleAvatar(backgroundColor: AppColors.successSoft, child: Icon(Icons.eco_outlined, color: AppColors.primary)), title: Text('${item['nom']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${item['usage']}')))),
      const SizedBox(height: 8),
      const Text('Mon répertoire de fournisseurs', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      const SizedBox(height: 8),
      const _Note(text: 'Les fournisseurs ne sont pas préremplis avec des coordonnées non vérifiées. Les contacts ajoutés ci-dessous restent sur cet appareil et ne sont pas envoyés à la base de données.'),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _ajouterFournisseur, icon: const Icon(Icons.add_business_outlined), label: const Text('Ajouter un fournisseur rencontré')),
      const SizedBox(height: 12),
      if (_fournisseurs.isEmpty) const _EmptyState(text: 'Aucun fournisseur enregistré sur cet appareil.'),
      ..._fournisseurs.asMap().entries.map((entry) {
        final i = entry.key; final f = entry.value;
        return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
          title: Text(f['nom'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('${f['zone'] ?? ''}\n${f['telephone'] ?? 'Contact non renseigné'} · ${f['produits'] ?? 'Engrais'}${(f['prix'] ?? '').isEmpty ? '' : '\n${f['prix']}'}'),
          isThreeLine: true,
          trailing: IconButton(tooltip: 'Supprimer de cet appareil', icon: const Icon(Icons.delete_outline), onPressed: () async { setState(() => _fournisseurs.removeAt(i)); await _sauverFournisseursLocaux(); }),
        ));
      }),
      if ((_engrais?['avertissement'] ?? '').toString().isNotEmpty) ...[
        const SizedBox(height: 8),
        _Note(text: _engrais!['avertissement'].toString()),
      ],
    ]);
  }

  Widget _intro(IconData icon, String title, String text) => Container(
    padding: const EdgeInsets.all(18), margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(20)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppColors.primary, size: 30), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)), const SizedBox(height: 5), Text(text, style: const TextStyle(color: AppColors.ink))])),
    ]),
  );
}

class _BulletCard extends StatelessWidget {
  final String title;
  final List<String> items;
  const _BulletCard({required this.title, required this.items});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 10),
    ...items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success), const SizedBox(width: 8), Expanded(child: Text(item))]))),
  ])));
}

class _Note extends StatelessWidget {
  final String text;
  const _Note({required this.text});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(14)), child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.ink)));
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft))));
}
