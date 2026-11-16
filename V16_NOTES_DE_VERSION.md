# SAMOU MBEYMI — Notes de version V16

## Objectif
Recentrer l'application sur la gestion, la traçabilité et le suivi des récoltes et des pertes post-récolte.

## Modifications de cette livraison
- Navigation Flutter recentrée : Accueil, Récoltes, Pertes, Pilotage, Profil.
- Retrait de la navigation principale vers le scanner photo, la carte/marché et l'assistant vocal.
- Retrait du menu donnant accès aux modules conversationnels et agricoles avancés.
- Actions rapides du tableau de bord recentrées sur Pilotage, Récolte et Perte.
- Écran Pilotage clarifié : synthèse de production et points de stockage ; mention Machine Learning retirée de cet écran.
- Code source des modules reportés conservé dans le dépôt pour une version ultérieure.

## Limites connues à traiter dans les prochaines étapes
- La traçabilité événementielle complète n'est pas encore implémentée : le modèle actuel `Recolte` représente un enregistrement de récolte, mais il n'existe pas encore de journal structuré des mouvements/événements d'un lot.
- L'export CSV existe côté Django ; son parcours de téléchargement depuis Flutter doit être vérifié/complété.
- Les tests d'exécution Flutter et Django doivent être effectués dans l'environnement de développement du projet. Cette livraison n'est pas certifiée par une exécution locale Flutter dans l'environnement de génération.
- Les règles métier de modification/suppression d'une récolte liée à des pertes doivent être testées avant mise en production.

## Sécurité et données
- Aucune migration de base de données n'a été effectuée.
- Aucun modèle métier ni enregistrement SQLite n'a été supprimé ou modifié.
- Le fichier `.env` local est exclu de cette archive de partage. Utiliser le `.env.example` et reporter localement les valeurs secrètes depuis une sauvegarde sécurisée.
- La base `db.sqlite3` est conservée dans cette archive ; faire une copie de sauvegarde avant toute migration ou test destructif.
