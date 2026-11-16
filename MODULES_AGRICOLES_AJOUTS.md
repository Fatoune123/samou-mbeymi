# SAMOU MBEY — Modules agricoles ajoutés

Cette version ajoute des écrans Flutter et des endpoints Django sans créer de modèle Django, sans ajouter de migration et sans exécuter de commande sur la base de données.

## Modules

### 1. Conservation
- Liste les récoltes déjà enregistrées dans le compte connecté.
- Affiche des conseils de stockage selon le produit.
- Permet de lancer le modèle existant de prédiction du risque.
- Les durées de conservation ne sont pas inventées : l'API précise qu'une estimation fiable exige notamment la variété, la maturité et les conditions réelles.
- Le scanner photo existant reste disponible dans l'onglet « Scanner IA ».

Endpoint : `GET /api/conservation/conseils/?produit=Tomate`

### 2. Assistant phytosanitaire
- Conseils généraux de surveillance et de prévention.
- Question adressée au conseiller agricole Gemini existant.
- Enregistrement d'une perte phytosanitaire réelle via le modèle de pertes déjà présent.
- Le formulaire précise qu'il faut saisir une quantité réellement perdue ; il ne crée pas de fausse perte pour un simple symptôme.
- Aucun pesticide n'est prescrit automatiquement.

Endpoint : `GET /api/phytosanitaire/conseils/?culture=Tomate`

### 3. Engrais et répertoire local
- Présente des repères généraux sur les familles d'engrais.
- Permet de noter localement les coordonnées de fournisseurs rencontrés par l'utilisateur.
- Les contacts sont conservés dans les préférences de l'appareil (`SharedPreferences`), pas dans la base Django et pas partagés entre appareils.
- Aucun fournisseur, prix ou stock n'est inventé. Les informations doivent être vérifiées auprès du vendeur.

Endpoint : `GET /api/engrais/catalogue/`

## Accès dans Flutter
Depuis le tableau de bord, ouvrir le menu en haut à droite puis « Conservation, phytosanitaire & engrais ».

## Fichiers modifiés / ajoutés
- `backend_django/pertes/api_views.py`
- `backend_django/pertes/api_urls.py`
- `app_flutter/lib/services/api_service.dart`
- `app_flutter/lib/screens/dashboard_screen.dart`
- `app_flutter/lib/screens/modules_agricoles_screen.dart` (nouveau)

## Protection des données
Aucune modification intentionnelle n'a été faite à `backend_django/db.sqlite3`, `backend_django/.env`, `pertes/admin.py`, aux identifiants utilisateurs, aux mots de passe ou aux migrations existantes. Aucune migration n'a été créée ou exécutée.

## Vérifications nécessaires sur l'ordinateur de développement
L'environnement de cette session ne contient pas Django ni Flutter. Le contrôle de syntaxe Python a été effectué, mais il reste à exécuter localement :

Backend :
```bash
python manage.py check
python manage.py test pertes
```

Flutter :
```bash
flutter pub get
flutter analyze
flutter test
```

Le conseiller Gemini nécessite une configuration existante valide de `GEMINI_API_KEY`. L'analyse de risque dépend du modèle IA et de ses données déjà présents dans le projet.
