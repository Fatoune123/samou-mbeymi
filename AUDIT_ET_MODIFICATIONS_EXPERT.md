# Audit technique — SAMOU MBEY

## Modifications de cette version
- Ajout de l’onglet Marketplace dans l’écran Flutter `ModulesAgricolesScreen`.
- Connexion de cet onglet aux routes API existantes : consultation des offres, publication d’une offre à partir d’une récolte existante, demande de commande et consultation des commandes du compte connecté.
- Conservation des trois onglets existants : conservation, phytosanitaire et engrais.
- Aucune modification du modèle de données, des migrations, de `db.sqlite3`, du fichier `.env` ou de `pertes/admin.py`.

## Limites connues
- Le répertoire de fournisseurs reste local à l’appareil : il n’est pas partagé entre utilisateurs et n’est pas stocké côté serveur. Il n’a pas été transformé en registre central car cela nécessiterait un choix métier et potentiellement une évolution du schéma.
- Les conseils phytosanitaires ne constituent pas un diagnostic médical/agronomique confirmé. Les paiements ne sont pas intégrés.
- L’environnement de cette session ne dispose pas de Flutter/Dart ni des dépendances Django installées : la compilation Flutter et `manage.py check` n’ont donc pas pu être exécutés.

## Vérifications effectuées
- Vérification de la syntaxe Python par AST pour les principaux fichiers Django.
- Comparaison octet par octet de la base SQLite, du `.env`, de `pertes/admin.py` et des migrations avec l’archive fournie : inchangés.
- Intégrité de l’archive ZIP vérifiée.

## Démarrage conseillé
Tester d’abord dans un dossier séparé. Dans `backend_django`, activer l’environnement virtuel existant, exécuter `python manage.py check`, puis `python manage.py runserver`. Dans `app_flutter`, exécuter `flutter pub get`, puis `flutter analyze` et lancer l’application sur un appareil de test.


## Améliorations supplémentaires de cette révision
- Pages web Conservation, Phytosanitaire, Engrais et Marketplace réorganisées en mises en page responsives avec actions explicites et états vides.
- Conservation : indicateurs dérivés des récoltes et pertes déjà enregistrées, âge du lot et niveau de surveillance calculé à partir du pourcentage de perte déclaré. Aucun chiffre de durée de conservation n'est inventé.
- Phytosanitaire web : accès direct au scanner photo existant et au formulaire de signalement de perte.
- Marketplace web : recherche/filtre, publication d'offre à partir d'une récolte appartenant au compte connecté, demande de commande, consultation des commandes et transitions de statut contrôlées.
- API marketplace : vérification du stock côté serveur, contrôle de propriété et transitions de commande autorisées. Le champ `est_producteur` est calculé pour l'interface Flutter sans ajout de champ en base.
- Flutter : accès au scanner photo depuis l'onglet phytosanitaire, recherche/filtre des offres et actions de suivi des commandes selon le rôle.
- Aucune migration ou modification de modèle n'a été ajoutée. Le répertoire fournisseurs Flutter demeure local à l'appareil, car le partage entre comptes nécessiterait un stockage serveur et une décision d'architecture.

## Limites de validation
- Les fichiers Python ont été analysés syntaxiquement et l'intégrité ZIP vérifiée.
- Django et Flutter/Dart ne sont pas installés dans l'environnement de travail ; `manage.py check`, tests HTTP, `flutter analyze` et compilation n'ont pas pu être exécutés ici. Ces vérifications doivent être faites localement avant de remplacer la version utilisée.
