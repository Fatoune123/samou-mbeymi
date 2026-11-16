
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration de l'URL du backend Django.
///
/// Appareil Android physique : adresse IP locale de l'ordinateur.
/// Émulateur Android : http://10.0.2.2:8000/api.
/// Web et ordinateur : http://127.0.0.1:8000/api.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.26:8000/api',
  );
}

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  static const _tokenKey = 'auth_token';

  Future<String?> get token async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> deconnexion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final t = await token;

    return {
      if (json) 'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Token $t',
    };
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  dynamic _decode(http.Response resp) {
    final body = resp.body.isNotEmpty
        ? jsonDecode(utf8.decode(resp.bodyBytes))
        : null;

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return body;
    }

    String msg = 'Erreur (${resp.statusCode})';

    if (body is Map) {
      msg = body.values
          .map((v) => v is List ? v.join(', ') : v.toString())
          .join(' — ');
    }

    throw ApiException(msg);
  }

  // ---------- AUTHENTIFICATION ----------

  Future<void> inscription({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String telephone,
    required String region,
    required String nomExploitation,
  }) async {
    final resp = await http.post(
      _uri('/inscription/'),
      headers: await _headers(),
      body: jsonEncode({
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
        'telephone': telephone,
        'region': region,
        'nom_exploitation': nomExploitation,
      }),
    );

    final data = _decode(resp);
    await _saveToken(data['token']);
  }

  Future<void> connexion({
    required String username,
    required String password,
  }) async {
    final resp = await http.post(
      _uri('/connexion/'),
      headers: await _headers(),
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final data = _decode(resp);
    await _saveToken(data['token']);
  }

  // ---------- PROFIL ----------

  Future<Map<String, dynamic>> profil() async {
    final resp = await http.get(
      _uri('/profil/'),
      headers: await _headers(),
    );

    return _decode(resp);
  }

  // ---------- CULTURES ----------

  Future<List<dynamic>> cultures() async {
    final resp = await http.get(
      _uri('/cultures/'),
      headers: await _headers(),
    );

    final data = _decode(resp);

    return data is Map && data.containsKey('results')
        ? data['results']
        : data;
  }

  // ---------- RÉCOLTES ----------

  Future<List<dynamic>> recoltes() async {
    final resp = await http.get(
      _uri('/recoltes/'),
      headers: await _headers(),
    );

    final data = _decode(resp);

    return data is Map && data.containsKey('results')
        ? data['results']
        : data;
  }

  Future<Map<String, dynamic>> ajouterRecolte({
    required int cultureId,
    required double quantiteKg,
    required String dateRecolte,
    String lieuStockage = '',
    String notes = '',
  }) async {
    final resp = await http.post(
      _uri('/recoltes/'),
      headers: await _headers(),
      body: jsonEncode({
        'culture': cultureId,
        'quantite_kg': quantiteKg,
        'date_recolte': dateRecolte,
        'lieu_stockage': lieuStockage,
        'notes': notes,
      }),
    );

    return _decode(resp);
  }

  // ---------- TRAÇABILITÉ DES RÉCOLTES ----------

  Future<List<dynamic>> evenementsTraceabilite(int recolteId) async {
    final uri = _uri('/traceabilite/evenements/').replace(
      queryParameters: {
        'recolte': recolteId.toString(),
      },
    );

    final resp = await http.get(
      uri,
      headers: await _headers(),
    );

    final data = _decode(resp);

    return data is Map && data.containsKey('results')
        ? List<dynamic>.from(data['results'])
        : List<dynamic>.from(data as List);
  }

  Future<Map<String, dynamic>> ajouterEvenementTraceabilite({
    required int recolteId,
    required String typeEvenement,
    required String description,
    String lieu = '',
    double? quantiteKg,
  }) async {
    final resp = await http.post(
      _uri('/traceabilite/evenements/'),
      headers: await _headers(),
      body: jsonEncode({
        'recolte': recolteId,
        'type_evenement': typeEvenement,
        'description': description,
        'lieu': lieu,
        if (quantiteKg != null) 'quantite_kg': quantiteKg,
      }),
    );

    return Map<String, dynamic>.from(_decode(resp) as Map);
  }

  // ---------- PERTES ----------

  Future<List<dynamic>> pertes() async {
    final resp = await http.get(
      _uri('/pertes/'),
      headers: await _headers(),
    );

    final data = _decode(resp);

    return data is Map && data.containsKey('results')
        ? data['results']
        : data;
  }

  Future<Map<String, dynamic>> signalerPerte({
    required int recolteId,
    required String typePerte,
    required double quantitePerdueKg,
    String description = '',
  }) async {
    final resp = await http.post(
      _uri('/pertes/'),
      headers: await _headers(),
      body: jsonEncode({
        'recolte': recolteId,
        'type_perte': typePerte,
        'quantite_perdue_kg': quantitePerdueKg,
        'description': description,
        'statut': 'signalee',
      }),
    );

    return _decode(resp);
  }

  // ---------- TABLEAU DE BORD ----------

  Future<Map<String, dynamic>> tableauBord() async {
    final resp = await http.get(
      _uri('/tableau-de-bord/'),
      headers: await _headers(),
    );

    return _decode(resp);
  }

  // ---------- IA (Phase 6) ----------

  Future<Map<String, dynamic>> predireRisque({
    required String culture,
    required double quantiteKg,
    required String dateRecolte,
    String lieuStockage = '',
  }) async {
    final resp = await http.post(
      _uri('/ia/predire-risque/'),
      headers: await _headers(),
      body: jsonEncode({
        'culture': culture,
        'quantite_kg': quantiteKg,
        'date_recolte': dateRecolte,
        'lieu_stockage': lieuStockage,
      }),
    );

    return _decode(resp);
  }

  Future<Map<String, dynamic>> scannerPhoto(
    List<int> bytes,
    String filename,
  ) async {
    final t = await token;

    final request = http.MultipartRequest(
      'POST',
      _uri('/ia/scanner-photo/'),
    );

    if (t != null) {
      request.headers['Authorization'] = 'Token $t';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        bytes,
        filename: filename,
      ),
    );

    // Le premier chargement du modèle de vision peut être long.
    final streamed = await request.send().timeout(
      const Duration(seconds: 120),
    );

    final resp = await http.Response.fromStream(streamed).timeout(
      const Duration(seconds: 30),
    );

    if (resp.statusCode == 422) {
      final body = resp.body.isNotEmpty
          ? jsonDecode(utf8.decode(resp.bodyBytes))
          : <String, dynamic>{};

      if (body is Map<String, dynamic>) {
        return body;
      }

      if (body is Map) {
        return Map<String, dynamic>.from(body);
      }

      throw ApiException('Réponse inattendue du scanner (422).');
    }

    return _decode(resp);
  }

  Future<void> modifierRecolte(
    int id, {
    required int cultureId,
    required double quantiteKg,
    required String dateRecolte,
    String lieuStockage = '',
    String notes = '',
  }) async {
    final resp = await http.patch(
      _uri('/recoltes/$id/'),
      headers: await _headers(),
      body: jsonEncode({
        'culture': cultureId,
        'quantite_kg': quantiteKg,
        'date_recolte': dateRecolte,
        'lieu_stockage': lieuStockage,
        'notes': notes,
      }),
    );

    _decode(resp);
  }

  Future<void> supprimerRecolte(int id) async {
    final resp = await http.delete(
      _uri('/recoltes/$id/'),
      headers: await _headers(),
    );

    _decode(resp);
  }

  Future<void> modifierPerte(
    int id, {
    required int recolteId,
    required String typePerte,
    required double quantitePerdueKg,
    String description = '',
    String statut = 'signalee',
  }) async {
    final resp = await http.patch(
      _uri('/pertes/$id/'),
      headers: await _headers(),
      body: jsonEncode({
        'recolte': recolteId,
        'type_perte': typePerte,
        'quantite_perdue_kg': quantitePerdueKg,
        'description': description,
        'statut': statut,
      }),
    );

    _decode(resp);
  }

  Future<void> supprimerPerte(int id) async {
    final resp = await http.delete(
      _uri('/pertes/$id/'),
      headers: await _headers(),
    );

    _decode(resp);
  }

  Future<Map<String, dynamic>> modifierProfil({
    required String firstName,
    required String lastName,
    required String email,
    required String telephone,
    required String region,
    required String nomExploitation,
  }) async {
    final resp = await http.patch(
      _uri('/profil/'),
      headers: await _headers(),
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'telephone': telephone,
        'region': region,
        'nom_exploitation': nomExploitation,
      }),
    );

    return _decode(resp);
  }

  Future<List<dynamic>> stockages() async {
    final resp = await http.get(
      _uri('/stockages/'),
      headers: await _headers(),
    );

    final data = _decode(resp);

    return data is Map && data.containsKey('results')
        ? data['results']
        : data;
  }

  Future<Map<String, dynamic>> infoIA() async {
    final resp = await http.get(
      _uri('/ia/info/'),
      headers: await _headers(),
    );

    return _decode(resp);
  }

  // ---------- ASSISTANT CONVERSATIONNEL AGRICOLE ----------

  Future<Map<String, dynamic>> conseillerAgricole({
    required String question,
    String langue = 'fr-FR',
  }) async {
    try {
      final resp = await http.post(
        _uri('/ia/conseiller/'),
        headers: await _headers(),
        body: jsonEncode({
          'question': question,
          'langue': langue,
        }),
      ).timeout(const Duration(seconds: 65));

      return Map<String, dynamic>.from(_decode(resp) as Map);
    } on TimeoutException {
      throw ApiException(
        'Le serveur met plus de 65 secondes à répondre. '
        'Vérifiez la connexion et le terminal Django, puis réessayez.',
      );
    } on http.ClientException {
      throw ApiException(
        'Connexion au serveur impossible. '
        'Vérifiez son adresse et assurez-vous que Django est démarré.',
      );
    }
  }

  Future<String> transcrireAudioAssistant({
    required Uint8List wavBytes,
    required String langue,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/ia/transcrire-audio/'),
    );

    final t = await token;

    if (t != null) {
      request.headers['Authorization'] = 'Token $t';
    }

    request.headers['Accept'] = 'application/json';
    request.fields['langue'] = langue;

    request.files.add(
      http.MultipartFile.fromBytes(
        'audio',
        wavBytes,
        filename: 'question.wav',
      ),
    );

    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );

      final response = await http.Response.fromStream(streamed);
      final decoded = _decode(response);

      if (decoded is! Map ||
          (decoded['transcription'] ?? '').toString().trim().isEmpty) {
        throw ApiException(
          'Aucune transcription exploitable. '
          'Réessayez en parlant plus distinctement.',
        );
      }

      return decoded['transcription'].toString().trim();
    } on TimeoutException {
      throw ApiException(
        'La transcription prend trop de temps. '
        'Réessayez avec une phrase plus courte.',
      );
    } on http.ClientException {
      throw ApiException(
        'Connexion au serveur impossible pendant la transcription audio.',
      );
    }
  }

  // ---------- LOCALISATION INTELLIGENTE / MARCHÉ AGRICOLE ----------

  Future<List<dynamic>> offresRecolte({
    String produit = '',
    String region = '',
    String commune = '',
    double? latitude,
    double? longitude,
    double rayonKm = 50,
  }) async {
    final params = <String, String>{};

    if (produit.trim().isNotEmpty) {
      params['produit'] = produit.trim();
    }

    if (region.trim().isNotEmpty) {
      params['region'] = region.trim();
    }

    if (commune.trim().isNotEmpty) {
      params['commune'] = commune.trim();
    }

    if (latitude != null && longitude != null) {
      params['latitude'] = latitude.toString();
      params['longitude'] = longitude.toString();
      params['rayon_km'] = rayonKm.toString();
    }

    final uri = _uri('/marketplace/offres/').replace(
      queryParameters: params.isEmpty ? null : params,
    );

    final resp = await http.get(
      uri,
      headers: await _headers(),
    );

    final data = _decode(resp);

    return data is Map && data.containsKey('results')
        ? List<dynamic>.from(data['results'])
        : List<dynamic>.from(data as List);
  }

  Future<Map<String, dynamic>> creerOffre({
    required int recolteId,
    required double quantiteKg,
    required double prixKgFcfa,
    String commune = '',
    double? latitude,
    double? longitude,
    String description = '',
  }) async {
    final resp = await http.post(
      _uri('/marketplace/offres/'),
      headers: await _headers(),
      body: jsonEncode({
        'recolte': recolteId,
        'quantite_kg': quantiteKg,
        'prix_kg_fcfa': prixKgFcfa,
        'commune': commune,
        if (latitude != null && longitude != null)
          'latitude': latitude,
        if (latitude != null && longitude != null)
          'longitude': longitude,
        'description': description,
      }),
    );

    return Map<String, dynamic>.from(_decode(resp) as Map);
  }

  Future<List<dynamic>> commandesLivraison() async {
    final resp = await http.get(
      _uri('/marketplace/commandes/'),
      headers: await _headers(),
    );

    final data = _decode(resp);

    return data is Map && data.containsKey('results')
        ? List<dynamic>.from(data['results'])
        : List<dynamic>.from(data as List);
  }

  Future<Map<String, dynamic>> demanderLivraison({
    required int offreId,
    required double quantiteKg,
    required String telephone,
    required String adresseLivraison,
    String notes = '',
  }) async {
    final resp = await http.post(
      _uri('/marketplace/commandes/'),
      headers: await _headers(),
      body: jsonEncode({
        'offre': offreId,
        'quantite_kg': quantiteKg,
        'telephone_contact': telephone,
        'adresse_livraison': adresseLivraison,
        'notes': notes,
      }),
    );

    return Map<String, dynamic>.from(_decode(resp) as Map);
  }

  // ---------- NOUVEAUX MODULES AGRICOLES ----------

  Future<Map<String, dynamic>> conseilsConservation(
    String produit,
  ) async {
    final uri = _uri('/conservation/conseils/').replace(
      queryParameters: {'produit': produit},
    );

    final resp = await http.get(
      uri,
      headers: await _headers(),
    );

    return Map<String, dynamic>.from(_decode(resp) as Map);
  }

  Future<Map<String, dynamic>> conseilsPhytosanitaires(
    String culture,
  ) async {
    final uri = _uri('/phytosanitaire/conseils/').replace(
      queryParameters: {'culture': culture},
    );

    final resp = await http.get(
      uri,
      headers: await _headers(),
    );

    return Map<String, dynamic>.from(_decode(resp) as Map);
  }

  Future<Map<String, dynamic>> catalogueEngrais() async {
    final resp = await http.get(
      _uri('/engrais/catalogue/'),
      headers: await _headers(),
    );

    return Map<String, dynamic>.from(_decode(resp) as Map);
  }

  Future<void> modifierStatutCommande(
    int id,
    String statut,
  ) async {
    final resp = await http.patch(
      _uri('/marketplace/commandes/$id/'),
      headers: await _headers(),
      body: jsonEncode({'statut': statut}),
    );

    _decode(resp);
  }
}
