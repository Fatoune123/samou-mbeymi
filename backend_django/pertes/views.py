from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import login
from django.contrib.auth.decorators import login_required
from django.contrib.auth.views import LoginView
from django.contrib import messages
from django.db.models import Sum, Count
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt, ensure_csrf_cookie
from django.core.files.base import ContentFile
import json
import base64
import tempfile
import os
import uuid

from .models import Agriculteur, Recolte, Perte, Stockage
from .forms import InscriptionForm, RecolteForm, PerteForm, PredictionForm


def accueil(request):
    """Page d'accueil publique de présentation de l'application."""
    stats = {
        'total_agriculteurs': Agriculteur.objects.count(),
        'total_recoltes': Recolte.objects.count(),
        'total_pertes_kg': Perte.objects.filter(quantite_perdue_kg__gt=0).aggregate(t=Sum('quantite_perdue_kg'))['t'] or 0,
    }
    return render(request, 'pertes/accueil.html', {'stats': stats})


def inscription(request):
    if request.user.is_authenticated:
        return redirect('tableau_bord')
    if request.method == 'POST':
        form = InscriptionForm(request.POST)
        if form.is_valid():
            user = form.save()
            login(request, user)
            messages.success(request, "Bienvenue ! Votre compte a été créé avec succès.")
            return redirect('tableau_bord')
    else:
        form = InscriptionForm()
    return render(request, 'pertes/inscription.html', {'form': form})


class ConnexionView(LoginView):
    template_name = 'pertes/connexion.html'


@login_required
def tableau_bord(request):
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    recoltes = Recolte.objects.filter(agriculteur=agriculteur, quantite_kg__gt=0)
    pertes = Perte.objects.filter(recolte__agriculteur=agriculteur, quantite_perdue_kg__gt=0)

    total_recolte_kg = recoltes.aggregate(t=Sum('quantite_kg'))['t'] or 0
    total_perte_kg = pertes.aggregate(t=Sum('quantite_perdue_kg'))['t'] or 0
    taux_perte = round((float(total_perte_kg) / float(total_recolte_kg)) * 100, 1) if total_recolte_kg else 0

    pertes_par_type = (
        pertes.values('type_perte')
        .annotate(total=Sum('quantite_perdue_kg'), nb=Count('id'))
        .order_by('-total')
    )
    types_labels = dict(Perte.TYPE_PERTE_CHOICES)
    pertes_par_type = [
        {
            'label': types_labels.get(p['type_perte'], p['type_perte']),
            'total': float(p['total'] or 0),
            'nb': p['nb'],
        }
        for p in pertes_par_type
    ]

    recoltes_recentes = recoltes.order_by('-date_recolte')[:5]
    pertes_recentes = pertes.order_by('-date_signalement')[:5]

    # Analyse mensuelle des 12 derniers mois pour le nouveau centre de pilotage.
    from datetime import date
    mois_courant = date.today().replace(day=1)
    brut = []
    max_volume = 1.0
    for i in range(11, -1, -1):
        idx = mois_courant.year * 12 + (mois_courant.month - 1) - i
        annee, mois = divmod(idx, 12)
        debut = date(annee, mois + 1, 1)
        if mois == 11:
            fin = date(annee + 1, 1, 1)
        else:
            fin = date(annee, mois + 2, 1)
        production = float(recoltes.filter(date_recolte__gte=debut, date_recolte__lt=fin).aggregate(t=Sum('quantite_kg'))['t'] or 0)
        perte = float(pertes.filter(date_signalement__gte=debut, date_signalement__lt=fin).aggregate(t=Sum('quantite_perdue_kg'))['t'] or 0)
        max_volume = max(max_volume, production, perte)
        brut.append({'date': debut, 'production': production, 'perte': perte})
    evolution_mensuelle = [{
        'label': x['date'].strftime('%b').capitalize(),
        'production': round(x['production'], 1),
        'perte': round(x['perte'], 1),
        'production_pct': round((x['production'] / max_volume) * 100, 1),
        'perte_pct': round((x['perte'] / max_volume) * 100, 1),
    } for x in brut]

    max_cause = max([x['total'] for x in pertes_par_type], default=1)
    for x in pertes_par_type:
        x['pct'] = round((x['total'] / max_cause) * 100, 1)

    rendement_conserve = round(max(0.0, 100 - taux_perte), 1)
    if taux_perte > 12:
        niveau_risque, niveau_risque_affiche = 'eleve', 'Élevé'
        recommandation_ia = 'Priorisez le stockage et inspectez les récoltes les plus récentes. Le scanner IA peut aider à détecter des signes visuels à surveiller.'
    elif taux_perte > 5:
        niveau_risque, niveau_risque_affiche = 'moyen', 'Moyen'
        recommandation_ia = 'Votre situation est à surveiller. Enregistrez précisément les causes de pertes pour identifier le principal levier d’amélioration.'
    else:
        niveau_risque, niveau_risque_affiche = 'faible', 'Faible'
        recommandation_ia = 'Les indicateurs sont encourageants. Continuez à documenter les récoltes et utilisez l’analyse IA en prévention.'

    context = {
        'agriculteur': agriculteur,
        'total_recolte_kg': total_recolte_kg,
        'total_perte_kg': total_perte_kg,
        'taux_perte': taux_perte,
        'nb_recoltes': recoltes.count(),
        'nb_pertes': pertes.count(),
        'pertes_par_type': pertes_par_type,
        'recoltes_recentes': recoltes_recentes,
        'pertes_recentes': pertes_recentes,
        'evolution_mensuelle': evolution_mensuelle,
        'rendement_conserve': rendement_conserve,
        'niveau_risque': niveau_risque,
        'niveau_risque_affiche': niveau_risque_affiche,
        'recommandation_ia': recommandation_ia,
    }
    return render(request, 'pertes/tableau_bord.html', context)


