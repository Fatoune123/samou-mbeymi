# Correctifs V9 : Samou Mbeymi

## À faire sur votre machine (dans backend_django)

```
python -m pip install -r requirements.txt --default-timeout=300 --retries 10
python manage.py initialiser_stockages
python manage.py runserver
```

Aucune migration n'est nécessaire (les modèles n'ont pas changé).
`initialiser_stockages` crée un point de stockage de démonstration par région. Remplacez-les par les vrais points via /admin/.

## Ce qui a été corrigé

| Problème constaté | Cause trouvée | Correction |
|---|---|---|
| Prédiction : `No module named 'joblib'` | joblib/scikit-learn absents de votre Python | `requirements.txt` complété (python-dotenv, psycopg2-binary ajoutés) |
| Carte : « Access blocked » 403 | Django envoie `Referrer-Policy: same-origin` : OpenStreetMap ne reçoit pas de Referer et refuse les tuiles | `SECURE_REFERRER_POLICY` dans `settings.py` + `referrerPolicy` sur la couche Leaflet |
| Graphiques du rapport et du tableau de bord vides, barres à 100 % | En français, Django écrit `66,4%` : le CSS refuse la virgule | nouveau filtre `css_num` (`pertes/templatetags/css_utils.py`) |
| Rapport : mois vides, causes à 0 kg | le template lisait `c.total` et `p.label`, la vue fournissait `total_kg` et `mois` | clés alignées, `pct` calculé |
| Rapport : 0,0 kg alors que la récolte fait 0,02 kg | arrondi à 1 décimale | arrondi à 2 décimales |
| Mois du graphique en anglais (Nov, Dec, Jan) | `strftime('%b')` | libellés français |
| Export CSV : caractères parasites dès la 2e ligne | le BOM UTF-8 était écrit à chaque ligne | BOM écrit une seule fois |
| Page Stockage vide (Fatick) | la table Stockage ne contenait que 3 régions | commande `initialiser_stockages` (14 régions) |
| Formulaire récolte : champ quantité sans garde-fou | pas de `min`/`step` sur le champ | `min=0.01`, `step=0.01`, exemple en placeholder |
| Formulaire récolte : date vide à la modification | format de date localisé incompatible avec `type=date` | format `%Y-%m-%d` |
| Lieu de stockage en texte libre sans aide | | suggestions (datalist) : stockages de la région + lieux déjà utilisés |
| Probabilités affichées « Eleve » sans accent, barres fausses | clés brutes et virgule décimale | libellé « Élevé » et filtre `css_pct` |
| Modèle .pkl illisible si autre version de scikit-learn | | ré-entraînement automatique si le chargement échoue |
| `settings.py` plante si python-dotenv absent | import obligatoire | import optionnel ; `DB_ENGINE=sqlite` pour tester sans PostgreSQL |

## Logo et bannière
- Logo : barre de navigation (emblème), pied de page, connexion, inscription, favicon.
- Bannière : page d'accueil (`static/img/hero-banner.jpg`).
- Fichiers : `static/img/logo-samou-mbeymi.png`, `logo-emblem.png`, `favicon.png`, `hero-banner.jpg`.

## Scanner IA (mise à jour)
- Le fond de l'image (blanc, table, sol) est ignoré : le taux est calculé sur le produit uniquement.
- Deux signes distingués : zones très sombres et taches brunes ; les feuilles vertes ne sont jamais comptées.
- Après une analyse « à surveiller » ou « détérioration probable », le bouton « Signaler cette perte » ouvre le formulaire de perte pré-rempli (récolte et quantité estimée).
- Limites : analyse par couleurs seulement ; ne reconnaît ni la culture ni la moisissure claire (blanche ou grise).
