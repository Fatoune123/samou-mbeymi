# Samou Mbeymi — V16 recentrée pour la soutenance

Application de suivi post-récolte destinée à aider un agriculteur à **enregistrer ses récoltes, déclarer les pertes, visualiser ses indicateurs et utiliser des outils d'aide à la décision basés sur l'IA**.

## 1. Périmètre fonctionnel V16

### Fonctionnalités prioritaires
- Inscription et connexion par token.
- Gestion des récoltes et consultation des lots enregistrés.
- Déclaration, consultation et suivi des pertes.
- Contrôle métier empêchant une perte de dépasser la quantité récoltée.
- Tableau de bord : volumes récoltés, volumes perdus, taux de perte et évolution mensuelle.
- Synthèse de pilotage et consultation des points de stockage.
- Rapports et export CSV côté backend.

### Fonctionnalités reportées
- Analyse photographique par IA.
- Assistant conversationnel agricole.
- Mise en relation producteurs–acheteurs / marketplace.

Le code source de ces modules est conservé pour une version ultérieure, mais leurs accès sont retirés de la navigation principale V16. Leur fonctionnement n'est pas considéré comme faisant partie du périmètre validé de cette version.

## 2. Architecture

```text
Flutter mobile
    │
    │ HTTP / JSON + Token
    ▼
Django REST Framework
    │
    ├── Authentification
    ├── Récoltes
    ├── Pertes
    ├── Tableau de bord
    ├── Rapports
    └── IA
          ├── Random Forest
          └── Analyse visuelle
    │
    ▼
SQLite / base de données Django
```

## 3. Installation backend Windows

```powershell
cd "C:\chemin\vers\samou_mbeymi_projet\backend_django"
py -m venv .venv
.\.venv\Scripts\Activate.ps1
py -m pip install --upgrade pip
py -m pip install -r requirements.txt
py manage.py migrate
py manage.py check
py manage.py initialiser_demo
py manage.py runserver
```

Compte de démonstration :

```text
Utilisateur : demo
Mot de passe : Demo@12345
```

## 4. Installation Flutter

Dans un second terminal :

```powershell
cd "C:\chemin\vers\samou_mbeymi_projet\app_flutter"
flutter pub get
flutter analyze
flutter devices
flutter run
```

### Émulateur Android

Le backend local est accessible depuis l'émulateur Android avec :

```text
http://10.0.2.2:8000/api
```

### Téléphone Android physique

Lancer Django :

```powershell
py manage.py runserver 0.0.0.0:8000
```

Puis récupérer l'IPv4 du PC avec `ipconfig` et lancer Flutter par exemple :

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.15:8000/api
```

Le PC et le téléphone doivent être sur le même réseau.

## 5. IA — formulation correcte pour la soutenance

Le modèle de risque est un **Random Forest Classifier**. Le jeu d'entraînement actuel est synthétique, car le projet ne dispose pas encore d'un historique réel suffisamment volumineux et labellisé.

Les variables utilisées sont :
- culture ;
- région ;
- mois ;
- quantité récoltée ;
- qualité du stockage.

Le scanner photo est une **analyse colorimétrique indicative**, et non un modèle CNN certifié. Il sert à démontrer le principe de vision par ordinateur et d'aide à la décision.

Cette distinction doit être expliquée au jury : elle montre que le projet maîtrise ses limites et son potentiel d'évolution.

## 6. Démonstration recommandée

1. Se connecter avec le compte de démonstration.
2. Montrer le tableau de bord et les KPI.
3. Ajouter une récolte.
4. Lancer la prédiction IA.
5. Enregistrer la récolte.
6. Signaler une perte.
7. Montrer la mise à jour du taux de perte.
8. Modifier puis supprimer un enregistrement.
9. Scanner une photo.
10. Montrer le rapport et exporter le CSV.
11. Montrer l'API et l'administration Django.

## 7. Points techniques à défendre

- Séparation frontend / backend.
- API REST.
- Authentification par token.
- Isolation des données par agriculteur.
- Validation des quantités.
- Agrégation des KPI.
- Modèle de machine learning.
- Vision par ordinateur.
- Gestion des erreurs et états de chargement.
- Responsive design.
- Export des données.
- Tests automatisés.


## Traçabilité événementielle (itération V17)
Le modèle `EvenementTraceabilite` conserve l'historique des récoltes : création, changement de lieu, mise à jour de quantité et déclaration de perte. L'API `/api/traceabilite/evenements/` est réservée aux utilisateurs authentifiés et filtrée par propriétaire. Consulter `V17_NOTES_DEVELOPPEMENT.md` pour les étapes de migration et de test.
