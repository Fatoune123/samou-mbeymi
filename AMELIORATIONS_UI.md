# Samou Mbeymi — amélioration UI/UX

## Ce qui a été modernisé
- Nouvelle identité visuelle plus premium : vert profond, ivoire, accent doré.
- Écran de connexion entièrement repensé avec carte d'accueil, validation et affichage du mot de passe.
- Splash screen plus professionnel avec identité de marque.
- Tableau de bord mobile modernisé : hero card, KPI, indice de maîtrise des pertes, causes de pertes et actions rapides.
- Navigation Material 3 harmonisée.
- Meilleure gestion des états de chargement et d'erreur.
- Mise en page responsive pour les écrans plus larges.

## Lancer l'application

### Backend Django
```bash
cd backend_django
python manage.py migrate
python manage.py runserver
```

### Flutter
```bash
cd app_flutter
flutter pub get
flutter run
```

Le projet utilise déjà Django pour l'API et Flutter pour l'application mobile.

## Vérification
Le SDK Flutter n'était pas installé dans l'environnement de travail utilisé pour cette amélioration. Le code a donc été relu et structuré pour rester compatible avec la configuration Flutter déjà présente, mais `flutter analyze` et `flutter test` doivent être exécutés sur une machine disposant du SDK Flutter.
