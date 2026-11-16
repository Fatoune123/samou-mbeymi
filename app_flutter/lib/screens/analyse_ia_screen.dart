import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class AnalyseIARisqueScreen extends StatefulWidget {
  const AnalyseIARisqueScreen({super.key});

  @override
  State<AnalyseIARisqueScreen> createState() => _AnalyseIARisqueScreenState();
}

class _AnalyseIARisqueScreenState extends State<AnalyseIARisqueScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _culture = TextEditingController();
  final _quantite = TextEditingController();
  final _stockage = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loadingInfo = true;
  bool _analysing = false;
  String? _error;
  Map<String, dynamic>? _info;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void dispose() {
    _culture.dispose();
    _quantite.dispose();
    _stockage.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    setState(() { _loadingInfo = true; _error = null; });
    try {
      final data = await _api.infoIA();
      if (mounted) setState(() => _info = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingInfo = false);
    }
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime(2035),
      helpText: 'Date de récolte',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _analyse() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _analysing = true; _result = null; });
    try {
      final date = '${_date.year.toString().padLeft(4, '0')}-'
          '${_date.month.toString().padLeft(2, '0')}-'
          '${_date.day.toString().padLeft(2, '0')}';
      final data = await _api.predireRisque(
        culture: _culture.text.trim(),
        quantiteKg: double.parse(_quantite.text.replaceAll(',', '.')),
        dateRecolte: date,
        lieuStockage: _stockage.text.trim(),
      );
      if (mounted) setState(() => _result = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _analysing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _info?['disponible'] == true;
    final stats = _info?['donnees'] is Map
        ? Map<String, dynamic>.from(_info!['donnees'] as Map)
        : <String, dynamic>{};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse intelligente'),
        actions: [IconButton(onPressed: _loadInfo, icon: const Icon(Icons.refresh), tooltip: 'Actualiser')],
      ),
      body: _loadingInfo
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInfo,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Card(
                    color: AppColors.primary.withValues(alpha: .07),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Row(children: [
                          Icon(Icons.auto_awesome, color: AppColors.primary, size: 25),
                          SizedBox(width: 10),
                          Expanded(child: Text('Prévision du risque de pertes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
                        ]),
                        const SizedBox(height: 8),
                        const Text('Le modèle Random Forest sera utilisé lorsque l’historique réel sera suffisant et évalué.'),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(child: _stat('Récoltes réelles', '${stats['exemples_reels'] ?? 0}')),
                          const SizedBox(width: 10),
                          Expanded(child: _stat('Minimum requis', '${stats['minimum_requis'] ?? 30}')),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Icon(available ? Icons.check_circle : Icons.info_outline,
                              color: available ? AppColors.success : AppColors.accent),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            available ? 'Modèle Random Forest disponible' : (_info?['message']?.toString() ?? 'Modèle non disponible'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          )),
                        ]),
                      ]),
                    ),
                  ),
                  if (_error != null) Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_error!, style: const TextStyle(color: AppColors.loss)),
                  ),
                  const SizedBox(height: 14),
                  const Text('Données de la récolte', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Form(
                    key: _formKey,
                    child: Column(children: [
                      TextFormField(
                        controller: _culture,
                        decoration: const InputDecoration(labelText: 'Culture (ex. tomate, mil, oignon)', prefixIcon: Icon(Icons.grass_outlined), border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Saisissez la culture.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantite,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Quantité récoltée (kg)', prefixIcon: Icon(Icons.scale_outlined), border: OutlineInputBorder()),
                        validator: (v) {
                          final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                          return n == null || n <= 0 ? 'Saisissez une quantité valide.' : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _chooseDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date de récolte', prefixIcon: Icon(Icons.calendar_today_outlined), border: OutlineInputBorder()),
                          child: Text('${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _stockage,
                        decoration: const InputDecoration(labelText: 'Lieu de stockage (facultatif)', hintText: 'Magasin, silo, hangar…', prefixIcon: Icon(Icons.warehouse_outlined), border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: !available || _analysing ? null : _analyse,
                          icon: _analysing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.insights),
                          label: Text(_analysing ? 'Analyse en cours…' : 'Analyser le risque'),
                        ),
                      ),
                    ]),
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 18),
                    _resultCard(_result!),
                  ],
                  const SizedBox(height: 14),
                  const Text('Limite actuelle : une prédiction ne doit pas être utilisée comme diagnostic agronomique certifié. La qualité dépend de la qualité et de la représentativité des données enregistrées.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                ],
              ),
            ),
    );
  }

  Widget _stat(String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary)),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
    ]),
  );

  Widget _resultCard(Map<String, dynamic> result) {
    final risk = result['risque_affiche']?.toString() ?? 'Non déterminé';
    final factors = (result['facteurs'] as List? ?? []).map((e) => e.toString()).toList();
    final probabilities = result['probabilites'] is Map
        ? Map<String, dynamic>.from(result['probabilites'] as Map)
        : <String, dynamic>{};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Résultat de l’analyse', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Niveau de risque : $risk', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
          if (probabilities.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...probabilities.entries.map((e) => Text('${e.key} : ${((double.tryParse(e.value.toString()) ?? 0) * 100).toStringAsFixed(1)} %')),
          ],
          const SizedBox(height: 12),
          const Text('Facteurs de vigilance', style: TextStyle(fontWeight: FontWeight.w800)),
          ...factors.map((f) => Padding(padding: const EdgeInsets.only(top: 5), child: Text('• $f'))),
          const SizedBox(height: 10),
          Text(result['recommandation']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Modèle : ${result['modele']?['type'] ?? 'Random Forest'} — données réelles : ${result['modele']?['donnees_reelles'] ?? 0}', style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
        ]),
      ),
    );
  }
}
