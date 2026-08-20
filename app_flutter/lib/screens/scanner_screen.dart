import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'pertes_screen.dart';

class ScannerScreen extends StatefulWidget {
  final bool embedded;
  const ScannerScreen({super.key, this.embedded = false});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  String _imageName = 'photo.jpg';
  Map<String, dynamic>? _resultat;
  bool _loading = false;
  bool _chargementRecoltes = true;
  String? _erreur;

  List<Recolte> _recoltes = [];
  Recolte? _recolteChoisie;
  double? _quantiteEstimeeKg;

  @override
  void initState() {
    super.initState();
    _chargerRecoltes();
  }

  Future<void> _chargerRecoltes() async {
    try {
      final data = await _api.recoltes();
      setState(() {
        _recoltes = data.map((e) => Recolte.fromJson(e)).toList();
        _chargementRecoltes = false;
      });
    } catch (e) {
      setState(() => _chargementRecoltes = false);
    }
  }

  Future<void> _choisirPhoto(ImageSource source) async {
    if (_recolteChoisie == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Choisissez d'abord la récolte concernée.")),
      );
      return;
    }
    final xfile = await _picker.pickImage(source: source, maxWidth: 1024);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageName = xfile.name;
      _resultat = null;
      _quantiteEstimeeKg = null;
      _erreur = null;
    });
    await _analyser();
  }

  Future<void> _analyser() async {
    if (_imageBytes == null) return;
    setState(() { _loading = true; _erreur = null; });
    try {
      final resultat = await _api.scannerPhoto(_imageBytes!, _imageName);
      setState(() {
        _resultat = resultat;
        if (_recolteChoisie != null) {
          final taux = (resultat['taux_zones_ternies'] as num).toDouble();
          _quantiteEstimeeKg = (_recolteChoisie!.quantiteKg * taux / 100);
        }
      });
    } catch (e) {
      setState(() => _erreur = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _couleurCategorie(String cat) {
    switch (cat) {
      case 'bon_etat': return AppColors.primary;
      case 'a_surveiller': return AppColors.accent;
      default: return AppColors.loss;
    }
  }

  String _labelCategorie(String cat) {
    switch (cat) {
      case 'bon_etat': return 'Bon état';
      case 'a_surveiller': return 'À surveiller';
      default: return 'Détérioration probable';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Scanner IA')),
      body: _chargementRecoltes
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome, size: 40, color: AppColors.primary),
                  const SizedBox(height: 8),
                  const Text('Scanner une récolte', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 6),
                  const Text(
                    "Choisissez la récolte concernée puis prenez une photo. On estime directement la quantité (en kg) potentiellement touchée.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 20),
                  if (_recoltes.isEmpty)
                    const Text("Vous devez d'abord enregistrer une récolte.", style: TextStyle(color: AppColors.inkSoft))
                  else
                    DropdownButtonFormField<Recolte>(
                      initialValue: _recolteChoisie,
                      decoration: const InputDecoration(labelText: 'Récolte concernée'),
                      items: _recoltes.map((r) => DropdownMenuItem(
                          value: r, child: Text('${r.cultureNom} — ${r.quantiteKg.toStringAsFixed(0)} kg (${r.dateRecolte})'))).toList(),
                      onChanged: (v) => setState(() {
                        _recolteChoisie = v;
                        _resultat = null;
                        _quantiteEstimeeKg = null;
                      }),
                    ),
                  const SizedBox(height: 16),
                  if (_imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(_imageBytes!, height: 220, fit: BoxFit.cover, width: double.infinity),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _choisirPhoto(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Caméra'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _choisirPhoto(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galerie'),
                        ),
                      ),
                    ],
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                  ],
                  if (_erreur != null) ...[
                    const SizedBox(height: 16),
                    Text('Erreur : $_erreur', style: const TextStyle(color: AppColors.loss)),
                  ],
                  if (_resultat != null) ...[
                    const SizedBox(height: 20),
                    Card(
                      color: _couleurCategorie(_resultat!['categorie']).withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Diagnostic', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                Chip(
                                  label: Text(_labelCategorie(_resultat!['categorie']),
                                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  backgroundColor: _couleurCategorie(_resultat!['categorie']),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('Zones ternies détectées : ${_resultat!['taux_zones_ternies']}%'),
                            const SizedBox(height: 6),
                            Text(_resultat!['message'] ?? '', style: const TextStyle(color: AppColors.inkSoft)),
                            if (_quantiteEstimeeKg != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.lossSoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('QUANTITÉ POTENTIELLEMENT TOUCHÉE',
                                        style: TextStyle(fontSize: 11, color: AppColors.loss, letterSpacing: 0.5)),
                                    const SizedBox(height: 4),
                                    Text('${_quantiteEstimeeKg!.toStringAsFixed(1)} kg',
                                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.loss)),
                                    Text('sur les ${_recolteChoisie!.quantiteKg.toStringAsFixed(0)} kg de cette récolte',
                                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            const Text(
                              "Analyse visuelle indicative — à confirmer par votre propre observation.",
                              style: TextStyle(fontSize: 11, color: AppColors.inkSoft, fontStyle: FontStyle.italic),
                            ),
                            if (_resultat!['categorie'] != 'bon_etat' && _recolteChoisie != null) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
                                  icon: const Icon(Icons.report_problem),
                                  label: Text('Signaler cette perte (${_quantiteEstimeeKg?.toStringAsFixed(1)} kg pré-rempli)'),
                                  onPressed: () {
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => SignalerPerteScreen(
                                        recolteInitiale: _recolteChoisie,
                                        quantiteInitiale: _quantiteEstimeeKg,
                                      ),
                                    ));
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
