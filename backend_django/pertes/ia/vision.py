"""Contrôle de la photo puis analyse indicative de couleurs.

Le contrôle d'objet utilise CLIP en zero-shot. Il ne remplace pas une expertise
agronomique et peut se tromper. Le modèle est téléchargé au premier usage si
le cache local ne le contient pas. Si le moteur n'est pas installé/disponible,
l'analyse est refusée plutôt que de présenter une photo quelconque comme récolte.
"""
import os
import numpy as np


class MoteurVisionIndisponible(RuntimeError):
    pass


def _verifier_culture(image):
    """Renvoie un contrôle CLIP; ferme le service si le modèle n'est pas disponible."""
    try:
        from transformers import pipeline
    except ImportError as exc:
        raise MoteurVisionIndisponible(
            "Le contrôle IA des objets n'est pas installé. Installez les dépendances de vision avec: "
            "pip install -r requirements-vision.txt"
        ) from exc

    # Cache le pipeline dans le processus pour ne pas recharger le modèle à chaque photo.
    global _CLASSIFIER
    try:
        _CLASSIFIER
    except NameError:
        _CLASSIFIER = None
    if _CLASSIFIER is None:
        model_name = os.environ.get('SAMOU_CLIP_MODEL', 'openai/clip-vit-base-patch32')
        try:
            _CLASSIFIER = pipeline('zero-shot-image-classification', model=model_name)
        except Exception as exc:
            raise MoteurVisionIndisponible(
                "Le modèle de reconnaissance visuelle est indisponible. Vérifiez Internet au premier lancement "
                "ou le cache local du modèle, puis réessayez."
            ) from exc

    # Le scanner accepte uniquement les fruits et légumes récoltés. Les objets
    # courants (bouteille, main, visage, mur, téléphone, etc.) sont des classes
    # négatives explicites afin d'éviter de traiter leur couleur comme une récolte.
    crop_labels = {
        'a close-up photograph of freshly harvested agricultural produce: fruits or vegetables',
        'a photograph of harvested tomatoes, onions, potatoes, carrots, cabbage, peppers, eggplants or cucumbers',
        'a photograph of harvested mangoes, bananas, oranges, apples, lemons, papayas or watermelons',
        'a photograph of harvested maize, corn cobs, millet, sorghum, rice grains or wheat',
        'a photograph of harvested groundnuts, peanuts, cowpeas, beans or other dry legumes',
        'a photograph of harvested cassava, sweet potatoes, yams or other edible roots and tubers',
        'a close-up photograph of harvested tomatoes only',
        'a close-up photograph of harvested onions only',
        'a close-up photograph of harvested potatoes only',
        'a close-up photograph of harvested carrots only',
        'a close-up photograph of harvested cabbage only',
        'a close-up photograph of harvested peppers only',
        'a close-up photograph of harvested mangoes only',
        'a close-up photograph of harvested bananas only',
        'a close-up photograph of harvested maize or corn only',
        'a close-up photograph of harvested groundnuts or peanuts only',
        'a close-up photograph of harvested millet or sorghum grains only',
    }
    negative_labels = {
        'a photograph of a human face, portrait, selfie or head',
        'a photograph of a person, human body or people',
        'a photograph of a person holding an object',
        'a photograph of a person holding or standing next to agricultural produce',
        'a photograph of human hands or fingers only',
        'a photograph of a dog, cat, livestock, bird or other animal',
        'a photograph of a plastic bottle, water bottle, cup or glass',
        'a photograph of a phone, computer, television or electronic device',
        'a photograph of a vehicle, truck, tractor, road or machinery',
        'a photograph of a house, room, wall, floor, furniture or household object',
        'a photograph of clothes, shoes, bags, tools or construction materials',
        'a photograph of a package, box, label, logo or product container',
        'a photograph of cooked food, a prepared meal, soup or restaurant dish',
        'a photograph of flowers, ornamental plants, grass or tree leaves only',
        'a photograph of crop leaves or stems only without harvested produce',
        'a photograph of soil, sand, rocks, water, sky or landscape',
        'a screenshot, drawing, painting, illustration or cartoon',
    }
    labels = list(crop_labels | negative_labels)
    try:
        results = _CLASSIFIER(image, candidate_labels=labels)
    except Exception as exc:
        raise MoteurVisionIndisponible('Impossible d’analyser cette image avec le modèle de vision.') from exc
    results = sorted(results, key=lambda x: float(x.get('score', 0)), reverse=True)
    best = results[0]
    score = float(best.get('score', 0))
    crop_score = max((float(item.get('score', 0)) for item in results if item.get('label') in crop_labels), default=0.0)
    non_crop_score = max((float(item.get('score', 0)) for item in results if item.get('label') in negative_labels), default=0.0)
    # Seuils conservateurs : une photo d'objet ne doit pas être interprétée comme
    # une récolte simplement parce qu'elle contient des couleurs sombres ou brunes.
    if best.get('label') not in crop_labels or crop_score < 0.45 or (crop_score - non_crop_score) < 0.15:
        return {
            'photo_acceptee': False,
            'categorie': 'photo_refusee',
            'message': "Photo refusée : aucune culture agricole n’a pu être confirmée avec suffisamment de confiance. "
                       "Photographiez uniquement un produit agricole récolté (fruit, légume, céréale, légumineuse ou tubercule), "
                       "en gros plan, avec une bonne lumière, sans visage, personne ni objet autour.",
            'confiance_reconnaissance_pct': round(crop_score * 100, 1),
            'limite': "La reconnaissance automatique peut se tromper; vérifiez toujours visuellement.",
        }
    return {
        'photo_acceptee': True,
        'type_image': 'produit_agricole_probable',
        'confiance_reconnaissance_pct': round(crop_score * 100, 1),
        'limite_reconnaissance': "Reconnaissance indicative, non garantie pour toutes les espèces et conditions de prise de vue.",
    }


