# Samou Mbeymi — Version 4.0

Version de fin d'études renforcée : application Flutter + API Django + module IA + centre de pilotage web.

## Nouveautés visibles

### Web Django
- Centre de pilotage entièrement redesigné avec navigation latérale.
- KPI production, pertes et rendement conservé.
- Alerte intelligente selon le taux de perte.
- Évolution mensuelle production/pertes sur 12 mois.
- Répartition visuelle des causes de pertes.
- Activité récente.
- Carte de recommandation IA.
- Responsive desktop/tablette/mobile.

### Flutter
- Dashboard agricole premium.
- Navigation Accueil / Récoltes / Pertes / Scanner IA / Profil.
- Écran Profil connecté à `/api/profil/`.
- Design Material 3 cohérent.
- Gestion des états de chargement et d'erreur.
- Authentification et API conservées.

### Backend/API
- Endpoint tableau de bord enrichi avec évolution mensuelle, rendement conservé, niveau de risque et recommandation.
- CRUD des récoltes et pertes conservé.
- Module de prédiction de risque conservé.
- Scanner photo conservé.

## Lancement local

### Backend
```powershell
cd "C:\Users\Hp\Desktop\Samou_Mbeymi_Professional_v4\samou_mbeymi_projet\backend_django"
py -m venv .venv
.\.venv\Scripts\Activate.ps1
py -m pip install --upgrade pip
py -m pip install -r requirements.txt
py manage.py check
py manage.py migrate
py manage.py runserver
```

### Flutter
Dans un second terminal :
```powershell
cd "C:\Users\Hp\Desktop\Samou_Mbeymi_Professional_v4\samou_mbeymi_projet\app_flutter"
flutter pub get
flutter analyze
flutter devices
flutter run
```

## Important
Le module photo fournit une alerte visuelle indicative. Il ne faut pas le présenter comme un diagnostic agronomique certifié. Pour la soutenance, présenter l'IA comme un prototype d'aide à la décision basé sur les données disponibles.
