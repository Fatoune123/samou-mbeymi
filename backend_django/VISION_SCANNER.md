# Scanner visuel — contrôle des photos

Le scanner contrôle désormais le type de photo avec CLIP avant l'analyse colorimétrique. Une photo identifiée comme visage, personne, objet ou image incertaine est refusée (HTTP 422). Si le moteur IA n'est pas installé ou que le modèle n'est pas disponible, le scanner renvoie une erreur explicite (HTTP 503) au lieu de produire un résultat trompeur.

## Installation Windows
Depuis `backend_django`, activez le venv puis exécutez :

```bat
pip install -r requirements-vision.txt
```

Au premier usage, le modèle `openai/clip-vit-base-patch32` est téléchargé depuis Hugging Face; une connexion Internet est nécessaire. Pour un environnement hors ligne, pré-téléchargez le modèle et définissez `SAMOU_CLIP_MODEL` vers le chemin local.

## Limites
CLIP est un modèle généraliste et peut se tromper. La vérification est indicative; elle ne certifie ni l'espèce ni la présence réelle de pourriture. L'analyse des zones sombres/brunes reste une heuristique colorimétrique, pas un diagnostic agronomique.


## Comportement côté Flutter

- Une réponse HTTP 422 correspondant à une photo non agricole est affichée comme « Photo refusée ».
- Le scanner n'affiche pas de pourcentage de zones ternies pour une photo refusée.
- Aucune quantité potentiellement touchée n'est calculée et aucun bouton de signalement de perte n'est proposé pour cette photo.
- Les cultures prises en charge dépendent de la capacité du modèle de vision généraliste : « toutes les cultures » ne peut pas être garanti sans tests et/ou données d'entraînement couvrant chaque culture.

## Vérification après mise à jour

Tester au minimum une photo nette de légumes/fruits/récolte, une photo de plante au champ, un visage, un téléphone ou une chaussure, et une image floue ou trop éloignée. Les photos non agricoles doivent être refusées; les cultures reconnues doivent arriver à l'analyse colorimétrique indicative.