@login_required
def liste_recoltes(request):
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    recoltes = Recolte.objects.filter(agriculteur=agriculteur, quantite_kg__gt=0).select_related('culture')
    q = request.GET.get('q', '').strip()
    if q:
        recoltes = recoltes.filter(culture__nom__icontains=q)
    culture = request.GET.get('culture', '').strip()
    if culture:
        recoltes = recoltes.filter(culture_id=culture)
    return render(request, 'pertes/liste_recoltes.html', {'recoltes': recoltes, 'cultures': __import__('pertes.models', fromlist=['Culture']).Culture.objects.all(), 'q': q, 'culture': culture})


@login_required
def ajouter_recolte(request):
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    if request.method == 'POST':
        form = RecolteForm(request.POST)
        if form.is_valid():
            recolte = form.save(commit=False)
            recolte.agriculteur = agriculteur
            recolte.save()
            messages.success(request, "Récolte enregistrée avec succès.")
            return redirect('liste_recoltes')
    else:
        form = RecolteForm()
    return render(request, 'pertes/formulaire_recolte.html', {'form': form, 'titre': 'Ajouter une récolte'})


@login_required
def detail_recolte(request, pk):
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    recolte = get_object_or_404(Recolte, pk=pk, agriculteur=agriculteur)

    from .ia.engine import predire_risque
    try:
        prediction = predire_risque(
            culture_nom=recolte.culture.nom,
            region=agriculteur.region,
            mois=recolte.date_recolte.month,
            quantite_kg=float(recolte.quantite_kg),
            lieu_stockage=recolte.lieu_stockage,
        )
        prediction['probabilite_principale'] = round(prediction['probabilites'][prediction['risque']] * 100, 0)
    except Exception:
        prediction = None

    return render(request, 'pertes/detail_recolte.html', {'recolte': recolte, 'prediction': prediction})


@login_required
def modifier_recolte(request, pk):
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    recolte = get_object_or_404(Recolte, pk=pk, agriculteur=agriculteur)
    if request.method == 'POST':
        form = RecolteForm(request.POST, instance=recolte)
        if form.is_valid():
            form.save()
            messages.success(request, "Récolte modifiée avec succès.")
            return redirect('detail_recolte', pk=recolte.pk)
    else:
        form = RecolteForm(instance=recolte)
    return render(request, 'pertes/formulaire_recolte.html', {'form': form, 'titre': 'Modifier la récolte'})


@login_required
def supprimer_recolte(request, pk):
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    recolte = get_object_or_404(Recolte, pk=pk, agriculteur=agriculteur)
    if request.method == 'POST':
        recolte.delete()
        messages.success(request, "Récolte supprimée.")
        return redirect('liste_recoltes')
    return render(request, 'pertes/confirmer_suppression.html', {'objet': recolte, 'type_objet': 'la récolte'})


@login_required
def prediction_risque(request):
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    resultat = None
    form = PredictionForm(request.POST or None)
    if request.method == 'POST' and form.is_valid():
        from .ia.engine import predire_risque
        recolte = form.cleaned_data['culture']
        date_recolte = form.cleaned_data['date_recolte']
        resultat = predire_risque(
            culture_nom=recolte.nom, region=agriculteur.region, mois=date_recolte.month,
            quantite_kg=float(form.cleaned_data['quantite_kg']),
            lieu_stockage=form.cleaned_data['lieu_stockage'],
        )
        resultat['probabilite_principale'] = round(resultat['probabilites'][resultat['risque']] * 100, 1)
    return render(request, 'pertes/prediction.html', {'form': form, 'resultat': resultat, 'agriculteur': agriculteur})

