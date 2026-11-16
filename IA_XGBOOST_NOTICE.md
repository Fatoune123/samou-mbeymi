# Module d'analyse du risque agricole — Random Forest

Le moteur de prédiction utilise RandomForestClassifier de scikit-learn et les récoltes réellement enregistrées dans la base active. Aucune donnée synthétique n'est ajoutée.

L'entraînement s'effectue depuis backend_django avec :
`python manage.py entrainer_modele_ia`

Le résultat reste expérimental tant que le volume et la diversité des récoltes ne permettent pas une évaluation indépendante fiable.
