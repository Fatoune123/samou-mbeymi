"""Prédiction expérimentale du risque de pertes avec Random Forest.

Les exemples proviennent exclusivement des récoltes réelles enregistrées.
Avec un petit échantillon, les sorties sont indicatives et ne constituent pas
une mesure de performance généralisable.
"""
import os
import joblib
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import LabelEncoder

from .dataset import CULTURES, REGIONS

MODELE_DIR = os.path.join(os.path.dirname(__file__), "modeles")
MODELE_PATH = os.path.join(MODELE_DIR, "modele_risque_random_forest.pkl")
MIN_EXEMPLES_REELS = 4


def _encoders(exemples):
    cultures = sorted(set(CULTURES + [e["culture"] for e in exemples] + ["Autre"]))
    regions = sorted(set(REGIONS + [e["region"] for e in exemples]))
    return LabelEncoder().fit(cultures), LabelEncoder().fit(regions)


def _vectoriser(exemples, ce, re):
    cultures = [e["culture"] if e["culture"] in ce.classes_ else "Autre" for e in exemples]
    regions = [e["region"] if e["region"] in re.classes_ else REGIONS[0] for e in exemples]
    return np.column_stack([
        ce.transform(cultures), re.transform(regions),
        [e["mois"] for e in exemples], [e["quantite_kg"] for e in exemples],
        [e["stockage_formel"] for e in exemples],
    ])


def _reelles():
    from ..models import Recolte
    exemples = []
    for r in Recolte.objects.select_related("agriculteur", "culture").all():
        quantite = float(r.quantite_kg or 0)
        if quantite <= 0:
            continue
        perte = float(r.total_pertes_kg or 0)
        taux = perte / quantite * 100
        risque = "eleve" if taux > 12 else ("moyen" if taux > 5 else "faible")
        lieu = (r.lieu_stockage or "").lower()
        formel = int(any(k in lieu for k in [
            "silo", "entrepôt", "entrepot", "magasin", "frigo",
            "chambre froide", "hangar"
        ]))
        exemples.append({
            "culture": r.culture.nom,
            "region": r.agriculteur.region,
            "mois": r.date_recolte.month,
            "quantite_kg": quantite,
            "stockage_formel": formel,
            "risque": risque,
        })
    return exemples


def statistiques_donnees():
    exemples = _reelles()
    repartition = {"faible": 0, "moyen": 0, "eleve": 0}
    for e in exemples:
        repartition[e["risque"]] += 1
    classes = {e["risque"] for e in exemples}
    return {
        "exemples_reels": len(exemples),
        "minimum_requis": MIN_EXEMPLES_REELS,
        "repartition": repartition,
        "entrainement_possible": len(exemples) >= MIN_EXEMPLES_REELS and len(classes) >= 2,
    }


def entrainer():
    exemples = _reelles()
    repartition = {"faible": 0, "moyen": 0, "eleve": 0}
    for e in exemples:
        repartition[e["risque"]] += 1
    classes_presentes = sorted({e["risque"] for e in exemples})
    if len(exemples) < MIN_EXEMPLES_REELS:
        raise ValueError(
            f"Données insuffisantes : {len(exemples)} récoltes réelles. "
            f"Au moins {MIN_EXEMPLES_REELS} sont nécessaires. Aucun modèle n'a été entraîné."
        )
    if len(classes_presentes) < 2:
        raise ValueError("Au moins deux niveaux de risque doivent être représentés dans les récoltes réelles.")

    ce, re = _encoders(exemples)
    X = _vectoriser(exemples, ce, re)
    labels = ["faible", "moyen", "eleve"]
    y = np.array([labels.index(e["risque"]) for e in exemples], dtype=int)

    model = RandomForestClassifier(
        n_estimators=200,
        max_depth=4,
        min_samples_leaf=1,
        class_weight="balanced",
        random_state=42,
        n_jobs=1,
    )
    model.fit(X, y)
    importance = dict(zip(
        ["culture", "region", "mois", "quantite_kg", "stockage_formel"],
        [round(float(v), 4) for v in model.feature_importances_]
    ))
    os.makedirs(MODELE_DIR, exist_ok=True)
    joblib.dump({
        "modele": model,
        "culture_encoder": ce,
        "region_encoder": re,
        "importance": importance,
        "n_reelles": len(exemples),
        "algorithme": "RandomForest",
        "classes": [labels[int(v)] for v in model.classes_],
        "repartition": repartition,
        "evaluation": "non_evaluee_echantillon_insuffisant",
    }, MODELE_PATH)
    return {
        "importance": importance,
        "n_reelles": len(exemples),
        "algorithme": "Random Forest",
        "repartition": repartition,
        "evaluation": "Entraînement sur données disponibles ; performance non validée indépendamment.",
    }


