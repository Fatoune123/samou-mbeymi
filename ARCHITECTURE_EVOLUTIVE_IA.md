# Architecture évolutive — perspective IA de SAMOU MBEYMI

## 1. Décision de périmètre
La version actuelle doit rester centrée sur quatre fonctions : gestion des récoltes, suivi des pertes, tableaux de bord et rapports. Le stockage et la traçabilité restent des capacités transversales attachées à chaque lot. L'IA, le chatbot et la marketplace sont hors du périmètre de démonstration actuel.

## 2. Architecture actuelle
```text
Application Flutter / Interface Web Django
                 |
                 v
       API Django REST Framework
                 |
       Services métier et validations
                 |
                 v
 Base de données relationnelle
 Producteurs | Cultures | Récoltes | Pertes
       |          Stockage / Traçabilité
                 |
                 v
      Indicateurs et rapports déterministes
```

## 3. Point d'extension IA (version future)
```text
Données historiques validées
           |
           v
Préparation / contrôle qualité des données
           |
           v
Service d'analyse IA isolé (futur)
           |
           v
Résultat documenté : modèle, date, niveau de confiance,
variables utilisées, limites et avertissement métier
           |
           v
API Django -> interface utilisateur
```

Le service IA futur ne doit pas être couplé aux écrans Flutter ni modifier directement les récoltes ou les pertes. Il devra recevoir des données validées via une interface de service, retourner un résultat structuré et conserver une trace de chaque analyse.

## 4. Données nécessaires avant toute IA
- Un historique réel de récoltes et pertes suffisamment volumineux.
- Des unités, dates, cultures et causes de pertes cohérentes.
- Des observations de stockage fiables lorsqu'elles sont disponibles.
- Des données représentatives de plusieurs producteurs, saisons et zones.
- Une définition métier vérifiable des catégories de risque.

Les données synthétiques peuvent servir aux essais techniques, mais ne suffisent pas à prouver la performance d'un modèle en conditions réelles.

## 5. Étapes futures recommandées
1. Collecter et contrôler les données réelles pendant l'utilisation de la version actuelle.
2. Définir avec un spécialiste agricole ce que signifie « risque de perte » et comment le mesurer.
3. Constituer un jeu d'entraînement et un jeu de test séparés.
4. Évaluer le modèle avec des métriques adaptées et comparer à une règle métier simple.
5. Exposer le modèle via un service isolé et une API versionnée.
6. Tester en mode expérimental avant toute présentation aux producteurs.
7. Surveiller les erreurs, les biais et la dérive des données après déploiement.

## 6. Règles de sécurité et de crédibilité
- Ne pas afficher une prédiction comme un fait ou un diagnostic agronomique.
- Ne pas inventer de résultats si le service IA est indisponible.
- Ne pas laisser un modèle modifier les données métier.
- Préserver les données historiques et les migrations.
- Documenter les limites, la date et la version du modèle.
