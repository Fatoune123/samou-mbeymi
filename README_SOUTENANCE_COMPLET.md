# Samou Mbeymi — version complète de soutenance

## Fonctionnalités
- Authentification web et mobile
- Profil agriculteur et région
- CRUD récoltes
- CRUD pertes avec validation métier
- Tableau de bord KPI
- Évolution de production/pertes sur 12 mois
- Analyse des causes de pertes
- Points de stockage disponibles
- Scanner photo indicatif
- Machine Learning Random Forest pour le risque post-récolte
- Entraînement avec données synthétiques + données réelles disponibles
- Métriques Accuracy / Precision / Recall / F1
- Importance des variables
- Rapports
- Export CSV compatible Excel français (`;`, UTF-8 BOM, décimales `,`)
- API REST pour Flutter
- Application Flutter avec dashboard, récoltes, pertes, scanner, profil et espace outils
- Données de démonstration associées à un compte existant

## Installation backend
```powershell
cd backend_django
py -m venv .venv
.\.venv\Scripts\Activate.ps1
py -m pip install --upgrade pip
py -m pip install -r requirements.txt
py manage.py migrate
py manage.py check
```

### Préparer les données sur le compte existant
Ne lancez pas `initialiser_demo` si vous avez déjà un compte.

```powershell
py manage.py initialiser_mes_donnees --username VOTRE_UTILISATEUR
```

Pour remplacer uniquement les récoltes/pertes de ce compte par un jeu propre :
```powershell
py manage.py initialiser_mes_donnees --username VOTRE_UTILISATEUR --reset
```

## Machine Learning
```powershell
py manage.py entrainer_modele_ia
```

Le modèle utilise 3 000 exemples synthétiques et ajoute les récoltes réelles disponibles. Les étiquettes des données réelles sont déduites du taux de perte observé : faible ≤ 5 %, moyen > 5 %, élevé > 12 %.

## Lancer Django
```powershell
py manage.py runserver
```

Puis ouvrir `http://127.0.0.1:8000/`.

## Lancer Flutter
Dans un second terminal :
```powershell
cd app_flutter
flutter pub get
flutter analyze
flutter devices
flutter run
```

## Présentation de l'IA
Le Random Forest est un outil d'aide à la décision. Le scanner photo est une analyse colorimétrique indicative et ne doit pas être présenté comme un diagnostic agronomique certifié. La performance réelle du modèle dépendra d'un historique agricole réel suffisamment large et correctement labellisé.
