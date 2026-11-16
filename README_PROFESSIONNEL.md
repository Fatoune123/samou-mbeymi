# SAMOU MBEYMI — version recentrée pour la soutenance

## Objectif
SAMOU MBEYMI est une application de suivi des récoltes et des pertes agricoles. Elle aide le producteur à enregistrer ses récoltes, documenter les pertes et consulter des indicateurs fiables pour mieux suivre son activité.

## Périmètre fonctionnel de la version actuelle
1. **Gestion des récoltes** : création, consultation, modification et suivi des lots.
2. **Suivi des pertes** : déclaration des pertes liées aux récoltes, avec contrôles de cohérence des quantités.
3. **Tableaux de bord** : indicateurs calculés à partir des récoltes et pertes réellement enregistrées.
4. **Rapports et statistiques** : synthèses et export des données utiles au suivi.

Le stockage et la traçabilité sont conservés comme informations complémentaires rattachées aux lots de récolte.

## Intelligence artificielle : perspective d'évolution
L'IA n'est pas une fonctionnalité opérationnelle revendiquée dans cette version recentrée. Une évolution ultérieure pourra exploiter les historiques réels et suffisamment documentés de récoltes et de pertes pour :
- repérer des tendances et périodes de pertes importantes ;
- aider à identifier les lots nécessitant une surveillance ;
- produire des estimations de risque à évaluer et valider avec des professionnels agricoles.

Aucun résultat d'IA ne doit être présenté comme fiable sans données représentatives, protocole d'évaluation, tests et validation métier. Les modules et routes historiques liés à l'IA ou à la marketplace sont conservés dans le dépôt pour préserver les dépendances et les données, mais ils ne font pas partie du périmètre de démonstration de cette version.

## Architecture évolutive proposée
- **Présentation** : application Flutter et interface web Django.
- **API métier** : Django REST Framework, responsable de l'authentification, des règles de gestion et de la validation des données.
- **Données** : modèles relationnels pour les producteurs, cultures, récoltes, pertes, stockage et événements de traçabilité.
- **Analytique actuelle** : agrégations déterministes calculées à partir des données enregistrées.
- **Extension IA future** : module isolé, appelé via un service dédié, sans accès direct depuis l'interface aux modèles ou aux bibliothèques ML. Les prédictions futures devront être versionnées, explicables, datées et accompagnées de limites d'utilisation.

## Précautions de maintenance
- Ne pas supprimer `db.sqlite3`, `.env`, `media/` ou les migrations existantes.
- Sauvegarder la base avant toute migration ou modification de schéma.
- Ne pas lancer de commande de réinitialisation des données sur une base existante.
- Tester le backend et Flutter dans l'environnement local avant la soutenance.

## Dossiers
- `backend_django/` : backend Django et API REST.
- `app_flutter/` : application mobile Flutter.