@login_required
def localisation(request):
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    return render(request, 'pertes/localisation.html', {'agriculteur': agriculteur})

@login_required
def enregistrer_localisation(request):
    if request.method != 'POST':
        return JsonResponse({'detail': 'Méthode non autorisée'}, status=405)
    try:
        data = json.loads(request.body or '{}')
        lat, lng = float(data.get('latitude')), float(data.get('longitude'))
        if not (-90 <= lat <= 90 and -180 <= lng <= 180):
            raise ValueError
        agriculteur = get_object_or_404(Agriculteur, user=request.user)
        agriculteur.latitude, agriculteur.longitude = lat, lng
        agriculteur.localisation_nom = str(data.get('nom', '')).strip()[:150]
        agriculteur.save(update_fields=['latitude', 'longitude', 'localisation_nom'])
        return JsonResponse({'ok': True, 'latitude': lat, 'longitude': lng, 'nom': agriculteur.localisation_nom})
    except (TypeError, ValueError, json.JSONDecodeError):
        return JsonResponse({'ok': False, 'detail': 'Coordonnées invalides.'}, status=400)

@login_required
def scanner_recolte(request):
    """Phase 6 — Module IA : scan visuel d'une photo de récolte, lié à une récolte précise."""
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    recoltes = Recolte.objects.filter(agriculteur=agriculteur, quantite_kg__gt=0).select_related('culture')
    resultat = None
    recolte_selectionnee = None
    quantite_estimee_kg = None

    if request.method == 'POST':
        recolte_id = request.POST.get('recolte')
        if recolte_id:
            recolte_selectionnee = get_object_or_404(Recolte, pk=recolte_id, agriculteur=agriculteur)

        if request.FILES.get('photo'):
            import tempfile, os
            from .ia.engine import analyser_photo

            photo = request.FILES['photo']
            with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as tmp:
                for chunk in photo.chunks():
                    tmp.write(chunk)
                tmp_path = tmp.name
            try:
                resultat = analyser_photo(tmp_path)
            finally:
                os.unlink(tmp_path)

            if recolte_selectionnee:
                quantite_estimee_kg = round(
                    float(recolte_selectionnee.quantite_kg) * resultat['taux_zones_ternies'] / 100, 1
                )

    return render(request, 'pertes/scanner_recolte.html', {
        'resultat': resultat,
        'recoltes': recoltes,
        'recolte_selectionnee': recolte_selectionnee,
        'quantite_estimee_kg': quantite_estimee_kg,
    })


