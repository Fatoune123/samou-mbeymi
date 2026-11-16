# SAMOU MBEYMI V18.3.2 — Modernisation du tableau de bord

## Modifications
- Refonte de `backend_django/pertes/templates/pertes/tableau_bord.html`.
- Navigation latérale compacte avec icônes SVG intégrées (sans dépendance externe ni emoji).
- Barre latérale sticky sur ordinateur et navigation horizontale sur mobile.
- Bannière avec photo agricole locale `static/img/hero-banner.jpg` et voile vert pour conserver le contraste.
- Hiérarchie visuelle et cartes KPI améliorées.
- Graphiques, causes de pertes, dernières récoltes et traçabilité conservés et alimentés par les données Django existantes.
- Cache CSS invalidé dans `base.html` (`v=13`).

## Données et périmètre
- `db.sqlite3`, `.env.example`, modèles, vues métier et migrations ne sont pas modifiés.
- Les valeurs des indicateurs restent liées au contexte Django existant ; aucune donnée de démonstration n'a été ajoutée.

## Vérification
- Archive ZIP testée (CRC).
- Vérification Django non exécutée dans l'environnement de préparation car Django n'y est pas installé. À vérifier sur le poste utilisateur avec `python manage.py check`.
