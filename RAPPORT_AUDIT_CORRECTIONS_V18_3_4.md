# SAMOU MBEYMI — Rapport d'audit et corrections V18.3.4

## Périmètre retenu
Gestion des récoltes, traçabilité des lots, suivi des pertes, stockage, tableaux de bord et rapports. Les fonctionnalités IA, assistant conversationnel et marketplace ne sont pas considérées comme faisant partie du périmètre fonctionnel validé pour cette version. Elles n'ont pas été supprimées du code afin de ne pas casser les dépendances ni les données historiques.

## Corrections appliquées
- Validation du formulaire de modification d'une récolte : la quantité ne peut plus être abaissée sous le cumul des pertes déjà enregistrées.
- Validation des pertes avec calcul décimal en base de données : le cumul des pertes d'un lot ne peut pas dépasser sa quantité récoltée.
- Application des mêmes contrôles au sérialiseur API pour les pertes et les récoltes.
- Traçabilité des changements de culture et de date de récolte.
- Traçabilité des changements de description d'une perte.
- Remplacement de deux recommandations du tableau de bord faisant référence à l'IA par des conseils de suivi opérationnel conformes au périmètre.
- Ajout de tests automatisés couvrant les validations et la traçabilité.

## Contrôle de la base fournie
- `PRAGMA integrity_check` : `ok`.
- Données observées dans la base fournie : 2 utilisateurs, 2 profils agriculteurs, 8 cultures, 6 récoltes, 5 pertes.
- La base incluse dans l'archive n'a pas été modifiée par les opérations de correction.
- Les migrations `0005_evenement_traceabilite` et `0006_proteger_historique_traceabilite` ne sont pas appliquées dans cette base. Elles doivent être exécutées après sauvegarde locale et vérification, sur l'installation de l'utilisateur.

## Limites de validation
- Compilation syntaxique Python (`compileall`) réussie.
- Les tests Django, `manage.py check`, les migrations et les tests Flutter n'ont pas pu être exécutés ici : Django et Flutter ne sont pas installés dans l'environnement d'audit.
- Le ZIP est donc une version corrigée du code avec validation syntaxique, et non une certification d'exécution complète.

## Procédure Windows conseillée
Dans `backend_django`, arrêter le serveur, puis :

```bat
copy db.sqlite3 db_backup_avant_v18_3_4.sqlite3
python -m venv venv
venv\Scripts\activate
python -m pip install -r requirements.txt
python manage.py showmigrations pertes
python manage.py migrate --plan
python manage.py migrate
python manage.py check
python manage.py test pertes
python manage.py runserver
```

Ne pas supprimer `db.sqlite3`, le dossier `media`, les migrations, ni le fichier `.env` existant. En cas d'erreur pendant une migration, arrêter et conserver la sauvegarde avant toute autre action.
