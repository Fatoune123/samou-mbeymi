from django.core.management.base import BaseCommand
from pertes.ia.engine import entrainer
class Command(BaseCommand):
    help='Entraîne le modèle Random Forest avec les données synthétiques et les données réelles disponibles.'
    def add_arguments(self, parser):
        parser.add_argument('--n',type=int,default=3000)
        parser.add_argument('--sans-reel',action='store_true')
    def handle(self,*args,**options):
        r=entrainer(options['n'],inclure_reel=not options['sans_reel'])
        m=r['metrics']
        self.stdout.write(self.style.SUCCESS(f"Modèle entraîné : {r['n_total']} exemples ({r['n_reelles']} réels + {r['n_synthetiques']} synthétiques)."))
        self.stdout.write(f"Accuracy={m['accuracy']:.3f} | Precision={m['precision']:.3f} | Recall={m['recall']:.3f} | F1={m['f1']:.3f}")
        self.stdout.write(f"Importance des variables : {r['importance']}")
