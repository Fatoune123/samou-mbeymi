# Modèle de prédiction — Random Forest

Le moteur utilise `RandomForestClassifier` de scikit-learn. Les exemples proviennent exclusivement des récoltes et pertes enregistrées dans la base active.

## Entraînement
Depuis `backend_django` :
```cmd
python manage.py entrainer_modele_ia
```

Le modèle est enregistré dans `pertes/ia/modeles/modele_risque_random_forest.pkl`.

## Limites
Les classes de risque sont calculées à partir du taux de pertes observé : faible (<= 5 %), moyen (> 5 % et <= 12 %), élevé (> 12 %). Un petit nombre de récoltes peut permettre un entraînement technique, mais ne permet pas de valider scientifiquement la performance du modèle. Les probabilités sont des scores du modèle, pas des garanties de risque réel. Aucune donnée synthétique n'est ajoutée.

## Base de données
Ce correctif ne modifie pas `db.sqlite3`, les migrations, les comptes ou les données métier.
