"""Filtres pour écrire des valeurs CSS valides.

Avec LANGUAGE_CODE = 'fr-fr', Django écrit 66.4 sous la forme « 66,4 ».
Le CSS n'accepte que le point décimal : « height:66,4% » est ignoré par le navigateur,
et les barres des graphiques restent vides ou à 100 %.
"""
from django import template

register = template.Library()

LIBELLES_RISQUE = {'faible': 'Faible', 'moyen': 'Moyen', 'eleve': 'Élevé'}


@register.filter
def css_num(value):
    """66.4 -> '66.4' (point décimal, jamais de virgule)."""
    try:
        return format(round(float(value), 1), 'f')
    except (TypeError, ValueError):
        return '0'


@register.filter
def css_pct(value):
    """0.926 -> '92.6' (probabilité 0-1 convertie en pourcentage)."""
    try:
        return format(round(float(value) * 100, 1), 'f')
    except (TypeError, ValueError):
        return '0'


@register.filter
def risque_label(value):
    return LIBELLES_RISQUE.get(str(value), str(value).capitalize())
