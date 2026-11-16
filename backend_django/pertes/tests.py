from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient
from .models import Agriculteur, Culture, Recolte, Perte


class SamouMbeymiAPITest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='testeur', password='Test@12345', first_name='Test')
        self.profil = Agriculteur.objects.create(user=self.user, region='thies', nom_exploitation='Ferme Test')
        self.culture = Culture.objects.create(nom='Tomate')
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_dashboard(self):
        r = Recolte.objects.create(agriculteur=self.profil, culture=self.culture, quantite_kg=100, date_recolte='2026-08-01')
        Perte.objects.create(recolte=r, type_perte='stockage', quantite_perdue_kg=10)
        response = self.client.get('/api/tableau-de-bord/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['total_recolte_kg'], 100.0)
        self.assertEqual(response.data['total_perte_kg'], 10.0)
        self.assertEqual(response.data['taux_perte'], 10.0)

    def test_perte_ne_depasse_pas_recolte(self):
        r = Recolte.objects.create(agriculteur=self.profil, culture=self.culture, quantite_kg=100, date_recolte='2026-08-01')
        response = self.client.post('/api/pertes/', {'recolte': r.id, 'type_perte': 'stockage', 'quantite_perdue_kg': 101}, format='json')
        self.assertEqual(response.status_code, 400)
    def test_recoltes_isolees_par_utilisateur(self):
        autre = User.objects.create_user(username='autre', password='Autre@12345')
        autre_profil = Agriculteur.objects.create(user=autre, region='dakar', nom_exploitation='Autre ferme')
        r = Recolte.objects.create(agriculteur=autre_profil, culture=self.culture, quantite_kg=50, date_recolte='2026-08-01')
        response = self.client.get(f'/api/recoltes/{r.id}/')
        self.assertEqual(response.status_code, 404)

    def test_scanner_refuse_fichier_non_image(self):
        from django.core.files.uploadedfile import SimpleUploadedFile
        response = self.client.post('/api/ia/scanner-photo/', {
            'photo': SimpleUploadedFile('not-image.txt', b'not an image', content_type='text/plain')
        }, format='multipart')
        self.assertEqual(response.status_code, 400)


    def test_marche_est_consultable_sans_connexion(self):
        from .models import OffreRecolte
        recolte = Recolte.objects.create(agriculteur=self.profil, culture=self.culture, quantite_kg=100, date_recolte='2026-10-01')
        OffreRecolte.objects.create(recolte=recolte, quantite_kg=25, prix_kg_fcfa=450, commune='Diamniadio')
        client_public = APIClient()
        response = client_public.get('/api/marketplace/offres/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['count'], 1)

    def test_filtre_marche_par_region_et_proximite(self):
        from .models import OffreRecolte
        recolte = Recolte.objects.create(agriculteur=self.profil, culture=self.culture, quantite_kg=100, date_recolte='2026-10-01')
        OffreRecolte.objects.create(recolte=recolte, quantite_kg=20, prix_kg_fcfa=400, commune='Diamniadio', latitude='14.717200', longitude='-17.176000')
        response = APIClient().get('/api/marketplace/offres/?region=Thiès&latitude=14.72&longitude=-17.17&rayon_km=10')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['count'], 1)
        self.assertAlmostEqual(response.data['results'][0]['distance_km'], 0.8, delta=1.5)

    def test_offre_marche_geolocalisee(self):
        from .models import OffreRecolte
        recolte = Recolte.objects.create(
            agriculteur=self.profil, culture=self.culture,
            quantite_kg=100, date_recolte='2026-10-01'
        )
        response = self.client.post('/api/marketplace/offres/', {
            'recolte': recolte.id, 'quantite_kg': '40', 'prix_kg_fcfa': '500',
            'commune': 'Diamniadio', 'latitude': '14.7172', 'longitude': '-17.1760',
            'description': 'Récolte fraîche disponible',
        }, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(OffreRecolte.objects.count(), 1)
        self.assertEqual(response.data['commune'], 'Diamniadio')

    def test_offre_marche_refuse_recolte_d_un_autre_producteur(self):
        autre = User.objects.create_user(username='autre_producteur', password='Autre@12345')
        autre_profil = Agriculteur.objects.create(user=autre, region='dakar')
        recolte = Recolte.objects.create(agriculteur=autre_profil, culture=self.culture, quantite_kg=100, date_recolte='2026-10-01')
        response = self.client.post('/api/marketplace/offres/', {
            'recolte': recolte.id, 'quantite_kg': '20', 'prix_kg_fcfa': '300',
        }, format='json')
        self.assertEqual(response.status_code, 400)

    def test_commande_livraison_refuse_survente(self):
        from .models import OffreRecolte
        producteur_recolte = Recolte.objects.create(agriculteur=self.profil, culture=self.culture, quantite_kg=100, date_recolte='2026-10-01')
        offre = OffreRecolte.objects.create(recolte=producteur_recolte, quantite_kg=20, prix_kg_fcfa=400, commune='Thiès')
        acheteur = User.objects.create_user(username='acheteur', password='Acheteur@12345')
        self.client.force_authenticate(acheteur)
        response = self.client.post('/api/marketplace/commandes/', {
            'offre': offre.id, 'quantite_kg': '25', 'telephone_contact': '+221770000000',
            'adresse_livraison': 'Marché de Thiès',
        }, format='json')
        self.assertEqual(response.status_code, 400)


    def test_creation_recolte_cree_evenement_traceabilite(self):
        from .models import EvenementTraceabilite
        recolte = Recolte.objects.create(
            agriculteur=self.profil, culture=self.culture,
            quantite_kg=80, date_recolte='2026-11-01',
            lieu_stockage='Magasin principal'
        )
        event = EvenementTraceabilite.objects.get(recolte=recolte)
        self.assertEqual(event.type_evenement, 'creation')
        self.assertEqual(event.lieu, 'Magasin principal')
        self.assertEqual(float(event.quantite_kg), 80.0)

    def test_declaration_perte_est_tracee(self):
        from .models import EvenementTraceabilite
        recolte = Recolte.objects.create(
            agriculteur=self.profil, culture=self.culture,
            quantite_kg=100, date_recolte='2026-11-01'
        )
        Perte.objects.create(
            recolte=recolte, type_perte='stockage',
            quantite_perdue_kg=5, description='Humidité excessive'
        )
        event = EvenementTraceabilite.objects.get(recolte=recolte, type_evenement='perte')
        self.assertIn('Humidité excessive', event.description)

    def test_api_traceabilite_isolee_par_utilisateur(self):
        from .models import EvenementTraceabilite
        autre = User.objects.create_user(username='autre_trace', password='Autre@12345')
        autre_profil = Agriculteur.objects.create(user=autre, region='dakar')
        recolte = Recolte.objects.create(
            agriculteur=autre_profil, culture=self.culture,
            quantite_kg=50, date_recolte='2026-11-01'
        )
        response = self.client.get(f'/api/traceabilite/evenements/?recolte={recolte.id}')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data['results']), 0)

    def test_api_traceabilite_refuse_recolte_tiers(self):
        autre = User.objects.create_user(username='autre_trace2', password='Autre@12345')
        autre_profil = Agriculteur.objects.create(user=autre, region='dakar')
        recolte = Recolte.objects.create(
            agriculteur=autre_profil, culture=self.culture,
            quantite_kg=50, date_recolte='2026-11-01'
        )
        response = self.client.post('/api/traceabilite/evenements/', {
            'recolte': recolte.id, 'type_evenement': 'controle',
            'description': 'Contrôle visuel effectué'
        }, format='json')
        self.assertEqual(response.status_code, 400)

    def test_numero_lot_et_quantite_restante(self):
        recolte = Recolte.objects.create(
            agriculteur=self.profil, culture=self.culture,
            quantite_kg=100, date_recolte='2026-11-01'
        )
        Perte.objects.create(recolte=recolte, type_perte='stockage', quantite_perdue_kg=12)
        self.assertEqual(recolte.numero_lot, f'SMB-2026-{recolte.pk:05d}')
        self.assertEqual(float(recolte.quantite_restante_kg), 88.0)

    def test_detail_recolte_affiche_et_ajoute_evenement(self):
        from .models import EvenementTraceabilite
        recolte = Recolte.objects.create(
            agriculteur=self.profil, culture=self.culture,
            quantite_kg=100, date_recolte='2026-11-01'
        )
        response = self.client.get(f'/recoltes/{recolte.pk}/')
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, recolte.numero_lot)
        response = self.client.post(f'/recoltes/{recolte.pk}/', {
            'type_evenement': 'controle',
            'description': 'Contrôle visuel effectué',
            'lieu': 'Magasin principal',
        })
        self.assertEqual(response.status_code, 302)
        self.assertTrue(EvenementTraceabilite.objects.filter(
            recolte=recolte, type_evenement='controle',
            description='Contrôle visuel effectué'
        ).exists())

    def test_modification_lieu_et_quantite_cree_deux_evenements(self):
        from .models import EvenementTraceabilite
        recolte = Recolte.objects.create(
            agriculteur=self.profil, culture=self.culture,
            quantite_kg=100, date_recolte='2026-11-01',
            lieu_stockage='Magasin A'
        )
        recolte.lieu_stockage = 'Magasin B'
        recolte.quantite_kg = 90
        recolte.save()
        self.assertTrue(EvenementTraceabilite.objects.filter(
            recolte=recolte, type_evenement='deplacement'
        ).exists())
        self.assertTrue(EvenementTraceabilite.objects.filter(
            recolte=recolte, type_evenement='mise_a_jour'
        ).exists())

    def test_transfert_perte_est_trace_sur_les_deux_lots(self):
        from .models import EvenementTraceabilite
        lot_a = Recolte.objects.create(
            agriculteur=self.profil, culture=self.culture,
            quantite_kg=100, date_recolte='2026-11-01'
        )
        lot_b = Recolte.objects.create(
            agriculteur=self.profil, culture=self.culture,
            quantite_kg=80, date_recolte='2026-11-02'
        )
        perte = Perte.objects.create(
            recolte=lot_a, type_perte='stockage', quantite_perdue_kg=8
        )
        perte.recolte = lot_b
        perte.save()
        self.assertTrue(EvenementTraceabilite.objects.filter(
            recolte=lot_a, description__icontains='rattachée au lot'
        ).exists())
        self.assertTrue(EvenementTraceabilite.objects.filter(
            recolte=lot_b, description__icontains='transférée depuis le lot'
        ).exists())

    def test_suppression_recolte_preserve_historique(self):
        from django.db.models.deletion import ProtectedError
        from .models import EvenementTraceabilite
        recolte = Recolte.objects.create(
            agriculteur=self.profil, culture=self.culture,
            quantite_kg=60, date_recolte='2026-11-03'
        )
        with self.assertRaises(ProtectedError):
            recolte.delete()
        self.assertTrue(EvenementTraceabilite.objects.filter(recolte=recolte).exists())
    def test_recolte_refuse_diminution_sous_pertes_existantes(self):
        from .forms import RecolteForm
        recolte = Recolte.objects.create(
            agriculteur=self.profil, culture=self.culture,
            quantite_kg=100, date_recolte='2026-08-01'
        )
        Perte.objects.create(recolte=recolte, type_perte='stockage', quantite_perdue_kg=40)
        form = RecolteForm(data={
            'culture': self.culture.pk, 'quantite_kg': '30',
            'date_recolte': '2026-08-01', 'lieu_stockage': '', 'notes': ''
        }, instance=recolte)
        self.assertFalse(form.is_valid())
        self.assertIn('quantite_kg', form.errors)

    def test_perte_refuse_depassement_cumulatif(self):
        from .forms import PerteForm
        recolte = Recolte.objects.create(
            agriculteur=self.profil, culture=self.culture,
            quantite_kg=100, date_recolte='2026-08-01'
        )
        Perte.objects.create(recolte=recolte, type_perte='stockage', quantite_perdue_kg=70)
        form = PerteForm(data={
            'recolte': recolte.pk, 'type_perte': 'transport',
            'quantite_perdue_kg': '31', 'description': '', 'statut': 'signalee'
        }, agriculteur=self.profil)
        self.assertFalse(form.is_valid())
        self.assertIn('quantite_perdue_kg', form.errors)

    def test_modification_date_recolte_est_tracee(self):
        from .models import EvenementTraceabilite
        recolte = Recolte.objects.create(
            agriculteur=self.profil, culture=self.culture,
            quantite_kg=50, date_recolte='2026-11-01'
        )
        recolte.date_recolte = '2026-11-02'
        recolte.save()
        self.assertTrue(EvenementTraceabilite.objects.filter(
            recolte=recolte, type_evenement='mise_a_jour',
            description__icontains='Date de récolte modifiée'
        ).exists())

