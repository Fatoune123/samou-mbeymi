from django.urls import path
from django.contrib.auth.views import LogoutView
from . import views

urlpatterns = [
    # Pages publiques
    path('', views.accueil, name='accueil'),
    path('inscription/', views.inscription, name='inscription'),
    path('connexion/', views.ConnexionView.as_view(), name='connexion'),
    path('deconnexion/', LogoutView.as_view(), name='deconnexion'),
    
    # Tableau de bord
    path('tableau-de-bord/', views.tableau_bord, name='tableau_bord'),
    
    # Gestion des récoltes
    path('recoltes/', views.liste_recoltes, name='liste_recoltes'),
    path('recoltes/ajouter/', views.ajouter_recolte, name='ajouter_recolte'),
    path('recoltes/<int:pk>/', views.detail_recolte, name='detail_recolte'),
    path('recoltes/<int:pk>/modifier/', views.modifier_recolte, name='modifier_recolte'),
    path('recoltes/<int:pk>/supprimer/', views.supprimer_recolte, name='supprimer_recolte'),
    
    # Scanner IA (avec caméra)
    path('scanner/', views.scanner_recolte, name='scanner_recolte'),
    path('stockage/', views.liste_stockages, name='liste_stockages'),
    path('localisation/', views.localisation, name='localisation'),
    path('localisation/enregistrer/', views.enregistrer_localisation, name='enregistrer_localisation'),
    path('prediction/', views.prediction_risque, name='prediction_risque'),
    path('rapport/', views.rapport, name='rapport'),
    path('rapport/export/', views.export_rapport_csv, name='export_rapport_csv'),
    
    # Gestion des pertes
    path('pertes/', views.liste_pertes, name='liste_pertes'),
    path('pertes/signaler/', views.signaler_perte, name='signaler_perte'),
    path('pertes/<int:pk>/modifier/', views.modifier_perte, name='modifier_perte'),
    path('pertes/<int:pk>/supprimer/', views.supprimer_perte, name='supprimer_perte'),
    
    # 🔥 NOUVEAU : API pour l'analyse IA (utilisée par la caméra)
    path('api/analyser-recolte/', views.analyser_recolte_api, name='analyser_recolte_api'),
]