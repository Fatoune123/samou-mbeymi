from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import api_views

router = DefaultRouter()
router.register('cultures', api_views.CultureViewSet, basename='api-culture')
router.register('recoltes', api_views.RecolteViewSet, basename='api-recolte')
router.register('pertes', api_views.PerteViewSet, basename='api-perte')
router.register('stockages', api_views.StockageViewSet, basename='api-stockage')

urlpatterns = [
    path('health/', api_views.HealthAPIView.as_view(), name='api-health'),
    path('inscription/', api_views.InscriptionAPIView.as_view(), name='api-inscription'),
    path('connexion/', api_views.ConnexionAPIView.as_view(), name='api-connexion'),
    path('profil/', api_views.ProfilAPIView.as_view(), name='api-profil'),
    path('tableau-de-bord/', api_views.TableauBordAPIView.as_view(), name='api-tableau-bord'),
    path('rapport.csv', api_views.RapportCSVAPIView.as_view(), name='api-rapport-csv'),
    path('ia/info/', api_views.ModeleIAInfoAPIView.as_view(), name='api-ia-info'),
    path('ia/entrainer/', api_views.ModeleIATrainAPIView.as_view(), name='api-ia-entrainer'),
    path('ia/predire-risque/', api_views.PredireRisqueAPIView.as_view(), name='api-ia-predire-risque'),
    path('ia/scanner-photo/', api_views.ScannerPhotoAPIView.as_view(), name='api-ia-scanner-photo'),
    path('', include(router.urls)),
]
