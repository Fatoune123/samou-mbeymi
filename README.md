# Samou Mbeymi — Application intelligente pour réduire les pertes agricoles

Projet de soutenance — Phase 5 (Interface & base de données) et Phase 6 (Module IA)
du planning Mai–Août 2026.

## Architecture

```
backend_django/            → Backend Django (site web + API REST + module IA)
app_flutter/    → Application mobile Flutter (consomme l'API REST)
```

Le backend Django sert **deux choses en même temps** :
1. Un site web complet (inscription, tableau de bord, récoltes, pertes) — utilisable directement au navigateur.
2. Une API REST (`/api/...`) sécurisée par token, consommée par l'application Flutter.

Le module IA (scikit-learn) est partagé par les deux : il prédit le risque de
perte d'une récolte et analyse une photo pour repérer des signes visuels de
détérioration.

---

## 1. Lancer le backend Django

```bash
cd backend_django
python3 -m venv venv && source venv/bin/activate      # optionnel mais recommandé
pip install -r requirements.txt

python3 manage.py migrate
python3 manage.py entrainer_modele_ia                  # entraîne le modèle IA (Phase 6)
python3 manage.py createsuperuser                       # optionnel : accès à /admin/

python3 manage.py runserver 0.0.0.0:8000
```

- Site web : http://127.0.0.1:8000/
- Admin Django : http://127.0.0.1:8000/admin/
- API REST : http://127.0.0.1:8000/api/

Quelques cultures de base (Mil, Maïs, Riz, Tomate...) sont à créer via l'admin
ou le shell Django (`Culture.objects.create(nom="Tomate")`) si votre base est vierge.

### Endpoints API principaux

| Méthode | URL | Description |
|---|---|---|
| POST | `/api/inscription/` | Créer un compte agriculteur → renvoie un token |
| POST | `/api/connexion/` | Se connecter → renvoie un token |
| GET | `/api/cultures/` | Liste des cultures |
| GET/POST | `/api/recoltes/` | Lister / ajouter une récolte |
| GET/POST | `/api/pertes/` | Lister / signaler une perte |
| GET | `/api/tableau-de-bord/` | Statistiques agrégées |
| POST | `/api/ia/predire-risque/` | Prédiction IA du risque de perte |
| POST | `/api/ia/scanner-photo/` | Analyse visuelle d'une photo (multipart) |

Toutes les routes (sauf inscription/connexion) nécessitent l'en-tête :
`Authorization: Token <votre_token>`

---

## 2. Lancer l'application Flutter

Le Flutter SDK n'était pas disponible dans l'environnement où ce projet a été
généré — le code est donc **écrit et prêt**, mais n'a pas pu être compilé ici.
Sur votre machine (avec Flutter installé) :

```bash
cd app_flutter
flutter pub get
flutter run
```

### Adresse du serveur Django

Dans `lib/services/api_service.dart`, la classe `ApiConfig` définit l'URL du
backend :
- **Émulateur Android** : `http://10.0.2.2:8000/api` (déjà configuré par défaut)
- **Simulateur iOS / bureau** : `http://127.0.0.1:8000/api` (déjà configuré par défaut)
- **Téléphone physique** : remplacez par l'IP locale de votre ordinateur
  (ex. `http://192.168.1.10:8000/api`), téléphone et ordinateur sur le même Wi-Fi.

### Fonctionnalités de l'app Flutter

- Inscription / connexion (token stocké localement)
- Tableau de bord (KPIs, répartition des pertes)
- Ajout de récolte **+ prédiction IA du risque de perte** avant enregistrement
- Signalement de perte
- **Scanner IA** : photo (caméra ou galerie) → analyse visuelle de l'état de la récolte

---

## 3. Le module IA (Phase 6)

- `pertes/ia/dataset.py` : génère un jeu de données synthétique basé sur des
  règles agronomiques documentées (sensibilité des cultures, humidité par
  région, saison des pluies au Sénégal, qualité du stockage).
- `pertes/ia/engine.py` : entraîne un `RandomForestClassifier` (scikit-learn)
  sur ce jeu de données et expose `predire_risque()` et `analyser_photo()`.
- Commande `python3 manage.py entrainer_modele_ia` pour ré-entraîner le modèle.

**Pour la soutenance** : ce modèle est un vrai modèle de machine learning
(entraînement, séparation train/test, score de précision affiché), mais les
données d'entraînement sont synthétiques car l'application est encore jeune.
Une fois assez de vraies récoltes/pertes enregistrées par les agriculteurs,
il suffit d'adapter `dataset.py` pour utiliser les données réelles de la base
au lieu des données simulées — l'architecture du modèle reste identique.

Le scan photo est une **analyse colorimétrique simplifiée** (comptage de
pixels ternis/sombres), pas un réseau de neurones — un bon point de départ
explicable en soutenance, améliorable plus tard avec un vrai CNN entraîné sur
des photos réelles labellisées.
