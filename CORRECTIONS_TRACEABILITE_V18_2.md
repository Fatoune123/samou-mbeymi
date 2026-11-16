# SAMOU MBEYMI V18.2 — Corrections de traçabilité

## Ce qui a été corrigé

1. Enregistrement explicite de `PertesConfig` dans `INSTALLED_APPS` afin de garantir le chargement des signaux Django.
2. La migration `0005_evenement_traceabilite` crée la table d'historique puis initialise l'historique des récoltes et pertes déjà présentes dans la base.
3. Toute nouvelle récolte crée automatiquement un événement « Création du lot ».
4. Toute nouvelle perte crée automatiquement un événement « Perte déclarée » sur le lot auquel elle est rattachée.
5. Les changements de lieu ou de quantité d'une récolte sont historisés.
6. Les modifications de cause, quantité ou statut d'une perte sont historisées.
7. La suppression d'un signalement de perte laisse une trace dans l'historique du lot.
8. Le texte d'aide de la page Récoltes est recentré sur les récoltes, pertes, tableaux de bord et rapports.

## Pourquoi l'historique affichait 0 événement

La base SQLite fournie contient déjà des récoltes et des pertes, mais la migration `0005_evenement_traceabilite` n'est pas marquée comme appliquée et la table `pertes_evenementtraceabilite` n'existe pas encore. Les signaux ne peuvent donc pas écrire dans cette table avant l'application de la migration.

La migration corrigée crée la table et ajoute un événement initial pour chaque récolte ainsi qu'un événement pour chaque perte existante. Elle ne supprime et ne modifie aucune récolte ni aucune perte.

## Installation sous Windows

1. Fermer le serveur Django avec `CTRL + C`.
2. Ouvrir le dossier `backend_django` dans l'Explorateur Windows.
3. Double-cliquer sur `APPLIQUER_CORRECTIONS_TRACEABILITE.bat`.
4. Attendre le message « SUCCES ».
5. Relancer le serveur avec `python manage.py runserver`.
6. Ouvrir une récolte déjà enregistrée, puis consulter « Historique de traçabilité ».

Le script crée une copie horodatée de `db.sqlite3` avant de lancer les migrations. Ne supprimez pas cette sauvegarde.

## Périmètre fonctionnel de la version actuelle

La version actuelle doit se concentrer sur :
- gestion des récoltes et des lots ;
- suivi des pertes liées à chaque récolte ;
- historique de traçabilité ;
- tableaux de bord et rapports.

L'analyse photographique par IA, l'assistant conversationnel agricole et la mise en relation producteurs–acheteurs ne font pas partie du périmètre fonctionnel à présenter pour cette version. Les anciens fichiers/modules sont conservés dans le projet pour éviter une suppression accidentelle, mais ne doivent pas être considérés comme des fonctionnalités validées du MVP.

## Limite de validation

Les fichiers ont été contrôlés statiquement dans cette archive. Le serveur n'a pas été exécuté dans l'environnement Windows de l'utilisateur. La validation finale doit être faite après application du script sur une copie de la base locale.


## Correctifs complémentaires V18.2.1

- Une perte déplacée d'une récolte vers une autre laisse désormais une trace sur le lot d'origine et sur le lot de destination.
- La suppression d'une récolte ayant un historique de traçabilité est protégée afin d'éviter l'effacement en cascade des événements. La page de suppression affiche un message explicatif.
- La migration `0006_proteger_historique_traceabilite` applique cette protection dans la base.
- Le script `APPLIQUER_CORRECTIONS_TRACEABILITE.bat` sauvegarde la base SQLite avant migration, affiche l'état des migrations, applique les migrations puis exécute `manage.py check`.

### Installation

Depuis le dossier `backend_django`, avec l'environnement Python du projet activé, double-cliquer sur `APPLIQUER_CORRECTIONS_TRACEABILITE.bat`, ou exécuter `python manage.py migrate` après avoir vérifié qu'une sauvegarde récente de `db.sqlite3` existe.

### Vérification

Les tests ajoutés couvrent le transfert d'une perte entre deux lots et la protection de l'historique lors d'une tentative de suppression d'une récolte.
