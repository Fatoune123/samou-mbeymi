# SAMOU MBEYMI — Corrections de l'application

## Corrections de cette version
- Le scanner Flutter utilise désormais le plugin `camera` pour afficher un aperçu caméra intégré et capturer une photo, au lieu d'ouvrir uniquement l'application caméra native via `image_picker`.
- La galerie reste disponible via `image_picker`.
- Le résultat de la capture est affiché avant l'envoi au scanner Django.
- Le bouton de capture est protégé contre les doubles appuis pendant la prise de vue.
- Le backend limite la taille des réponses Gemini et journalise la durée de génération pour faciliter le diagnostic de la lenteur.
- Le champ Decimal du formulaire Django utilise bien `Decimal`.

## Configuration à conserver depuis votre installation originale
Cette archive source ne contenait pas `app_flutter/android/` ni `backend_django/db.sqlite3`.
1. Copiez votre dossier `android` original dans `app_flutter/` du projet extrait. Ne remplacez pas les fichiers Android de votre projet original.
2. Dans `app_flutter/android/app/src/main/AndroidManifest.xml`, vérifiez que la permission suivante existe sous `<manifest>` et avant `<application>` :
   `<uses-permission android:name="android.permission.CAMERA" />`
3. Conservez votre `db.sqlite3` original séparément et remettez-le dans `backend_django/` uniquement si c'est bien le chemin utilisé par votre `settings.py`.
4. Ne lancez pas `python manage.py migrate` pour cette mise à jour.
5. Dans `app_flutter/`, exécutez `flutter pub get` pour résoudre la nouvelle dépendance `camera`.

## Limites à ne pas masquer
- Le code Flutter doit être compilé et testé sur un téléphone Android réel après restauration du dossier `android`.
- La reconnaissance et la synthèse vocales fiables en wolof, pulaar, sérère, joola, mandinka et soninké nécessitent des moteurs audio réellement compatibles et une validation par des locuteurs natifs. Les codes de langue du système ne constituent pas une preuve de prise en charge.
- Le modèle de vision CLIP est chargé au premier usage et peut prendre du temps. Le scanner renvoie un indicateur visuel indicatif, pas un diagnostic agronomique certifié.
