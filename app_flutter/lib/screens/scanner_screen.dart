import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
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
    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (xfile == null || !mounted) return;
      final bytes = await xfile.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _erreur = "La photo sélectionnée est vide. Reprenez la photo.");
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageName = xfile.name.isNotEmpty ? xfile.name : 'recolte.jpg';
        _resultat = null;
        _quantiteEstimeeKg = null;
        _erreur = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.message ??
          "Impossible d'ouvrir la caméra ou la galerie. Vérifiez les autorisations de l'application.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = "Impossible de récupérer la photo : $e");
    }
  }

  Future<void> _ouvrirCamera() async {
    if (_recolteChoisie == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Choisissez d'abord la récolte concernée.")),
      );
      return;
    }

    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'Aucune caméra disponible sur cet appareil.');
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      var capturing = false;
      final captured = await showDialog<XFile>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog.fullscreen(
          child: SafeArea(
            child: StatefulBuilder(
              builder: (context, refreshDialog) => Column(
                children: [
                  AppBar(
                    title: const Text('Photographier la récolte'),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: controller!.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: controller!.value.aspectRatio,
                              child: CameraPreview(controller!),
                            )
                          : const CircularProgressIndicator(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Capturer la photo'),
                        onPressed: capturing || controller!.value.isTakingPicture
                            ? null
                            : () async {
                                refreshDialog(() => capturing = true);
                                try {
                                  final file = await controller!.takePicture();
                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop(file);
                                  }
                                } on CameraException catch (e) {
                                  if (dialogContext.mounted) {
                                    refreshDialog(() => capturing = false);
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                                      SnackBar(content: Text('Capture impossible : ${e.description ?? e.code}')),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (captured == null || !mounted) return;
      final bytes = await captured.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _erreur = 'La caméra a produit une photo vide. Réessayez.');
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageName = captured.name.isNotEmpty ? captured.name : 'recolte.jpg';
        _resultat = null;
        _quantiteEstimeeKg = null;
        _erreur = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _erreur = switch (e.code) {
        'CameraAccessDenied' => 'Autorisez l’accès à la caméra dans les paramètres du téléphone.',
        'CameraAccessDeniedWithoutPrompt' => 'Accès caméra refusé. Activez la permission dans les paramètres.',
        'CameraAccessRestricted' => 'L’accès à la caméra est restreint sur cet appareil.',
        _ => 'Impossible d’ouvrir la caméra : ${e.description ?? e.code}',
      });
    } catch (e) {
      if (mounted) setState(() => _erreur = 'Erreur caméra : $e');
    } finally {
      await controller?.dispose();
    }
  }

  Future<void> _analyser() async {
    if (_imageBytes == null) return;
    setState(() { _loading = true; _erreur = null; });
    try {
      final resultat = await _api.scannerPhoto(_imageBytes!, _imageName);
      final photoAcceptee = resultat['photo_acceptee'] != false;
      final tauxBrut = resultat['taux_zones_ternies'];
      final taux = tauxBrut is num ? tauxBrut.toDouble() : null;

      if (!mounted) return;
      setState(() {
        _resultat = resultat;
        // Une photo refusée ne possède pas forcément de taux de détérioration.
        // Ne jamais estimer de perte ni proposer de la signaler dans ce cas.
        _quantiteEstimeeKg = photoAcceptee && taux != null && _recolteChoisie != null
            ? (_recolteChoisie!.quantiteKg * taux / 100)
            : null;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _erreur =
          "L’analyse prend trop de temps. Vérifiez que le moteur de vision est installé sur Django et que le serveur a terminé le téléchargement initial du modèle, puis réessayez.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _photoAcceptee => _resultat?['photo_acceptee'] != false;

  Color _couleurCategorie(String cat) {
    switch (cat) {
      case 'bon_etat': return AppColors.primary;
      case 'a_surveiller': return AppColors.accent;
      case 'photo_refusee': return AppColors.loss;
      default: return AppColors.loss;
    }
  }

  String _labelCategorie(String cat) {
    switch (cat) {
      case 'bon_etat': return 'Bon état';
      case 'a_surveiller': return 'À surveiller';
      case 'photo_refusee': return 'Photo refusée';
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0B4B37), Color(0xFF167653)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withValues(alpha: .15)),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .18), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.center_focus_strong_rounded, size: 30, color: Colors.white),
                      ),
                      const SizedBox(height: 18),
                      const Text('SCANNER AGRICOLE', style: TextStyle(color: Color(0xFFBCE8D0), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      const SizedBox(height: 6),
                      const Text('Inspectez votre récolte', style: TextStyle(fontSize: 25, height: 1.12, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 8),
                      const Text(
                        "Prenez une photo pour obtenir un indicateur visuel de l’état de vos produits et repérer les signes possibles de dégradation.",
                        style: TextStyle(color: Color(0xFFE0F2E8), height: 1.45, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Row(children: const [
                        Icon(Icons.verified_user_outlined, color: Color(0xFFBCE8D0), size: 16),
                        SizedBox(width: 7),
                        Expanded(child: Text('Analyse indicative — vérification humaine recommandée', style: TextStyle(color: Colors.white, fontSize: 11))),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Align(alignment: Alignment.centerLeft, child: Text('1. Choisir la récolte', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.ink))),
                  const SizedBox(height: 8),
                  if (_recoltes.isEmpty)
                    const Text("Vous devez d'abord enregistrer une récolte.", style: TextStyle(color: AppColors.inkSoft))
                  else
                    DropdownButtonFormField<Recolte>(
                      initialValue: _recolteChoisie,
                      decoration: InputDecoration(labelText: 'Récolte concernée', prefixIcon: const Icon(Icons.agriculture_rounded), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border))),
                      isExpanded: true,
                      items: _recoltes.map((r) => DropdownMenuItem<Recolte>(
                          value: r,
                          child: Text(
                            '${r.cultureNom} — ${r.quantiteKg.toStringAsFixed(0)} kg (${r.dateRecolte})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ))).toList(),
                      onChanged: (v) => setState(() {
                        _recolteChoisie = v;
                        _resultat = null;
                        _quantiteEstimeeKg = null;
                      }),
                    ),
                  const SizedBox(height: 18),
                  Align(alignment: Alignment.centerLeft, child: Text('2. Ajouter une photo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.ink))),
                  const SizedBox(height: 10),
                  if (_imageBytes != null)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .08), blurRadius: 18, offset: const Offset(0, 6))]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Image.memory(_imageBytes!, height: 240, fit: BoxFit.cover, width: double.infinity),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_imageBytes == null)
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: _recoltes.isEmpty || _loading
                            ? null
                            : () => _choisirPhoto(ImageSource.gallery),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Column(children: [
                            Icon(Icons.add_a_photo_outlined, size: 30, color: AppColors.primary),
                            SizedBox(height: 9),
                            Text('Ajoutez une photo de votre récolte', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                            SizedBox(height: 4),
                            Text('Ouvrez la caméra pour voir l’image en direct, capturez votre récolte ou choisissez une photo dans la galerie.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.inkSoft)),
                          ]),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _ouvrirCamera,
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
                  if (_imageBytes != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : () => setState(() {
                                      _imageBytes = null;
                                      _resultat = null;
                                      _quantiteEstimeeKg = null;
                                      _erreur = null;
                                    }),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Changer la photo'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _analyser,
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: const Text('Analyser'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_loading) ...[
                    const SizedBox(height: 24),
                    Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(18)), child: const Row(children: [SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)), SizedBox(width: 14), Expanded(child: Text('Analyse de la photo en cours…', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary))) ])),
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
                                Text(
                                  _photoAcceptee ? 'Diagnostic' : 'Vérification de la photo',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                Chip(
                                  label: Text(_labelCategorie((_resultat!['categorie'] ?? '').toString()),
                                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  backgroundColor: _couleurCategorie((_resultat!['categorie'] ?? '').toString()),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_photoAcceptee && _resultat!['taux_zones_ternies'] is num)
                              Text('Zones ternies détectées : ${_resultat!['taux_zones_ternies']}%'),
                            if (_resultat!['confiance_reconnaissance_pct'] is num) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Confiance indicative de reconnaissance : ${_resultat!['confiance_reconnaissance_pct']}%',
                                style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(_resultat!['message'] ?? '', style: const TextStyle(color: AppColors.inkSoft)),
                            if (!_photoAcceptee) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Conseil : photographiez une seule culture agricole, bien visible et suffisamment éclairée. Évitez les visages et les objets sans rapport avec la récolte.',
                                style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                              ),
                            ],
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
                            if (_photoAcceptee && _resultat!['categorie'] != 'bon_etat' && _recolteChoisie != null && _quantiteEstimeeKg != null) ...[
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
