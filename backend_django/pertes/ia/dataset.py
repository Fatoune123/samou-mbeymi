"""
Génération d'un jeu de données synthétique pour entraîner le modèle de prédiction
du risque de perte post-récolte.

Pourquoi des données synthétiques ?
Au démarrage du projet (phase 6), l'application ne dispose pas encore d'un
historique réel de récoltes/pertes suffisant pour entraîner un modèle fiable.
On construit donc un jeu de données réaliste à partir de connaissances
agronomiques documentées (sensibilité des cultures à la chaleur/l'humidité,
saison des pluies au Sénégal, qualité du stockage...), avec du bruit aléatoire.
Le modèle (RandomForest) apprend ensuite la relation entre ces facteurs et le
risque, exactement comme il le ferait sur des données réelles collectées via
l'application. Quand assez de vraies données seront disponibles (via les
récoltes/pertes enregistrées par les agriculteurs), il suffira de ré-entraîner
le modèle sur `Recolte`/`Perte` réels avec la même fonction `entrainer()`.
"""
import random

# Sensibilité relative à la détérioration (0 = très résistant, 1 = très périssable)
SENSIBILITE_CULTURE = {
    'Mil': 0.10, 'Maïs': 0.15, 'Riz': 0.15, 'Arachide': 0.20, 'Niébé': 0.15,
    'Manioc': 0.35, 'Oignon': 0.40, 'Pastèque': 0.55,
    'Tomate': 0.75, 'Mangue': 0.70,
}

# Pluviométrie relative par région (0 = sec, 1 = très humide) — influence moisissures
HUMIDITE_REGION = {
    'dakar': 0.30, 'thies': 0.30, 'diourbel': 0.25, 'fatick': 0.35,
    'kaolack': 0.35, 'kaffrine': 0.30, 'kolda': 0.65, 'louga': 0.15,
    'matam': 0.15, 'saint_louis': 0.20, 'sedhiou': 0.70,
    'tambacounda': 0.45, 'kedougou': 0.60, 'ziguinchor': 0.75,
}

CULTURES = list(SENSIBILITE_CULTURE.keys())
REGIONS = list(HUMIDITE_REGION.keys())


def _mois_risque(mois):
    """Juin à octobre = saison des pluies au Sénégal -> risque accru d'humidité."""
    return 0.7 if mois in (6, 7, 8, 9, 10) else 0.2


def generer_exemple(rng):
    culture = rng.choice(CULTURES)
    region = rng.choice(REGIONS)
    mois = rng.randint(1, 12)
    quantite_kg = rng.uniform(20, 3000)
    stockage_formel = rng.random() < 0.45  # magasin/entrepôt/silo vs stockage informel

    score = (
        0.40 * SENSIBILITE_CULTURE[culture]
        + 0.25 * HUMIDITE_REGION[region]
        + 0.20 * _mois_risque(mois)
        + 0.10 * min(quantite_kg / 3000, 1.0)
        + (0.0 if stockage_formel else 0.20)
    )
    score += rng.gauss(0, 0.08)  # bruit
    score = max(0.0, min(1.0, score))

    if score < 0.33:
        risque = 'faible'
    elif score < 0.60:
        risque = 'moyen'
    else:
        risque = 'eleve'

    return {
        'culture': culture,
        'region': region,
        'mois': mois,
        'quantite_kg': round(quantite_kg, 1),
        'stockage_formel': int(stockage_formel),
        'risque': risque,
    }


def generer_dataset(n=3000, seed=42):
    rng = random.Random(seed)
    return [generer_exemple(rng) for _ in range(n)]
