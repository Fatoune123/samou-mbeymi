import 'package:flutter/material.dart';
import 'theme.dart';
import 'services/api_service.dart';
import 'screens/connexion_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SamouMbeymiApp());
}

class SamouMbeymiApp extends StatelessWidget {
  const SamouMbeymiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Samou Mbeymi',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _verifier();
  }

  Future<void> _verifier() async {
    await Future.delayed(const Duration(milliseconds: 900));
    final token = await _api.token;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => token != null ? const DashboardScreen() : const ConnexionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          Positioned(
            right: -100,
            top: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: .10),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: .14)),
                  ),
                  child: const Icon(Icons.eco_rounded, size: 48, color: AppColors.accent),
                ),
                const SizedBox(height: 24),
                const Text(
                  'SAMOU MBEYMI',
                  style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                const Text('Piloter • Prévenir • Réduire les pertes', style: TextStyle(color: Color(0xFFBFD2C8))),
                const SizedBox(height: 34),
                const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
