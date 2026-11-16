# Version corrigée — Samou Mbeymi V10

## Modifications incluses
- Configuration locale SQLite par défaut pour éviter d'exiger PostgreSQL dès le premier lancement. PostgreSQL reste disponible via `DB_ENGINE=postgresql`.
- Suppression de l'autorisation CORS globale ; origines configurables par variables d'environnement.
- Clé Django de développement explicitement séparée de la configuration de production ; démarrage en production refusé si aucune clé secrète n'est définie.
- Paramètres de sécurité HTTP et cookies renforcés lorsque `DJANGO_DEBUG=False`.
- Profil absent traité de façon contrôlée dans plusieurs endpoints au lieu de provoquer une erreur serveur.
- Contrôle de la taille, du format, de l'intégrité et de la résolution des images envoyées au scanner.
- Validation des mots de passe à l'inscription via les validateurs Django.
- Le moteur de risque ne lance plus un entraînement automatique dans le cadre d'une requête utilisateur ; si le modèle est absent ou illisible, l'API l'indique explicitement.
- Tests ajoutés pour l'isolation des récoltes entre utilisateurs et le rejet de fichiers qui ne sont pas des images.
- Documentation Windows et script `demarrer_windows.bat` ajoutés.
- Archives et ignores préparés pour exclure les secrets, environnements virtuels et fichiers temporaires.

## Limites non résolues par cette version
- Les tests Django n'ont pas pu être exécutés dans l'environnement de préparation, car Django et Django REST Framework n'y étaient pas installés et l'accès réseau nécessaire à leur installation était indisponible. Le code Python a été vérifié par compilation syntaxique uniquement.
- L'application Flutter n'a pas été compilée ici : Flutter/Dart n'étaient pas disponibles dans l'environnement.
- Le modèle IA de risque reste expérimental tant qu'il n'a pas été évalué sur un jeu indépendant de données agricoles réelles.
- Les fonctions marketplace, paiements Wave/Orange Money, notifications push et messagerie temps réel ne sont pas déclarées terminées si elles ne sont pas présentes dans le code initial.
- Avant une mise en production, définir une clé secrète robuste, désactiver DEBUG, configurer les domaines, HTTPS, CORS/CSRF, sauvegardes et une base de données de production.
