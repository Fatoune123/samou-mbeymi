import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'inscription_screen.dart';
import 'dashboard_screen.dart';

class ConnexionScreen extends StatefulWidget {
  const ConnexionScreen({super.key});

  @override
  State<ConnexionScreen> createState() => _ConnexionScreenState();
}

class _ConnexionScreenState extends State<ConnexionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _api = ApiService();
  bool _loading = false;
  bool _showPassword = false;
  String? _erreur;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _erreur = null;
    });
    try {
      await _api.connexion(username: _username.text.trim(), password: _password.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) setState(() => _erreur = 'Identifiants incorrects. Vérifiez vos informations et réessayez.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(backgroundColor: Color(0x22FFFFFF), child: Icon(Icons.eco_rounded, color: AppColors.accent)),
                        SizedBox(width: 12),
                        Text('SAMOU MBEYMI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ]),
                      SizedBox(height: 32),
                      Text('Pilotez vos récoltes\navec plus de sérénité.', style: TextStyle(color: Colors.white, fontSize: 27, height: 1.1, fontWeight: FontWeight.w900)),
                      SizedBox(height: 10),
                      Text('Suivez les volumes, détectez les pertes et utilisez l’IA pour mieux décider.', style: TextStyle(color: Color(0xFFD6E7DE), height: 1.45)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          const Text('Connexion', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 5),
                          const Text('Accédez à votre espace agricole.', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _username,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded), labelText: "Nom d'utilisateur"),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Votre nom d’utilisateur est requis.' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: !_showPassword,
                            onFieldSubmitted: (_) => _seConnecter(),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              labelText: 'Mot de passe',
                              suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded), onPressed: () => setState(() => _showPassword = !_showPassword)),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Votre mot de passe est requis.' : null,
                          ),
                          if (_erreur != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.lossSoft, borderRadius: BorderRadius.circular(14)),
                              child: Row(children: [const Icon(Icons.error_outline_rounded, color: AppColors.loss, size: 19), const SizedBox(width: 9), Expanded(child: Text(_erreur!, style: const TextStyle(color: AppColors.loss, fontSize: 12, fontWeight: FontWeight.w600)))]),
                            ),
                          ],
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _loading ? null : _seConnecter,
                            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_forward_rounded),
                            label: Text(_loading ? 'Connexion…' : 'Se connecter'),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InscriptionScreen())),
                            child: const Text('Créer un compte'),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.verified_user_outlined, size: 15, color: AppColors.inkSoft), SizedBox(width: 6), Text('Connexion sécurisée', style: TextStyle(color: AppColors.inkSoft, fontSize: 11))]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
