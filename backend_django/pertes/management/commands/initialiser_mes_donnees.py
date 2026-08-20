from datetime import date, timedelta
from django.core.management.base import BaseCommand, CommandError
from django.contrib.auth.models import User
from pertes.models import Agriculteur, Culture, Recolte, Perte, Stockage

class Command(BaseCommand):
    help='Prépare des données réalistes pour un compte EXISTANT, sans créer de compte demo.'
    def add_arguments(self, parser):
        parser.add_argument('--username', help='Nom du compte existant. Si absent, le seul utilisateur non-staff est utilisé.')
        parser.add_argument('--reset', action='store_true', help='Supprime les récoltes/pertes du compte avant de recréer les données.')
    def handle(self,*args,**o):
        qs=User.objects.filter(is_staff=False).order_by('id')
        if o.get('username'): qs=qs.filter(username=o['username'])
        if qs.count()!=1: raise CommandError('Compte introuvable ou plusieurs comptes correspondent. Utilisez --username votre_utilisateur.')
        user=qs.first(); profil,created=Agriculteur.objects.get_or_create(user=user,defaults={'region':'thies','nom_exploitation':'Mon exploitation'})
        if o['reset']:
            Recolte.objects.filter(agriculteur=profil).delete()
        cultures={}
        for nom,desc in [('Tomate','Culture maraîchère périssable'),('Mil','Céréale adaptée aux zones sèches'),('Oignon','Culture maraîchère de conservation'),('Maïs','Céréale de production saisonnière'),('Arachide','Culture oléagineuse')]:
            cultures[nom],_=Culture.objects.get_or_create(nom=nom,defaults={'description':desc})
        today=date.today(); data=[('Tomate',420,3,12,'Entrepôt principal'),('Mil',1250,18,38,'Magasin ventilé'),('Oignon',780,25,67,'Entrepôt principal'),('Maïs',980,9,92,'Silo communautaire'),('Arachide',640,4,120,'Magasin ventilé')]
        for i,(nom,q,perte,days,stock) in enumerate(data):
            r=Recolte.objects.create(agriculteur=profil,culture=cultures[nom],quantite_kg=q,date_recolte=today-timedelta(days=days),lieu_stockage=stock,notes='Donnée de démonstration pour le pilotage.')
            if perte: Perte.objects.create(recolte=r,type_perte=['insectes','moisissure','stockage','transport','climat'][i],quantite_perdue_kg=perte,description='Signalement de démonstration',statut='resolue' if i%2 else 'en_cours')
        for nom,region,cap,contact in [('Entrepôt principal',profil.region,5000,'77 000 00 00'),('Silo communautaire','kaolack',8000,'76 000 00 00'),('Magasin ventilé','thies',3500,'78 000 00 00')]: Stockage.objects.get_or_create(nom=nom,region=region,defaults={'capacite_kg':cap,'contact':contact,'disponible':True})
        self.stdout.write(self.style.SUCCESS(f'Données préparées pour le compte existant : {user.username}.'))
