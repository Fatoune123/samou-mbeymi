import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class OutilsScreen extends StatefulWidget {
  const OutilsScreen({super.key});

  @override
  State<OutilsScreen> createState() => _OutilsScreenState();
}

class _OutilsScreenState extends State<OutilsScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  List<dynamic> _stockages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.tableauBord(),
        _api.stockages(),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as Map<String, dynamic>;
        _stockages = results[1] as List<dynamic>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              Text(_error ?? 'Les données de pilotage sont indisponibles.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final data = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          Text('Pilotage des récoltes', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Synthèse des quantités enregistrées et des pertes déclarées.', style: TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: 16),
          _summaryCard(
            icon: Icons.analytics_outlined,
            title: 'Synthèse de production',
            lines: [
              'Récoltes enregistrées : ${data['nb_recoltes'] ?? 0}',
              'Quantité récoltée : ${data['total_recolte_kg'] ?? 0} kg',
              'Quantité perdue : ${data['total_perte_kg'] ?? 0} kg',
              'Taux de perte : ${data['taux_perte'] ?? 0} %',
            ],
          ),
          const SizedBox(height: 18),
          Text('Points de stockage', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (_stockages.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Aucun point de stockage disponible.')))
          else
            ..._stockages.map((storage) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.warehouse_outlined)),
                title: Text('${storage['nom'] ?? 'Point de stockage'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${storage['region_display'] ?? 'Région non précisée'} · ${storage['capacite_kg'] ?? 0} kg'),
                trailing: Icon(
                  storage['disponible'] == true ? Icons.check_circle_outline : Icons.remove_circle_outline,
                  color: storage['disponible'] == true ? AppColors.success : AppColors.inkSoft,
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _summaryCard({required IconData icon, required String title, required List<String> lines}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)))]),
            const SizedBox(height: 12),
            ...lines.map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(line, style: const TextStyle(color: AppColors.inkSoft)),
            )),
          ],
        ),
      ),
    );
  }
}
