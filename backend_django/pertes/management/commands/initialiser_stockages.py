from django.core.management.base import BaseCommand
from pertes.models import Stockage, REGIONS_SENEGAL

# Capacités indicatives (kg), à remplacer par les vrais points de stockage
# (liste officielle, partenaires, coopératives) avant une mise en production.
CAPACITES = {
    'dakar': 8000, 'thies': 5000, 'diourbel': 4000, 'fatick': 4500, 'kaolack': 12000,
    'kaffrine': 6000, 'kolda': 5000, 'louga': 4000, 'matam': 3500, 'saint_louis': 7000,
    'sedhiou': 3500, 'tambacounda': 6000, 'kedougou': 3000, 'ziguinchor': 5000,
}


class Command(BaseCommand):
    help = "Crée un point de stockage de démonstration par région (aucun doublon créé)."

    def handle(self, *args, **options):
        crees = 0
        for code, label in REGIONS_SENEGAL:
            _, created = Stockage.objects.get_or_create(
                nom=f'Magasin communautaire de {label}', region=code,
                defaults={'capacite_kg': CAPACITES.get(code, 4000), 'disponible': True, 'contact': ''},
            )
            crees += int(created)
        self.stdout.write(self.style.SUCCESS(f'{crees} point(s) de stockage créé(s) ; {Stockage.objects.count()} au total.'))
        self.stdout.write('Ce sont des données de démonstration : remplacez-les par les vrais points via /admin/.')
