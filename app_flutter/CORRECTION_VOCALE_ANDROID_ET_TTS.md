# Configuration Android pour l'assistant vocal

Ce projet ne contient pas les fichiers de plateforme Android. Le script `PREPARER_FLUTTER_WINDOWS.bat` génère la plateforme si nécessaire, puis applique automatiquement les déclarations Android requises pour le microphone et la découverte du service de reconnaissance vocale.

Le code Flutter :
- tente `fr_FR` si Android ne publie pas sa liste de langues de reconnaissance ;
- recherche une variante française réellement installée pour la synthèse vocale (par exemple `fr-FR`, `fr_FR` ou `fr-CA`) ;
- ne remplace pas silencieusement le wolof, le pulaar ou les autres langues nationales par le français ;
- conserve les réponses écrites si aucune voix compatible n'est disponible.

## Étapes sur Windows

1. Extraire le ZIP.
2. Ouvrir le dossier `app_flutter`.
3. Exécuter `PREPARER_FLUTTER_WINDOWS.bat`.
4. Sur le téléphone, autoriser le microphone et installer/activer un moteur de reconnaissance et de synthèse vocale, puis télécharger une voix française.
5. Recompiler avec `flutter run`.

Commandes manuelles équivalentes :

```bash
flutter pub get
flutter analyze
flutter run
```

La disponibilité réelle de la reconnaissance et de la voix dépend du moteur vocal installé sur le téléphone. Le code seul ne peut pas installer une voix Android. La validation finale doit être faite sur l'appareil cible.

## Protection des données

Aucune base Django/SQLite, aucun compte, mot de passe, fichier `.env` ou historique de migration n'est modifié par ces corrections Flutter.
