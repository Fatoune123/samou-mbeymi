import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'dashboard_screen.dart';

const List<Map<String, String>> regionsSenegal = [
  {'code': 'dakar', 'label': 'Dakar'},
  {'code': 'thies', 'label': 'Thiès'},
  {'code': 'diourbel', 'label': 'Diourbel'},
  {'code': 'fatick', 'label': 'Fatick'},
  {'code': 'kaolack', 'label': 'Kaolack'},
  {'code': 'kaffrine', 'label': 'Kaffrine'},
  {'code': 'kolda', 'label': 'Kolda'},
  {'code': 'louga', 'label': 'Louga'},
  {'code': 'matam', 'label': 'Matam'},
  {'code': 'saint_louis', 'label': 'Saint-Louis'},
  {'code': 'sedhiou', 'label': 'Sédhiou'},
  {'code': 'tambacounda', 'label': 'Tambacounda'},
  {'code': 'kedougou', 'label': 'Kédougou'},
  {'code': 'ziguinchor', 'label': 'Ziguinchor'},
];

class InscriptionScreen extends StatefulWidget {
  const InscriptionScreen({super.key});
  @override
  State<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends State<InscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _exploitation = TextEditingController();
  final _password = TextEditingController();
  String _region = 'thies';
  final _api = ApiService();
  bool _loading = false;
  String? _erreur;

  Future<void> _sInscrire() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _erreur = null; });
    try {
      await _api.inscription(
        username: _username.text.trim(),
        firstName: _prenom.text.trim(),
        lastName: _nom.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        telephone: _telephone.text.trim(),
        region: _region,
        nomExploitation: _exploitation.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: TextFormField(controller: _prenom,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                      validator: (v) => v!.isEmpty ? 'Requis' : null)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _nom,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      validator: (v) => v!.isEmpty ? 'Requis' : null)),
                ]),
                const SizedBox(height: 16),
                TextFormField(controller: _username,
                    decoration: const InputDecoration(labelText: "Nom d'utilisateur"),
                    validator: (v) => v!.isEmpty ? 'Requis' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? 'Requis' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _telephone,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _region,
                  decoration: const InputDecoration(labelText: 'Région'),
                  items: regionsSenegal
                      .map((r) => DropdownMenuItem(value: r['code'], child: Text(r['label']!)))
                      .toList(),
                  onChanged: (v) => setState(() => _region = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _exploitation,
                    decoration: const InputDecoration(labelText: "Nom de l'exploitation")),
                const SizedBox(height: 16),
                TextFormField(controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mot de passe (8 caractères min.)'),
                    validator: (v) => (v == null || v.length < 8) ? '8 caractères minimum' : null),
                if (_erreur != null) ...[
                  const SizedBox(height: 12),
                  Text(_erreur!, style: const TextStyle(color: AppColors.loss)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _sInscrire,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Créer mon compte'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