def _charger():
    if not os.path.exists(MODELE_PATH):
        return None
    try:
        data = joblib.load(MODELE_PATH)
        if data.get("algorithme") != "RandomForest" or data.get("n_reelles", 0) < MIN_EXEMPLES_REELS:
            return None
        return data
    except Exception:
        return None


def predire_risque(culture_nom, region, mois, quantite_kg, lieu_stockage=""):
    data = _charger()
    if data is None:
        raise RuntimeError(
            "Le modèle Random Forest n'est pas encore entraîné. "
            "Vérifiez les données réelles puis lancez entrainer_modele_ia."
        )
    model = data["modele"]
    ce, re = data["culture_encoder"], data["region_encoder"]
    culture = culture_nom if culture_nom in ce.classes_ else "Autre"
    region = region if region in re.classes_ else REGIONS[0]
    lieu = (lieu_stockage or "").lower()
    formel = int(any(k in lieu for k in [
        "silo", "entrepôt", "entrepot", "magasin", "frigo",
        "chambre froide", "hangar"
    ]))
    X = _vectoriser([{
        "culture": culture, "region": region, "mois": int(mois),
        "quantite_kg": float(quantite_kg), "stockage_formel": formel,
    }], ce, re)
    probabilities = model.predict_proba(X)[0]
    model_labels = [data["classes"][i] for i in range(len(data["classes"]))]
    # RandomForest.classes_ garde les identifiants numériques de risque.
    labels_by_id = {0: "faible", 1: "moyen", 2: "eleve"}
    model_labels = [labels_by_id[int(v)] for v in model.classes_]
    index = int(np.argmax(probabilities))
    risk = model_labels[index]
    all_probabilities = {"faible": 0.0, "moyen": 0.0, "eleve": 0.0}
    for label, value in zip(model_labels, probabilities):
        all_probabilities[label] = round(float(value), 3)
    factors = []
    if int(mois) in (6, 7, 8, 9, 10):
        factors.append("La période correspond à la saison des pluies : surveillez l'humidité.")
    if not formel:
        factors.append("Le lieu renseigné n'est pas reconnu comme un stockage formel.")
    if float(quantite_kg) > 1500:
        factors.append("Le volume est important : renforcez les contrôles du lot.")
    if not factors:
        factors.append("Aucun facteur de vigilance simple n'a été détecté parmi les variables saisies.")
    return {
        "risque": risk,
        "risque_affiche": {"faible": "Faible", "moyen": "Moyen", "eleve": "Élevé"}[risk],
        "probabilites": all_probabilities,
        "facteurs": factors,
        "recommandation": (
            "Renforcez immédiatement le stockage et le suivi du lot." if risk == "eleve"
            else "Planifiez un contrôle préventif du lot." if risk == "moyen"
            else "Continuez le suivi préventif du lot."
        ),
        "modele": {
            "type": "Random Forest",
            "donnees_reelles": data["n_reelles"],
            "donnees_synthetiques": 0,
            "evaluation": "Résultat expérimental : petit échantillon, validation indépendante non réalisée.",
        },
    }


from .vision import analyser_photo  # compatibilité historique
