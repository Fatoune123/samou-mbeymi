# Intégration de l'assistant agricole — V18

## Changements
- Django Web : ajout d'un bouton flottant « Assistant agricole » disponible sur les pages qui héritent de `pertes/base.html`.
- Django Web : saisie ou reconnaissance vocale via Web Speech API, envoi vers `POST /api/ia/conseiller/`, affichage et lecture de la réponse.
- Flutter : l'écran `AssistantVocalScreen` envoie les questions agricoles à l'API Gemini via `ApiService.conseillerAgricole`.
- Flutter : réponse Gemini affichée puis lue avec `flutter_tts`; commandes de navigation locales conservées.
- Flutter : bouton d'accès à l'assistant agricole ajouté dans « Outils intelligents » du tableau de bord.
- Ajout d'une saisie textuelle de secours dans l'écran vocal.
- Choix de langue de réponse : français, wolof, pulaar, sérère, joola, mandinka, soninké et anglais.

## Architecture conservée
- Le moteur conversationnel reste Google Gemini, appelé par Django.
- L'endpoint existant `/api/ia/conseiller/` est réutilisé.
- Aucun nouveau modèle de données, aucune migration et aucune modification de base de données.
- Aucun changement de clé API ou de fichier `.env`.

## Limites à connaître
- La reconnaissance et la synthèse vocales dans le navigateur dépendent de la prise en charge de Web Speech par le navigateur.
- Sur Flutter, la reconnaissance et la synthèse dépendent des moteurs et langues installés sur le téléphone.
- Les huit langues sont transmises comme langues de réponse à Gemini, mais cela ne garantit pas une reconnaissance ou une prononciation vocale disponible pour chacune.
- Le test réel Gemini nécessite une clé `GEMINI_API_KEY` valide dans l'environnement local et une connexion Internet.
- L'environnement de préparation ne disposait pas d'un exécutable Flutter/Dart utilisable : `flutter analyze` et `flutter build` n'ont donc pas été exécutés.
- La reconnaissance vocale doit être testée sur un navigateur compatible et sur un vrai téléphone Android avec permission microphone.

## Démarrage et test
1. Garder le fichier `.env` et `db.sqlite3` de votre installation existante.
2. Démarrer Django avec `python manage.py runserver`.
3. Sur le site web, cliquer sur le bouton flottant « Assistant agricole », autoriser le microphone et poser une question.
4. Dans Flutter, exécuter `flutter pub get`, puis `flutter analyze`, puis `flutter run`.
5. Dans le tableau de bord Flutter, ouvrir « Assistant agricole — parler à Gemini ».
6. Tester d'abord en français avec une question simple, par exemple : « Comment conserver mes tomates après la récolte ? »

Ne pas lancer de migration pour cette intégration vocale.
