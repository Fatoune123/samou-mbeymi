# Intégration web des modules SAMOU MBEY

Ajout du menu web et de quatre pages protégées : `/conservation/`, `/phytosanitaire/`, `/engrais/`, `/marketplace/`. Réutilisation des modèles existants sans modification de schéma ni migration.

Limites : la page Engrais fournit des repères généraux, sans inventer de fournisseurs ni de prix. Marketplace affiche les offres disponibles en lecture seule ; le flux de commande doit être testé et complété séparément. Le conseil phytosanitaire est préventif, pas un diagnostic.

Fichiers modifiés : `pertes/views.py`, `pertes/urls.py`, `pertes/templates/pertes/base.html` et quatre nouveaux templates. Base SQLite, `.env`, `pertes/admin.py` et migrations inchangés.