@login_required
@csrf_exempt
def analyser_recolte_api(request):
    """API qui reçoit une image base64, l'analyse et retourne les résultats en JSON."""
    if request.method != 'POST':
        return JsonResponse({'error': 'Méthode non autorisée'}, status=405)

    try:
        data = json.loads(request.body)
        recolte_id = data.get('recolte_id')
        image_base64 = data.get('image')  # "data:image/jpeg;base64,..."

        # Vérifier que la récolte existe et appartient à l'utilisateur
        agriculteur = get_object_or_404(Agriculteur, user=request.user)
        recolte = get_object_or_404(Recolte, pk=recolte_id, agriculteur=agriculteur)

        # Extraire le base64 pur
        format, imgstr = image_base64.split(';base64,')
        img_bytes = base64.b64decode(imgstr)

        # Sauvegarder temporairement l'image pour l'analyse
        with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as tmp:
            tmp.write(img_bytes)
            tmp_path = tmp.name

        # Appeler le moteur d'analyse
        from .ia.engine import analyser_photo
        resultat = analyser_photo(tmp_path)

        # Supprimer le fichier temporaire
        os.unlink(tmp_path)

        # Calculer la quantité estimée
        quantite_estimee_kg = round(
            float(recolte.quantite_kg) * resultat['taux_zones_ternies'] / 100, 1
        )

        # (Optionnel) Sauvegarder l'image scannée dans la récolte
        # recolte.image_scannee.save(f"scan_{recolte.pk}.jpg", ContentFile(img_bytes))
        # recolte.save()

        return JsonResponse({
            'taux_zones_ternies': resultat['taux_zones_ternies'],
            'categorie': resultat['categorie'],
            'message': resultat['message'],
            'quantite_estimee_kg': quantite_estimee_kg,
            'quantite_totale': float(recolte.quantite_kg),
        })

    except Recolte.DoesNotExist:
        return JsonResponse({'error': 'Récolte introuvable'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@login_required
def liste_pertes(request):
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    pertes = Perte.objects.filter(recolte__agriculteur=agriculteur, quantite_perdue_kg__gt=0).select_related('recolte', 'recolte__culture')
    q = request.GET.get('q', '').strip()
    statut = request.GET.get('statut', '').strip()
    type_perte = request.GET.get('type_perte', '').strip()
    if q: pertes = pertes.filter(recolte__culture__nom__icontains=q)
    if statut: pertes = pertes.filter(statut=statut)
    if type_perte: pertes = pertes.filter(type_perte=type_perte)
    return render(request, 'pertes/liste_pertes.html', {'pertes': pertes, 'q': q, 'statut': statut, 'type_perte': type_perte, 'statuts': Perte.STATUT_CHOICES, 'types': Perte.TYPE_PERTE_CHOICES})

@login_required
def liste_stockages(request):
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    stockages = Stockage.objects.filter(disponible=True).order_by('region','nom')
    region = request.GET.get('region', '').strip()
    if region:
        stockages = stockages.filter(region=region)
    else:
        stockages = list(stockages)
        preferes = [s for s in stockages if s.region == agriculteur.region]
        autres = [s for s in stockages if s.region != agriculteur.region]
        stockages = preferes + autres
    return render(request, 'pertes/liste_stockages.html', {'stockages': stockages, 'agriculteur': agriculteur, 'regions': __import__('pertes.models', fromlist=['REGIONS_SENEGAL']).REGIONS_SENEGAL, 'region': region})


@login_required
def signaler_perte(request):
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    if not Recolte.objects.filter(agriculteur=agriculteur).exists():
        messages.warning(request, "Vous devez d'abord enregistrer une récolte avant de signaler une perte.")
        return redirect('ajouter_recolte')
    if request.method == 'POST':
        form = PerteForm(request.POST, request.FILES, agriculteur=agriculteur)
        if form.is_valid():
            form.save()
            messages.success(request, "Perte signalée avec succès.")
            return redirect('liste_pertes')
    else:
        initial = {}
        if request.GET.get('recolte'):
            initial['recolte'] = request.GET.get('recolte')
        if request.GET.get('quantite'):
            initial['quantite_perdue_kg'] = request.GET.get('quantite')
        form = PerteForm(agriculteur=agriculteur, initial=initial)
    return render(request, 'pertes/formulaire_perte.html', {'form': form, 'titre': 'Signaler une perte'})


@login_required
def modifier_perte(request, pk):
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    perte = get_object_or_404(Perte, pk=pk, recolte__agriculteur=agriculteur)
    if request.method == 'POST':
        form = PerteForm(request.POST, request.FILES, instance=perte, agriculteur=agriculteur)
        if form.is_valid():
            form.save()
            messages.success(request, "Perte modifiée avec succès.")
            return redirect('liste_pertes')
    else:
        form = PerteForm(instance=perte, agriculteur=agriculteur)
    return render(request, 'pertes/formulaire_perte.html', {'form': form, 'titre': 'Modifier la perte'})


@login_required
def supprimer_perte(request, pk):
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    perte = get_object_or_404(Perte, pk=pk, recolte__agriculteur=agriculteur)
    if request.method == 'POST':
        perte.delete()
        messages.success(request, "Perte supprimée.")
        return redirect('liste_pertes')
    return render(request, 'pertes/confirmer_suppression.html', {'objet': perte, 'type_objet': 'la perte'})
@login_required
def rapport(request):
    """Centre de rapports : synthèse exploitable pour le suivi et la soutenance."""
    from .api_views import _dashboard_data
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    data = _dashboard_data(agriculteur)
    return render(request, 'pertes/rapport.html', {'data': data, 'agriculteur': agriculteur})

@login_required
def export_rapport_csv(request):
    import csv
    from django.http import HttpResponse
    agriculteur = get_object_or_404(Agriculteur, user=request.user)
    recoltes = Recolte.objects.filter(agriculteur=agriculteur, quantite_kg__gt=0).select_related('culture')
    response = HttpResponse(content_type='text/csv; charset=utf-8-sig')
    response['Content-Disposition'] = 'attachment; filename="samou_mbeymi_rapport.csv"'
    writer = csv.writer(response, delimiter=';', lineterminator='\r\n')
    writer.writerow(['Culture', 'Date de récolte', 'Quantité récoltée (kg)', 'Pertes (kg)', 'Taux de perte (%)', 'Lieu de stockage'])
    for r in recoltes:
        writer.writerow([r.culture.nom, r.date_recolte.strftime('%d/%m/%Y'), f'{float(r.quantite_kg):.2f}'.replace('.',','), f'{float(r.total_pertes_kg):.2f}'.replace('.',','), f'{r.pourcentage_perte:.1f}'.replace('.',','), r.lieu_stockage])
    return response
