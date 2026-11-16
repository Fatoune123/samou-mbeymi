import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../theme.dart';

/// Marché agricole géolocalisé : annonces de récoltes et demandes de livraison.
class LocalisationScreen extends StatefulWidget {
  const LocalisationScreen({super.key});

  @override
  State<LocalisationScreen> createState() => _LocalisationScreenState();
}

class _LocalisationScreenState extends State<LocalisationScreen> {
  final _api = ApiService();
  final _produit = TextEditingController();
  final _commune = TextEditingController();
  final _region = TextEditingController();
  final _latSearch = TextEditingController();
  final _lonSearch = TextEditingController();
  List<dynamic> _offres = [];
  bool _chargement = true;
  bool _actionEnCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _produit.dispose();
    _commune.dispose();
    _region.dispose();
    _latSearch.dispose();
    _lonSearch.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() { _chargement = true; _erreur = null; });
    try {
      final lat = _latSearch.text.trim().isEmpty ? null : double.tryParse(_latSearch.text.trim().replaceAll(',', '.'));
      final lon = _lonSearch.text.trim().isEmpty ? null : double.tryParse(_lonSearch.text.trim().replaceAll(',', '.'));
      if ((lat == null) != (lon == null)) throw ApiException('Pour rechercher par proximité, renseignez la latitude et la longitude.');
      final result = await _api.offresRecolte(produit: _produit.text, region: _region.text, commune: _commune.text, latitude: lat, longitude: lon); 
      if (!mounted) return;
      setState(() => _offres = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  double? _number(dynamic value) => value == null ? null : double.tryParse(value.toString());

  List<Marker> _markers() {
    return _offres.where((item) => _number(item['latitude']) != null && _number(item['longitude']) != null).map((item) {
      final point = LatLng(_number(item['latitude'])!, _number(item['longitude'])!);
      return Marker(
        point: point,
        width: 42,
        height: 42,
        child: const Icon(Icons.location_on, color: AppColors.primary, size: 38),
      );
    }).toList();
  }

  Future<void> _publierOffre() async {
    List<dynamic> recoltes;
    try {
      recoltes = await _api.recoltes();
    } catch (e) {
      _message('Impossible de charger vos récoltes : $e');
      return;
    }
    if (!mounted) return;
    if (recoltes.isEmpty) {
      _message('Enregistrez d’abord une récolte dans l’onglet Récoltes.');
      return;
    }
    final formKey = GlobalKey<FormState>();
    final qty = TextEditingController();
    final price = TextEditingController();
    final commune = TextEditingController();
    final lat = TextEditingController();
    final lon = TextEditingController();
    final description = TextEditingController();
    int selectedId = int.tryParse(recoltes.first['id'].toString()) ?? 0;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Publier une récolte'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              value: selectedId,
              decoration: const InputDecoration(labelText: 'Récolte à vendre'),
              items: recoltes.map((r) => DropdownMenuItem<int>(
                value: int.tryParse(r['id'].toString()),
                child: Text('${r['culture_nom'] ?? 'Culture'} — ${r['quantite_kg']} kg', overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) { if (v != null) setDialogState(() => selectedId = v); },
            ),
            const SizedBox(height: 10),
            TextFormField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantité à vendre (kg)'), validator: _positive),
            TextFormField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Prix par kg (FCFA)'), validator: _positive),
            TextFormField(controller: commune, decoration: const InputDecoration(labelText: 'Commune / village')),
            TextFormField(controller: lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitude (facultatif)')),
            TextFormField(controller: lon, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitude (facultatif)')),
            TextFormField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Qualité, conditionnement, disponibilité')),
            const SizedBox(height: 8),
            const Text('La carte utilise les coordonnées fournies. Sans coordonnées, l’annonce apparaît dans la liste mais pas sur la carte.', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ]),
        ))),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(
            onPressed: saving ? null : () async {
              if (!formKey.currentState!.validate()) return;
              final latitude = lat.text.trim().isEmpty ? null : double.tryParse(lat.text.trim().replaceAll(',', '.'));
              final longitude = lon.text.trim().isEmpty ? null : double.tryParse(lon.text.trim().replaceAll(',', '.'));
              if ((latitude == null) != (longitude == null)) {
                _message('Renseignez les deux coordonnées ou laissez les deux vides.');
                return;
              }
              setDialogState(() => saving = true);
              try {
                await _api.creerOffre(
                  recolteId: selectedId,
                  quantiteKg: double.parse(qty.text.trim().replaceAll(',', '.')),
                  prixKgFcfa: double.parse(price.text.trim().replaceAll(',', '.')),
                  commune: commune.text.trim(), latitude: latitude, longitude: longitude,
                  description: description.text.trim(),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _charger();
                _message('Annonce publiée.');
              } catch (e) {
                setDialogState(() => saving = false);
                _message('Publication impossible : $e');
              }
            },
            child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Publier'),
          ),
        ],
      )),
    );
    qty.dispose(); price.dispose(); commune.dispose(); lat.dispose(); lon.dispose(); description.dispose();
  }

  Future<void> _mesCommandes() async {
    try {
      final commandes = await _api.commandesLivraison();
      final profil = await _api.profil();
      if (!mounted) return;
      final labels = <String, String>{
        'demandee': 'Demande envoyée', 'confirmee': 'Confirmée',
        'preparation': 'En préparation', 'expediee': 'Expédiée',
        'livree': 'Livrée', 'annulee': 'Annulée',
      };
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .78,
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(18), child: Row(children: [
              const Expanded(child: Text('Suivi des commandes et livraisons', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
            ])),
            const Divider(height: 1),
            Expanded(child: commandes.isEmpty
              ? const Center(child: Text('Aucune commande pour le moment.'))
              : ListView.builder(padding: const EdgeInsets.all(12), itemCount: commandes.length, itemBuilder: (ctx, i) {
                  final c = Map<String, dynamic>.from(commandes[i]);
                  final statut = c['statut']?.toString() ?? 'demandee';
                  final producteur = c['producteur']?.toString() ?? '';
                  final currentLabels = [profil['nom_exploitation']?.toString(), profil['nom_complet']?.toString(), profil['username']?.toString()].whereType<String>().where((x) => x.isNotEmpty).toSet();
                  final isProducer = currentLabels.contains(producteur);
                  final isBuyer = c['acheteur_nom']?.toString() == profil['username']?.toString();
                  final next = <String, String>{'demandee': 'confirmee', 'confirmee': 'preparation', 'preparation': 'expediee', 'expediee': 'livree'}[statut];
                  return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${c['culture_nom'] ?? 'Récolte'} — ${c['quantite_kg']} kg', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Producteur : $producteur · Acheteur : ${c['acheteur_nom'] ?? '—'}'),
                    Text('Livraison : ${c['adresse_livraison'] ?? '—'}'),
                    const SizedBox(height: 6),
                    Chip(label: Text(labels[statut] ?? statut)),
                    if (isProducer && next != null) Align(alignment: Alignment.centerRight, child: TextButton.icon(
                      onPressed: () async {
                        try {
                          await _api.modifierStatutCommande(int.parse(c['id'].toString()), next);
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          _message('Statut de livraison mis à jour.');
                          await _mesCommandes();
                        } catch (e) { _message('Mise à jour impossible : $e'); }
                      }, icon: const Icon(Icons.arrow_forward), label: Text('Passer à : ${labels[next]}'),
                    )),
                    if (isBuyer && !isProducer && !['livree', 'annulee'].contains(statut)) Align(alignment: Alignment.centerRight, child: TextButton.icon(
                      onPressed: () async {
                        try {
                          await _api.modifierStatutCommande(int.parse(c['id'].toString()), 'annulee');
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          _message('Commande annulée.');
                          await _mesCommandes();
                        } catch (e) { _message('Annulation impossible : $e'); }
                      }, icon: const Icon(Icons.cancel_outlined), label: const Text('Annuler la commande'),
                    )),
                  ])));
                })),
          ]),
        )),
      );
    } catch (e) {
      _message('Impossible de charger les commandes : $e');
    }
  }

  String? _positive(String? value) {
    final n = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (n == null || n <= 0) return 'Saisissez une valeur supérieure à zéro.';
    return null;
  }

  Future<void> _commander(Map<String, dynamic> offre) async {
    final qty = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    final notes = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Demander ${offre['culture_nom'] ?? 'cette récolte'}'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Disponible : ${offre['quantite_restante_kg'] ?? offre['quantite_kg']} kg · ${offre['prix_kg_fcfa']} FCFA/kg'),
                  TextFormField(
                    controller: qty,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantité demandée (kg)'),
                    validator: _positive,
                  ),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone de contact'),
                    validator: (v) => (v == null || v.trim().length < 6) ? 'Téléphone requis.' : null,
                  ),
                  TextFormField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Lieu de livraison'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Lieu de livraison requis.' : null,
                  ),
                  TextFormField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Précisions (facultatif)'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Retour')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Envoyer la demande'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await _api.demanderLivraison(
          offreId: int.parse(offre['id'].toString()),
          quantiteKg: double.parse(qty.text.trim().replaceAll(',', '.')),
          telephone: phone.text.trim(), adresseLivraison: address.text.trim(), notes: notes.text.trim(),
        );
        _message('Demande envoyée au producteur.');
        await _charger();
      } catch (e) {
        _message('Demande impossible : $e');
      }
    }
    qty.dispose(); phone.dispose(); address.dispose(); notes.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final markers = _markers();
    final initial = markers.isNotEmpty
        ? markers.first.point
        : const LatLng(14.4974, -14.4524);

    return RefreshIndicator(
      onRefresh: _charger,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 28 : 16,
              vertical: 16,
            ),
            children: [
              // En-tête éditorial : identité visuelle du marché.
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryDark, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.accent,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Le marché agricole',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.4,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Des récoltes locales, des échanges plus simples.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .82),
                              height: 1.4,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              '${_offres.length} annonce${_offres.length == 1 ? '' : 's'} disponible${_offres.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Recherche principale, compacte et adaptée au mobile.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune_rounded,
                              color: AppColors.primary, size: 21),
                          SizedBox(width: 8),
                          Text(
                            'Trouver une récolte',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      TextField(
                        controller: _produit,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _charger(),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Ex. oignon, tomate, pomme de terre',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _commune,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _charger(),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.location_on_outlined),
                          hintText: 'Commune ou village',
                        ),
                      ),
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 8),
                          leading: const Icon(
                            Icons.filter_alt_outlined,
                            color: AppColors.inkSoft,
                          ),
                          title: const Text(
                            'Filtres avancés',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: const Text(
                            'Région et proximité GPS',
                            style: TextStyle(fontSize: 11),
                          ),
                          children: [
                            TextField(
                              controller: _region,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _charger(),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.map_outlined),
                                labelText: 'Région (ex. thies, dakar)',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _latSearch,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Latitude',
                                      hintText: 'Optionnel',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _lonSearch,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Longitude',
                                      hintText: 'Optionnel',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      FilledButton.icon(
                        onPressed: _chargement ? null : _charger,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Rechercher les récoltes'),
                      ),
                      const SizedBox(height: 10),
                      if (wide)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _publierOffre,
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Publier une récolte'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _mesCommandes,
                                icon: const Icon(Icons.local_shipping_outlined),
                                label: const Text('Mes commandes'),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _publierOffre,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Publier une récolte'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _mesCommandes,
                              icon: const Icon(Icons.local_shipping_outlined),
                              label: const Text('Mes commandes'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Carte uniquement si des annonces possèdent des coordonnées.
              Row(
                children: [
                  const Icon(Icons.map_outlined,
                      color: AppColors.primary, size: 21),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Récoltes autour de vous',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (markers.isNotEmpty)
                    Text(
                      '${markers.length} point${markers.length == 1 ? '' : 's'} GPS',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (markers.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    height: wide ? 320 : 220,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: initial,
                        initialZoom: 6.2,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'sn.samoumbeymi.app',
                        ),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: .12),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.location_searching_rounded,
                          color: AppColors.primary, size: 25),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'La carte affichera les annonces avec coordonnées GPS. Les autres récoltes restent consultables dans la liste.',
                          style: TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 22),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Récoltes disponibles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.3,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '${_offres.length}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _charger,
                    tooltip: 'Actualiser',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_chargement)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                )
              else if (_erreur != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off_outlined,
                            color: AppColors.loss, size: 32),
                        const SizedBox(height: 8),
                        Text(_erreur!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: _charger,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_offres.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        const Icon(Icons.agriculture_outlined,
                            size: 38, color: AppColors.inkSoft),
                        const SizedBox(height: 10),
                        const Text(
                          'Aucune récolte trouvée',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Modifiez les filtres ou publiez votre récolte pour la proposer aux acheteurs.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _publierOffre,
                          icon: const Icon(Icons.add),
                          label: const Text('Publier une récolte'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._offres.map(
                  (raw) => _offreCard(Map<String, dynamic>.from(raw)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _offreCard(Map<String, dynamic> offre) {
    final culture = offre['culture_nom']?.toString() ?? 'Culture';
    final producteur = offre['producteur']?.toString() ?? 'Producteur';
    final commune = offre['commune']?.toString() ?? '';
    final region = offre['region']?.toString() ?? '';
    final prix = offre['prix_kg_fcfa']?.toString() ?? '—';
    final qty = offre['quantite_restante_kg']?.toString() ??
        offre['quantite_kg']?.toString() ?? '—';
    final distance = offre['distance_km'];
    final description = offre['description']?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.successSoft, Color(0xFFF4F8F1)],
                    ),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        culture,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 14, color: AppColors.inkSoft),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              producteur,
                              style: const TextStyle(
                                color: AppColors.inkSoft,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$prix F',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'par kg',
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(Icons.scale_outlined,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '$qty kg disponibles',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (distance != null) ...[
                    const Icon(Icons.near_me_outlined,
                        color: AppColors.inkSoft, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '${distance.toString()} km',
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (commune.isNotEmpty || region.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (commune.isNotEmpty)
                    _chip(Icons.location_on_outlined, commune),
                  if (region.isNotEmpty)
                    _chip(Icons.map_outlined, region),
                ],
              ),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _actionEnCours ? null : () => _commander(offre),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Demander une livraison'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Chip(avatar: Icon(icon, size: 15), label: Text(text), visualDensity: VisualDensity.compact, side: BorderSide.none, backgroundColor: AppColors.bg);
}
