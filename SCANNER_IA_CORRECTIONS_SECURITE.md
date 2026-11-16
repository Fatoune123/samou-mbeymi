# Correctifs de sécurité — Scanner IA

## Corrections incluses
- Compression côté navigateur : redimensionnement à 1600 px maximum et conversion JPEG avant l'envoi.
- Limite serveur : corps JSON plafonné à 10 Mo et image décodée plafonnée à 6 Mo.
- Validation du format réel avec Pillow (JPEG, PNG, WEBP uniquement), des dimensions et de l'intégrité du fichier.
- Normalisation de l'image après validation (orientation EXIF, RGB, JPEG).
- Protection CSRF réactivée sur l'API du scanner ; le navigateur transmet le jeton CSRF.
- Les erreurs de dépassement de taille renvoient HTTP 413 au lieu d'une erreur 500.
- Le contrôle CLIP refuse les images classées comme visages, personnes, animaux, objets, véhicules, pièces, écrans, emballages, nourriture cuisinée ou paysages.
- Les classes agricoles acceptées couvrent fruits, légumes, céréales, légumineuses et tubercules.
- Seuil de reconnaissance renforcé. Une photo incertaine est refusée plutôt que traitée comme une récolte.

## Installation
1. Décompresser l'archive dans un nouveau dossier.
2. Réutiliser l'environnement virtuel du projet si les dépendances sont déjà installées.
3. Si le moteur CLIP n'est pas installé :
   `pip install -r requirements-vision.txt`
4. Lancer :
   `python manage.py runserver`
5. Tester d'abord une photo nette d'un seul produit agricole récolté, puis une photo d'objet ou de visage : cette dernière doit être refusée.

## Limites importantes
La reconnaissance CLIP est probabiliste : aucun classifieur visuel ne garantit 100 % de détection correcte. Le seuil est volontairement conservateur, mais une image ambiguë peut être mal classée. Pour une garantie plus forte, il faudra ajouter un détecteur spécialisé entraîné et évalué sur un jeu d'images agricoles local (cultures du Sénégal) et un détecteur de visages/ personnes. L'analyse colorimétrique reste un indicateur visuel expérimental, pas un diagnostic de maladie ni une mesure certifiée de pertes.

## Protection des données
Aucune migration n'a été ajoutée. La base SQLite originale est conservée octet pour octet dans cette archive.