def analyser_photo(image_path):
    from PIL import Image, ImageOps
    try:
        with Image.open(image_path) as source:
            image = ImageOps.exif_transpose(source).convert('RGB')
            controle = _verifier_culture(image)
            if not controle.get('photo_acceptee'):
                return controle
            img = image.copy()
    except MoteurVisionIndisponible:
        raise
    img.thumbnail((300, 300))
    a = np.asarray(img).astype(float)
    h, w, _ = a.shape

    bord = max(2, min(h, w) // 25)
    contour = np.concatenate([a[:bord].reshape(-1, 3), a[-bord:].reshape(-1, 3),
                              a[:, :bord].reshape(-1, 3), a[:, -bord:].reshape(-1, 3)])
    fond = np.median(contour, axis=0)
    ecart = np.sqrt(((a - fond) ** 2).sum(axis=2))
    produit = ecart > 40
    if produit.mean() < 0.05:
        produit = np.ones((h, w), dtype=bool)

    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = (r + g + b) / 3
    vert = (g > r * 1.05) & (g > b * 1.05)
    sombre = (lum < 60) & ~vert
    ratio_gr = g / np.maximum(r, 1)
    brun = (r > g) & (g > b) & (ratio_gr > 0.40) & (ratio_gr < 0.85) & (lum < 115) & ~sombre

    n = max(int(produit.sum()), 1)
    part_sombre = float((sombre & produit).sum()) / n
    part_brune = float((brun & produit).sum()) / n
    taux = part_sombre + part_brune

    if taux < .12:
        cat, msg = 'bon_etat', 'Aucun signe visuel majeur de détérioration détecté.'
    elif taux < .30:
        cat, msg = 'a_surveiller', 'Quelques zones sombres ou brunes détectées : vérification recommandée.'
    else:
        cat, msg = 'deterioration_probable', 'Proportion importante de zones sombres ou brunes : inspection recommandée.'

    signe = '' if taux < .12 else ('Zones très sombres (pourriture avancée possible)' if part_sombre >= part_brune else 'Taches brunes (brunissement ou début de pourriture possible)')
    return {
        **controle,
        'taux_zones_ternies': round(taux * 100, 1),
        'part_sombre': round(part_sombre * 100, 1),
        'part_brune': round(part_brune * 100, 1),
        'zone_analysee': round(n / (h * w) * 100, 1),
        'signe_principal': signe,
        'categorie': cat,
        'message': msg,
        'limite': 'Analyse colorimétrique indicative, pas un diagnostic agronomique certifié. Confirmez le résultat par inspection réelle.',
    }
