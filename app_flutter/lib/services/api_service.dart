import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration de l'URL du backend Django.
///
/// - Émulateur Android : 10.0.2.2 pointe vers le "localhost" de la machine hôte.
/// - Web (Chrome/Edge), Windows/macOS/Linux desktop, simulateur iOS : http://127.0.0.1:8000
/// - Appareil physique : remplacer par l'adresse IP locale de votre machine
///   (ex: http://192.168.1.10:8000) — le téléphone et l'ordinateur doivent
///   être sur le même réseau Wi-Fi.
class ApiConfig {
  static final String baseUrl = () {
    if (const String.fromEnvironment('API_BASE_URL').isNotEmpty) return const String.fromEnvironment('API_BASE_URL');
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000/api';
    return 'http://127.0.0.1:8000/api';
  }();
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
    final body = resp.body.isNotEmpty ? jsonDecode(utf8.decode(resp.bodyBytes)) : null;
    if (resp.statusCode >= 200 && resp.statusCode < 300) return body;
    String msg = 'Erreur (${resp.statusCode})';
    if (body is Map) {
      msg = body.values.map((v) => v is List ? v.join(', ') : v.toString()).join(' — ');
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

  Future<void> connexion({required String username, required String password}) async {
    final resp = await http.post(
      _uri('/connexion/'),
      headers: await _headers(),
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = _decode(resp);
    await _saveToken(data['token']);
  }

  // ---------- PROFIL ----------

  Future<Map<String, dynamic>> profil() async {
    final resp = await http.get(_uri('/profil/'), headers: await _headers());
    return _decode(resp);
  }

  // ---------- CULTURES ----------

  Future<List<dynamic>> cultures() async {
    final resp = await http.get(_uri('/cultures/'), headers: await _headers());
    final data = _decode(resp);
    return data is Map && data.containsKey('results') ? data['results'] : data;
  }

  // ---------- RÉCOLTES ----------

  Future<List<dynamic>> recoltes() async {
    final resp = await http.get(_uri('/recoltes/'), headers: await _headers());
    final data = _decode(resp);
    return data is Map && data.containsKey('results') ? data['results'] : data;
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

  // ---------- PERTES ----------

  Future<List<dynamic>> pertes() async {
    final resp = await http.get(_uri('/pertes/'), headers: await _headers());
    final data = _decode(resp);
    return data is Map && data.containsKey('results') ? data['results'] : data;
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
    final resp = await http.get(_uri('/tableau-de-bord/'), headers: await _headers());
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

  Future<Map<String, dynamic>> scannerPhoto(List<int> bytes, String filename) async {
    final t = await token;
    final request = http.MultipartRequest('POST', _uri('/ia/scanner-photo/'));
    if (t != null) request.headers['Authorization'] = 'Token $t';
    request.files.add(http.MultipartFile.fromBytes('photo', bytes, filename: filename));
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    return _decode(resp);
  }

  Future<void> modifierRecolte(int id, {required int cultureId, required double quantiteKg, required String dateRecolte, String lieuStockage = '', String notes = ''}) async {
    final resp = await http.patch(_uri('/recoltes/$id/'), headers: await _headers(), body: jsonEncode({
      'culture': cultureId, 'quantite_kg': quantiteKg, 'date_recolte': dateRecolte, 'lieu_stockage': lieuStockage, 'notes': notes,
    }));
    _decode(resp);
  }

  Future<void> supprimerRecolte(int id) async {
    final resp = await http.delete(_uri('/recoltes/$id/'), headers: await _headers());
    _decode(resp);
  }

  Future<void> modifierPerte(int id, {required int recolteId, required String typePerte, required double quantitePerdueKg, String description = '', String statut = 'signalee'}) async {
    final resp = await http.patch(_uri('/pertes/$id/'), headers: await _headers(), body: jsonEncode({
      'recolte': recolteId, 'type_perte': typePerte, 'quantite_perdue_kg': quantitePerdueKg, 'description': description, 'statut': statut,
    }));
    _decode(resp);
  }

  Future<void> supprimerPerte(int id) async {
    final resp = await http.delete(_uri('/pertes/$id/'), headers: await _headers());
    _decode(resp);
  }

  Future<Map<String, dynamic>> modifierProfil({required String firstName, required String lastName, required String telephone, required String region, required String nomExploitation}) async {
    final resp = await http.patch(_uri('/profil/'), headers: await _headers(), body: jsonEncode({
      'first_name': firstName, 'last_name': lastName, 'telephone': telephone, 'region': region, 'nom_exploitation': nomExploitation,
    }));
    return _decode(resp);
  }

  Future<List<dynamic>> stockages() async {
    final resp = await http.get(_uri('/stockages/'), headers: await _headers());
    final data = _decode(resp);
    return data is Map && data.containsKey('results') ? data['results'] : data;
  }

  Future<Map<String, dynamic>> infoIA() async {
    final resp = await http.get(_uri('/ia/info/'), headers: await _headers());
    return _decode(resp);
  }

}
