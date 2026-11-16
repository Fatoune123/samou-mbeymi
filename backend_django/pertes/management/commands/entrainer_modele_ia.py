from django.core.management.base import BaseCommand, CommandError
from pertes.ia.engine import entrainer


class Command(BaseCommand):
    help = "Entraîne Random Forest sur les récoltes réelles enregistrées."

    def handle(self, *args, **options):
        try:
            result = entrainer()
        except (ValueError, RuntimeError) as exc:
            raise CommandError(str(exc))
        self.stdout.write(self.style.SUCCESS(
            f"Modèle {result['algorithme']} entraîné sur {result['n_reelles']} récoltes réelles."
        ))
        self.stdout.write(f"Répartition des risques : {result['repartition']}")
        self.stdout.write(f"Importance des variables : {result['importance']}")
        self.stdout.write(self.style.WARNING(result["evaluation"]))
