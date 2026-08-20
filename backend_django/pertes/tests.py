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
