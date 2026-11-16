# SAMOU MBEYMI — V17 (itération de développement)

## Fonction livrée dans cette itération : traçabilité des récoltes

### Backend Django
- Nouveau modèle `EvenementTraceabilite`.
- Nouvelle migration `0005_evenement_traceabilite.py`.
- API authentifiée : `/api/traceabilite/evenements/`.
- Filtrage par récolte : `/api/traceabilite/evenements/?recolte=<id>`.
- Un événement de création est automatiquement enregistré à la création d'une récolte.
- Un événement est automatiquement enregistré lors d'un changement de lieu ou de quantité.
- Une déclaration de perte ajoute un événement dans l'historique.
- Les utilisateurs ne peuvent consulter ou ajouter des événements que sur leurs propres récoltes.

### Application Flutter
- Ajout des méthodes API de lecture et de création d'événements.
- Ajout de l'accès « Historique / traçabilité » dans le menu de chaque récolte.
- Écran d'historique avec ajout d'événements : stockage, déplacement, contrôle, mise à jour et autre.

### Tests ajoutés
- Création automatique de l'événement initial.
- Traçage d'une perte.
- Isolation des événements par utilisateur.
- Refus de création d'événement sur une récolte appartenant à un autre compte.

## Installation prudente
1. Faire une copie de sauvegarde de `backend_django/db.sqlite3`.
2. Conserver le `.env` local et ne pas le partager.
3. Activer l'environnement virtuel du backend.
4. Exécuter `python manage.py check`.
5. Exécuter `python manage.py migrate`.
6. Exécuter `python manage.py test pertes`.
7. Démarrer Django avec `python manage.py runserver`.
8. Dans `app_flutter`, exécuter `flutter pub get`, `flutter analyze`, puis lancer sur un appareil de test.

## Limites de validation
Le code Python a été contrôlé syntaxiquement. Cet environnement ne contient ni Django installé ni Flutter/Dart : la suite de tests Django, l'analyse Dart et la compilation de l'application doivent encore être exécutées sur la machine de développement. Cette itération n'est donc pas déclarée prête pour la production.
