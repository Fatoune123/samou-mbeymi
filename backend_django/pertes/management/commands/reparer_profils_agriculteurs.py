from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from pertes.models import Agriculteur


class Command(BaseCommand):
    help = "Crée un profil agriculteur pour chaque compte utilisateur qui n'en possède pas."

    def handle(self, *args, **options):
        User = get_user_model()
        crees = 0
        for user in User.objects.all().iterator():
            _, created = Agriculteur.objects.get_or_create(
                user=user,
                defaults={'region': 'thies', 'nom_exploitation': ''},
            )
            crees += int(created)
        self.stdout.write(self.style.SUCCESS(
            f"Terminé : {crees} profil(s) agriculteur créé(s). Les profils existants ont été conservés."
        ))
