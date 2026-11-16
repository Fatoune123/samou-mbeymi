# SAMOU MBEY — version corrigée du projet existant

Cette archive conserve le site Django et l'application Flutter fournis, et ajoute des correctifs de configuration, de sécurité et de validation. Les services externes et le modèle IA ne sont pas réputés opérationnels sans configuration et vérification.

## Prérequis Windows
- Python 3.10 à 3.13 recommandé ;
- Flutter/Dart uniquement pour exécuter l'application mobile ;
- connexion Internet pour installer les dépendances.

## Démarrage backend (recommandé)
1. Décompressez le dossier.
2. Ouvrez `backend_django`.
3. Exécutez `demarrer_windows.bat`, ou lancez manuellement :

```powershell
py -3 -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
Copy-Item .env.example .env
python manage.py check
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

Le fichier `.env.example` utilise SQLite pour faciliter le premier démarrage local sans serveur PostgreSQL. Pour PostgreSQL, définissez `DB_ENGINE=postgresql` et configurez les variables `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST` et `DB_PORT`.

Pages utiles : `http://127.0.0.1:8000/`, `http://127.0.0.1:8000/admin/`, `http://127.0.0.1:8000/api/health/`.

## Application Flutter
Depuis le dossier `app_flutter` :

```powershell
flutter pub get
flutter analyze
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

Pour Chrome, utiliser `--dart-define=API_BASE_URL=http://127.0.0.1:8000/api`. Pour un téléphone physique, utiliser l'adresse IP locale du PC et s'assurer que les deux appareils sont sur le même réseau. L'URL doit être adaptée à la cible utilisée.

## IA : limites et entraînement
- Le scanner photo est une analyse colorimétrique indicative, pas un diagnostic sanitaire.
- Le modèle de risque existant peut être entraîné avec des données synthétiques ; ses métriques ne démontrent pas sa précision dans des conditions agricoles réelles.
- Les requêtes ordinaires ne déclenchent plus automatiquement un entraînement coûteux. Pour entraîner explicitement le modèle, après installation et vérification des données : `python manage.py entrainer_modele_ia`.
- Un modèle entraîné sur données synthétiques doit être étiqueté comme expérimental et ne doit pas être présenté comme validé en terrain.

## Sécurité
- Ne partagez jamais `.env`. Si une clé ou un mot de passe réel a été inclus dans une archive partagée, faites-le tourner.
- En production, définir `DJANGO_DEBUG=False`, une `DJANGO_SECRET_KEY` forte, `DJANGO_ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, `CSRF_TRUSTED_ORIGINS`, HTTPS et une base PostgreSQL gérée.
- La configuration de développement par défaut n'est pas une configuration de production.

## Vérifications
Depuis `backend_django` :

```powershell
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py test
```

L'application n'est considérée comme validée qu'après exécution de ces commandes dans votre environnement, vérification des parcours Flutter et test de déploiement.


## Correction de l'erreur « No Agriculteur matches the given query »

Après extraction et activation de l'environnement, exécuter une fois :

```bat
python manage.py migrate
python manage.py reparer_profils_agriculteurs
```

Cette commande crée uniquement les profils manquants et conserve les profils existants. Les vues web créent également un profil par défaut si un compte connecté n'en possède pas.
