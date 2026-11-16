import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:samou_mbeymi/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Simule le stockage local pour éviter une erreur de plugin dans les tests.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SAMOU MBEYMI affiche l’écran de connexion au démarrage',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SamouMbeymiApp());

    // Le SplashScreen attend 900 ms avant de vérifier le token local.
    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
