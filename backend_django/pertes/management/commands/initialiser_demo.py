from datetime import date, timedelta
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.db import transaction
from pertes.models import Agriculteur, Culture, Recolte, Perte, Stockage

CULTURES = [
    ('Mil', 'Céréale locale adaptée aux conditions sahéliennes.'),
    ('Maïs', 'Culture céréalière suivie pour la production et le stockage.'),
    ('Riz', 'Culture céréalière.'),
    ('Arachide', 'Culture oléagineuse.'),
    ('Niébé', 'Légumineuse.'),
    ('Manioc', 'Culture tubéreuse.'),
    ('Oignon', 'Culture maraîchère.'),
    ('Pastèque', 'Culture maraîchère fruitière.'),
    ('Tomate', 'Culture maraîchère périssable.'),
    ('Mangue', 'Fruit tropical.'),
]


class Command(BaseCommand):
    help = "Prépare les données de démonstration de Samou Mbeymi."

    @transaction.atomic
    def handle(self, *args, **options):
        for nom, description in CULTURES:
            Culture.objects.get_or_create(nom=nom, defaults={'description': description})

        for nom, region, capacite in [
            ('Magasin communautaire de Thiès', 'thies', 5000),
            ('Entrepôt agricole de Dakar', 'dakar', 8000),
            ('Silo régional de Kaolack', 'kaolack', 12000),
        ]:
            Stockage.objects.get_or_create(nom=nom, defaults={'region': region, 'capacite_kg': capacite, 'contact': ''})

        user, created = User.objects.get_or_create(username='demo', defaults={
            'first_name': 'Mamadou', 'last_name': 'Diop', 'email': 'demo@samoumbeymi.local'
        })
        if created:
            user.set_password('Demo@12345')
            user.save()
        profil, _ = Agriculteur.objects.get_or_create(user=user, defaults={
            'telephone': '770000000', 'region': 'thies', 'nom_exploitation': 'Ferme Démonstration Samou'
        })

        if Recolte.objects.filter(agriculteur=profil).exists():
            self.stdout.write(self.style.WARNING('Les données de démonstration existent déjà.'))
            self.stdout.write('Compte : demo / Demo@12345')
            return

        cultures = {c.nom: c for c in Culture.objects.all()}
        today = date.today()
        samples = [
            ('Tomate', 850, 45, 'Magasin communautaire de Thiès', 'insectes', 28),
            ('Oignon', 1200, 70, 'Magasin communautaire de Thiès', 'stockage', 35),
            ('Mil', 2500, 180, 'Silo régional de Kaolack', 'transport', 18),
            ('Maïs', 1800, 90, 'Entrepôt agricole de Dakar', 'moisissure', 12),
            ('Mangue', 900, 130, '', 'climat', 8),
        ]
        for idx, (culture, qte, perte, stockage, cause, days) in enumerate(samples):
            recolte = Recolte.objects.create(
                agriculteur=profil, culture=cultures[culture], quantite_kg=qte,
                date_recolte=today - timedelta(days=days), lieu_stockage=stockage,
                notes='Donnée de démonstration pour la soutenance.'
            )
            Perte.objects.create(
                recolte=recolte, type_perte=cause, quantite_perdue_kg=perte,
                description='Signalement de démonstration.',
                statut='resolue' if idx < 2 else 'en_cours'
            )

        self.stdout.write(self.style.SUCCESS('Données de démonstration créées.'))
        self.stdout.write('Compte : demo / Demo@12345')
