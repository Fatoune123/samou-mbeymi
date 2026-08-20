from datetime import date
from django.db.models import Sum, Count
from django.http import StreamingHttpResponse
from rest_framework import viewsets, generics, permissions, status
from rest_framework.authtoken.models import Token
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Agriculteur, Culture, Recolte, Perte, Stockage
from .serializers import (
    AgriculteurSerializer, InscriptionSerializer, CultureSerializer,
    RecolteSerializer, PerteSerializer, StockageSerializer,
)


class HealthAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        return Response({'status': 'ok', 'application': 'Samou Mbeymi', 'version': '5.0'})


class InscriptionAPIView(generics.CreateAPIView):
    serializer_class = InscriptionSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        token, _ = Token.objects.get_or_create(user=user)
        return Response({'token': token.key, 'user_id': user.pk, 'username': user.username}, status=status.HTTP_201_CREATED)


class ConnexionAPIView(ObtainAuthToken):
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.serializer_class(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        token, _ = Token.objects.get_or_create(user=user)
        agriculteur = Agriculteur.objects.filter(user=user).first()
        return Response({'token': token.key, 'user_id': user.pk, 'username': user.username,
                         'nom_exploitation': agriculteur.nom_exploitation if agriculteur else ''})


class ProfilAPIView(generics.RetrieveUpdateAPIView):
    serializer_class = AgriculteurSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return Agriculteur.objects.get(user=self.request.user)


class CultureViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Culture.objects.all()
    serializer_class = CultureSerializer
    permission_classes = [permissions.IsAuthenticated]


class RecolteViewSet(viewsets.ModelViewSet):
    serializer_class = RecolteSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        agriculteur = Agriculteur.objects.get(user=self.request.user)
        qs = Recolte.objects.filter(agriculteur=agriculteur).select_related('culture')
        search = self.request.query_params.get('search', '').strip()
        if search:
            qs = qs.filter(culture__nom__icontains=search)
        return qs

    def get_serializer_context(self):
        return {'request': self.request}


class PerteViewSet(viewsets.ModelViewSet):
    serializer_class = PerteSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        agriculteur = Agriculteur.objects.get(user=self.request.user)
        qs = Perte.objects.filter(recolte__agriculteur=agriculteur).select_related('recolte', 'recolte__culture')
        statut = self.request.query_params.get('statut')
        type_perte = self.request.query_params.get('type_perte')
        if statut:
            qs = qs.filter(statut=statut)
        if type_perte:
            qs = qs.filter(type_perte=type_perte)
        return qs

    def get_serializer_context(self):
        return {'request': self.request}


class StockageViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Stockage.objects.filter(disponible=True)
    serializer_class = StockageSerializer
    permission_classes = [permissions.IsAuthenticated]


class PredireRisqueAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        from datetime import datetime
        from .ia.engine import predire_risque
        agriculteur = Agriculteur.objects.get(user=request.user)
        try:
            date_recolte = datetime.strptime(request.data.get('date_recolte'), '%Y-%m-%d')
            quantite_kg = float(request.data.get('quantite_kg', 0))
        except (TypeError, ValueError):
            return Response({'detail': 'Date ou quantité invalide.'}, status=400)
        if quantite_kg <= 0:
            return Response({'detail': 'La quantité doit être supérieure à 0 kg.'}, status=400)
        return Response(predire_risque(
            culture_nom=request.data.get('culture', ''), region=agriculteur.region,
            mois=date_recolte.month, quantite_kg=quantite_kg,
            lieu_stockage=request.data.get('lieu_stockage', ''),
        ))


class ScannerPhotoAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        import os
        import tempfile
        from .ia.engine import analyser_photo
        photo = request.FILES.get('photo')
        if not photo:
            return Response({'detail': "Aucune photo fournie (champ 'photo' requis)."}, status=400)
        with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as tmp:
            for chunk in photo.chunks():
                tmp.write(chunk)
            tmp_path = tmp.name
        try:
            return Response(analyser_photo(tmp_path))
        finally:
            os.unlink(tmp_path)


class ModeleIAInfoAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from .ia.engine import _charger
        data = _charger()
        return Response({
            'type_modele': 'Random Forest Classifier',
            'precision_test': round(float(data.get('precision_test', data.get('metrics', {}).get('accuracy', 0))) * 100, 2),
            'metrics': {k: round(float(v) * 100, 2) for k, v in data.get('metrics', {}).items()},
            'importance_variables': data.get('importance', {}),
            'dataset': f"{data.get('n_synthetiques', 0)} synthétiques + {data.get('n_reelles', 0)} réelles",
            'variables': ['culture', 'région', 'mois', 'quantité_kg', 'stockage'],
            'vision': 'Analyse colorimétrique indicative des zones ternies/brunes',
            'limite': 'Le scanner visuel est une aide à la décision et non un diagnostic certifié.',
        })


def _dashboard_data(agriculteur):
    recoltes = Recolte.objects.filter(agriculteur=agriculteur, quantite_kg__gt=0)
    pertes = Perte.objects.filter(recolte__agriculteur=agriculteur, quantite_perdue_kg__gt=0)
    total_recolte = float(recoltes.aggregate(t=Sum('quantite_kg'))['t'] or 0)
    total_perte = float(pertes.aggregate(t=Sum('quantite_perdue_kg'))['t'] or 0)
    taux = round(total_perte / total_recolte * 100, 1) if total_recolte else 0
    niveau = 'eleve' if taux > 12 else ('moyen' if taux > 5 else 'faible')
    recommandation = {
        'eleve': 'Priorisez le contrôle du stockage et inspectez les récoltes récentes.',
        'moyen': 'Surveillez les causes récurrentes et renforcez la prévention.',
        'faible': 'Les indicateurs sont encourageants. Continuez le suivi préventif.',
    }[niveau]
    labels = dict(Perte.TYPE_PERTE_CHOICES)
    causes = []
    for p in pertes.values('type_perte').annotate(total=Sum('quantite_perdue_kg'), nb=Count('id')).order_by('-total'):
        causes.append({'type': p['type_perte'], 'label': labels.get(p['type_perte'], p['type_perte']),
                       'total_kg': round(float(p['total'] or 0), 1), 'nombre': p['nb']})

    mois_courant = date.today().replace(day=1)
    evolution = []
    max_volume = 1.0
    for i in range(11, -1, -1):
        idx = mois_courant.year * 12 + mois_courant.month - 1 - i
        annee, mois = divmod(idx, 12)
        debut = date(annee, mois + 1, 1)
        fin = date(annee + 1, 1, 1) if mois == 11 else date(annee, mois + 2, 1)
        production = float(recoltes.filter(date_recolte__gte=debut, date_recolte__lt=fin).aggregate(t=Sum('quantite_kg'))['t'] or 0)
        perte = float(pertes.filter(date_signalement__gte=debut, date_signalement__lt=fin).aggregate(t=Sum('quantite_perdue_kg'))['t'] or 0)
        max_volume = max(max_volume, production, perte)
        evolution.append({'mois': debut.strftime('%b').capitalize(), 'production_kg': round(production, 1), 'perte_kg': round(perte, 1)})
    for point in evolution:
        point['production_pct'] = round(point['production_kg'] / max_volume * 100, 1)
        point['perte_pct'] = round(point['perte_kg'] / max_volume * 100, 1)

    alertes = []
    if not recoltes.exists():
        alertes.append({'niveau': 'info', 'titre': 'Commencez votre suivi', 'message': 'Enregistrez votre première récolte pour alimenter les indicateurs.'})
    if taux > 12:
        alertes.append({'niveau': 'danger', 'titre': 'Taux de perte élevé', 'message': f'{taux}% de la production enregistrée est actuellement perdue.'})
    elif taux > 5:
        alertes.append({'niveau': 'warning', 'titre': 'Surveillance recommandée', 'message': f'Le taux de perte atteint {taux}%. Analysez les causes principales.'})
    if not alertes:
        alertes.append({'niveau': 'success', 'titre': 'Situation maîtrisée', 'message': 'Aucune alerte critique sur les données enregistrées.'})

    recent_recoltes = list(recoltes.order_by('-date_recolte')[:5].values('id', 'culture__nom', 'quantite_kg', 'date_recolte'))
    recent_pertes = list(pertes.order_by('-date_signalement')[:5].values('id', 'recolte__culture__nom', 'quantite_perdue_kg', 'type_perte', 'statut', 'date_signalement'))
    return {
        'nb_recoltes': recoltes.count(), 'nb_pertes': pertes.count(),
        'total_recolte_kg': round(total_recolte, 1), 'total_perte_kg': round(total_perte, 1),
        'taux_perte': taux, 'rendement_conserve': round(max(0, 100 - taux), 1),
        'niveau_risque': niveau, 'recommandation': recommandation,
        'pertes_par_type': causes, 'evolution_mensuelle': evolution, 'alertes': alertes,
        'recoltes_recentes': recent_recoltes, 'pertes_recentes': recent_pertes,
    }


class TableauBordAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(_dashboard_data(Agriculteur.objects.get(user=request.user)))


class RapportCSVAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        import csv
        from django.http import HttpResponse
        agriculteur = Agriculteur.objects.get(user=request.user)
        recoltes = Recolte.objects.filter(agriculteur=agriculteur, quantite_kg__gt=0).select_related('culture')
        response = HttpResponse(content_type='text/csv; charset=utf-8-sig')
        response['Content-Disposition'] = 'attachment; filename="samou_mbeymi_rapport.csv"'
        writer = csv.writer(response, delimiter=';', lineterminator='\r\n')
        writer.writerow(['Culture','Date de récolte','Quantité récoltée (kg)','Pertes (kg)','Taux de perte (%)','Lieu de stockage'])
        for r in recoltes:
            writer.writerow([r.culture.nom, r.date_recolte.strftime('%d/%m/%Y'), f'{float(r.quantite_kg):.2f}'.replace('.',','), f'{float(r.total_pertes_kg):.2f}'.replace('.',','), f'{r.pourcentage_perte:.1f}'.replace('.',','), r.lieu_stockage])
        return response

class ModeleIATrainAPIView(APIView):
    permission_classes = [permissions.IsAdminUser]
    def post(self, request):
        from .ia.engine import entrainer
        return Response(entrainer(n_exemples=int(request.data.get('n',3000)), inclure_reel=True))
