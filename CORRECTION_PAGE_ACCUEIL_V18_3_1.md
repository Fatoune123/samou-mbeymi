# Correction V18.3.1 — robustesse de la page d'accueil

- La vue `accueil` initialise désormais les statistiques à zéro.
- Si les tables statistiques ne sont pas encore accessibles (OperationalError/ProgrammingError),
  la page d'accueil continue à s'afficher et l'erreur détaillée est journalisée dans le terminal.
- Aucune migration, donnée SQLite, configuration `.env` ou fonctionnalité métier n'a été modifiée.

Important : cette correction évite qu'une indisponibilité des tables statistiques bloque l'accueil.
Elle ne remplace pas l'application des migrations `0005` et `0006` et ne constitue pas un test
d'exécution complet dans un environnement Django installé.
