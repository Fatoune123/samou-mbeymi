from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import login
from django.contrib.auth.decorators import login_required
from django.contrib.auth.views import LoginView
from django.contrib import messages
from django.db.models import Sum, Count, Q
from django.db import transaction, OperationalError, ProgrammingError
from django.db.models.deletion import ProtectedError
from decimal import Decimal, InvalidOperation
from django.http import JsonResponse, Http404
from django.core.exceptions import RequestDataTooBig
from django.views.decorators.csrf import ensure_csrf_cookie
from django.core.files.base import ContentFile
import json
import base64
import binascii
import logging
import tempfile
import os
import uuid

from .models import Agriculteur, Recolte, Perte, Stockage, OffreRecolte, CommandeLivraison, EvenementTraceabilite
from .forms import InscriptionForm, RecolteForm, PerteForm, PredictionForm

MOIS_FR = ['Janv', 'Févr', 'Mars', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc']


def accueil(request):
    """Page d'accueil publique. Les statistiques ne doivent jamais empêcher
    l'affichage de la page si la base est momentanément indisponible/incomplète.
    """
    stats = {
        'total_agriculteurs': 0,
        'total_recoltes': 0,
        'total_pertes_kg': 0,
    }
    try:
        stats['total_agriculteurs'] = Agriculteur.objects.count()
        stats['total_recoltes'] = Recolte.objects.count()
        stats['total_pertes_kg'] = (
            Perte.objects.filter(quantite_perdue_kg__gt=0)
            .aggregate(t=Sum('quantite_perdue_kg'))['t'] or 0
        )
    except (OperationalError, ProgrammingError):
        # La page d'accueil reste consultable même si les tables statistiques
        # ne sont pas encore prêtes. L'erreur reste visible dans le terminal.
        import logging
        logging.getLogger(__name__).exception(
            "Impossible de calculer les statistiques de la page d'accueil."
        )
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
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
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
        'label': MOIS_FR[x['date'].month - 1],
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
        recommandation_ia = 'Priorisez le suivi des lots les plus touchés, vérifiez les conditions de stockage et documentez les causes des pertes.'
    elif taux_perte > 5:
        niveau_risque, niveau_risque_affiche = 'moyen', 'Moyen'
        recommandation_ia = 'Votre situation est à surveiller. Enregistrez précisément les causes de pertes pour identifier le principal levier d’amélioration.'
    else:
        niveau_risque, niveau_risque_affiche = 'faible', 'Faible'
        recommandation_ia = 'Les indicateurs sont encourageants. Continuez à enregistrer les récoltes, les mouvements de stockage et les contrôles des lots.'

    # Indicateurs de stockage et de traçabilité : calculés depuis les lots réels.
    lots_stockes = recoltes.exclude(lieu_stockage='').exclude(lieu_stockage__isnull=True)
    quantite_stockee_kg = sum(float(r.quantite_restante_kg) for r in lots_stockes)
    nb_lots_stockes = lots_stockes.count()
    evenements_recents = EvenementTraceabilite.objects.filter(
        recolte__agriculteur=agriculteur
    ).select_related('recolte', 'recolte__culture', 'auteur').order_by('-date_evenement')[:5]

    context = {
        'agriculteur': agriculteur,
        'quantite_stockee_kg': quantite_stockee_kg,
        'nb_lots_stockes': nb_lots_stockes,
        'evenements_recents': evenements_recents,
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
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
    recoltes = Recolte.objects.filter(agriculteur=agriculteur, quantite_kg__gt=0).select_related('culture')
    q = request.GET.get('q', '').strip()
    if q:
        # Recherche dans le nom et la description de la culture, ainsi que dans
        # les notes et le lieu de stockage. Cela permet de retrouver une récolte
        # d'oignons même si sa catégorie est enregistrée comme « Cultures maraîchères ».
        from django.db.models import Q
        recoltes = recoltes.filter(
            Q(culture__nom__icontains=q)
            | Q(culture__description__icontains=q)
            | Q(notes__icontains=q)
            | Q(lieu_stockage__icontains=q)
        ).distinct()
    culture = request.GET.get('culture', '').strip()
    if culture:
        recoltes = recoltes.filter(culture_id=culture)
    return render(request, 'pertes/liste_recoltes.html', {'recoltes': recoltes, 'cultures': __import__('pertes.models', fromlist=['Culture']).Culture.objects.all(), 'q': q, 'culture': culture})


def _lieux_stockage(agriculteur):
    """Suggestions pour le champ « Lieu de stockage » : points de stockage de la région
    de l'agriculteur, puis lieux déjà utilisés par lui. Le champ reste libre."""
    noms = list(Stockage.objects.filter(disponible=True, region=agriculteur.region).values_list('nom', flat=True))
    deja = Recolte.objects.filter(agriculteur=agriculteur).exclude(lieu_stockage='').values_list('lieu_stockage', flat=True).distinct()
    for n in deja:
        if n not in noms:
            noms.append(n)
    return noms


@login_required
def ajouter_recolte(request):
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
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
    return render(request, 'pertes/formulaire_recolte.html', {'form': form, 'titre': 'Ajouter une récolte', 'lieux_stockage': _lieux_stockage(agriculteur)})


@login_required
def detail_recolte(request, pk):
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
    recolte = get_object_or_404(
        Recolte.objects.select_related('culture', 'agriculteur__user').prefetch_related(
            'pertes', 'evenements_traceabilite__auteur'
        ),
        pk=pk,
        agriculteur=agriculteur,
    )

    # Permet d'ajouter un contrôle ou une observation sans modifier les quantités.
    if request.method == 'POST':
        type_evenement = request.POST.get('type_evenement', 'controle')
        description = request.POST.get('description', '').strip()
        lieu = request.POST.get('lieu', '').strip()
        if type_evenement not in {'controle', 'autre'}:
            messages.error(request, "Type d'événement non autorisé depuis ce formulaire.")
        elif not description:
            messages.error(request, "Veuillez saisir une description de l'événement.")
        else:
            EvenementTraceabilite.objects.create(
                recolte=recolte,
                type_evenement=type_evenement,
                description=description,
                lieu=lieu or recolte.lieu_stockage,
                quantite_kg=recolte.quantite_restante_kg if recolte.quantite_restante_kg > 0 else None,
                auteur=request.user,
            )
            messages.success(request, "Événement ajouté à l'historique du lot.")
            return redirect('detail_recolte', pk=recolte.pk)

    evenements = recolte.evenements_traceabilite.select_related('auteur').order_by('-date_evenement')
    return render(request, 'pertes/detail_recolte.html', {
        'recolte': recolte,
        'evenements': evenements,
    })


@login_required
def modifier_recolte(request, pk):
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
    recolte = get_object_or_404(Recolte, pk=pk, agriculteur=agriculteur)
    if request.method == 'POST':
        form = RecolteForm(request.POST, instance=recolte)
        if form.is_valid():
            form.save()
            messages.success(request, "Récolte modifiée avec succès.")
            return redirect('detail_recolte', pk=recolte.pk)
    else:
        form = RecolteForm(instance=recolte)
    return render(request, 'pertes/formulaire_recolte.html', {'form': form, 'titre': 'Modifier la récolte', 'lieux_stockage': _lieux_stockage(agriculteur)})


@login_required
def supprimer_recolte(request, pk):
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
    recolte = get_object_or_404(Recolte, pk=pk, agriculteur=agriculteur)
    if request.method == 'POST':
        try:
            recolte.delete()
        except ProtectedError:
            messages.error(
                request,
                "Cette récolte possède un historique de traçabilité. "
                "Sa suppression est bloquée afin de préserver les preuves des opérations enregistrées."
            )
            return redirect('detail_recolte', pk=recolte.pk)
        messages.success(request, "Récolte supprimée.")
        return redirect('liste_recoltes')
    return render(request, 'pertes/confirmer_suppression.html', {'objet': recolte, 'type_objet': 'la récolte'})


@login_required
def prediction_risque(request):
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
    resultat = None
    form = PredictionForm(request.POST or None)
    if request.method == 'POST' and form.is_valid():
        from .ia.engine import predire_risque
        recolte = form.cleaned_data['culture']
        date_recolte = form.cleaned_data['date_recolte']
        try:
            resultat = predire_risque(
                culture_nom=recolte.nom, region=agriculteur.region, mois=date_recolte.month,
                quantite_kg=float(form.cleaned_data['quantite_kg']),
                lieu_stockage=form.cleaned_data['lieu_stockage'],
            )
            resultat['probabilite_principale'] = round(resultat['probabilites'][resultat['risque']] * 100, 1)
        except RuntimeError as exc:
            messages.warning(request, str(exc))
            resultat = None
    return render(request, 'pertes/prediction.html', {'form': form, 'resultat': resultat, 'agriculteur': agriculteur})

@login_required
def localisation(request):
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
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
        agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
        agriculteur.latitude, agriculteur.longitude = lat, lng
        agriculteur.localisation_nom = str(data.get('nom', '')).strip()[:150]
        agriculteur.save(update_fields=['latitude', 'longitude', 'localisation_nom'])
        return JsonResponse({'ok': True, 'latitude': lat, 'longitude': lng, 'nom': agriculteur.localisation_nom})
    except (TypeError, ValueError, json.JSONDecodeError):
        return JsonResponse({'ok': False, 'detail': 'Coordonnées invalides.'}, status=400)

@login_required
def scanner_recolte(request):
    """Phase 6 — Module IA : scan visuel d'une photo de récolte, lié à une récolte précise."""
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
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
            from .ia.vision import analyser_photo

            photo = request.FILES['photo']
            with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as tmp:
                for chunk in photo.chunks():
                    tmp.write(chunk)
                tmp_path = tmp.name
            try:
                resultat = analyser_photo(tmp_path)
            finally:
                if os.path.exists(tmp_path):
                    os.unlink(tmp_path)

            # Une photo refusée ne doit jamais être traitée comme une récolte.
            if resultat.get('photo_acceptee', True) and recolte_selectionnee:
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
def analyser_recolte_api(request):
    """Analyse sécurisée d'une photo, réservée aux images de produits agricoles."""
    if request.method != 'POST':
        return JsonResponse({'error': 'Méthode non autorisée'}, status=405)

    tmp_path = None
    data = {}
    try:
        # Limite également configurée dans settings.py; on traite proprement le dépassement.
        raw_body = request.body
        if len(raw_body) > 10 * 1024 * 1024:
            return JsonResponse({'error': 'Requête trop volumineuse. Choisissez une photo plus légère (6 Mo maximum).'}, status=413)

        data = json.loads(raw_body or b'{}')
        recolte_id = data.get('recolte_id')
        image_data = data.get('image')
        if not isinstance(image_data, str) or not image_data.startswith('data:image/'):
            return JsonResponse({'error': 'Image absente ou format non autorisé. Utilisez une photo JPEG, PNG ou WEBP.'}, status=400)

        header, separator, encoded = image_data.partition(',')
        allowed_headers = {'data:image/jpeg;base64', 'data:image/jpg;base64',
                           'data:image/png;base64', 'data:image/webp;base64'}
        if not separator or header.lower() not in allowed_headers:
            return JsonResponse({'error': 'Format accepté : JPEG, PNG ou WEBP. Les SVG et autres fichiers sont refusés.'}, status=400)

        # Refuser avant décodage les chaînes Base64 qui dépasseraient la limite de 6 Mo.
        if len(encoded) > 4 * ((6 * 1024 * 1024 + 2) // 3):
            return JsonResponse({'error': 'La photo dépasse la limite de 6 Mo. Choisissez une image plus légère.'}, status=413)

        img_bytes = base64.b64decode(encoded, validate=True)
        if not img_bytes or len(img_bytes) > 6 * 1024 * 1024:
            return JsonResponse({'error': 'La photo est vide ou dépasse la limite de 6 Mo.'}, status=413)

        agriculteur, _ = Agriculteur.objects.get_or_create(
            user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''}
        )
        recolte = get_object_or_404(Recolte, pk=recolte_id, agriculteur=agriculteur)

        from PIL import Image, ImageOps, UnidentifiedImageError
        import io
        try:
            with Image.open(io.BytesIO(img_bytes)) as source:
                if source.format not in {'JPEG', 'PNG', 'WEBP'}:
                    return JsonResponse({'error': 'Format accepté : JPEG, PNG ou WEBP.'}, status=400)
                if source.width < 100 or source.height < 100:
                    return JsonResponse({'error': 'Image trop petite. Prenez une photo plus nette (au moins 100 × 100 pixels).'}, status=400)
                if source.width > 6000 or source.height > 6000 or source.width * source.height > 24_000_000:
                    return JsonResponse({'error': 'Dimensions trop importantes. Réduisez la résolution de la photo.'}, status=413)
                source.verify()
            with Image.open(io.BytesIO(img_bytes)) as source:
                normalized = ImageOps.exif_transpose(source).convert('RGB')
                normalized.thumbnail((1600, 1600))
                with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as tmp:
                    normalized.save(tmp, format='JPEG', quality=82, optimize=True)
                    tmp_path = tmp.name
        except (UnidentifiedImageError, OSError, ValueError):
            return JsonResponse({'error': 'Le fichier reçu n’est pas une image valide.'}, status=400)

        from .ia.vision import analyser_photo, MoteurVisionIndisponible
        try:
            resultat = analyser_photo(tmp_path)
        except MoteurVisionIndisponible as exc:
            return JsonResponse({'error': str(exc), 'disponible': False}, status=503)

        if not resultat.get('photo_acceptee', False):
            return JsonResponse({
                'photo_acceptee': False,
                'categorie': 'photo_refusee',
                'message': resultat.get('message', 'Photo refusée : aucun produit agricole reconnu.'),
                'confiance_reconnaissance_pct': resultat.get('confiance_reconnaissance_pct'),
                'limite': resultat.get('limite', 'La reconnaissance automatique peut se tromper.'),
            }, status=422)

        quantite_estimee_kg = round(
            float(recolte.quantite_kg) * resultat['taux_zones_ternies'] / 100, 1
        )
        return JsonResponse({
            'photo_acceptee': True,
            'taux_zones_ternies': resultat['taux_zones_ternies'],
            'categorie': resultat['categorie'],
            'message': resultat['message'],
            'quantite_estimee_kg': quantite_estimee_kg,
            'quantite_totale': float(recolte.quantite_kg),
            'part_sombre': resultat['part_sombre'],
            'part_brune': resultat['part_brune'],
            'zone_analysee': resultat['zone_analysee'],
            'signe_principal': resultat['signe_principal'],
            'confiance_reconnaissance_pct': resultat.get('confiance_reconnaissance_pct'),
            'limite': resultat.get('limite', 'Analyse indicative; confirmez le résultat par observation réelle.'),
        })
    except RequestDataTooBig:
        return JsonResponse({'error': 'La requête est trop volumineuse. La photo doit faire 6 Mo maximum.'}, status=413)
    except (ValueError, json.JSONDecodeError, TypeError, binascii.Error):
        return JsonResponse({'error': 'Les données envoyées sont invalides. Reprenez la photo et réessayez.'}, status=400)
    except (Recolte.DoesNotExist, Http404):
        return JsonResponse({'error': 'Récolte introuvable ou non accessible avec ce compte.'}, status=404)
    except Exception:
        logging.getLogger(__name__).exception(
            "Échec inattendu de l'analyse IA de récolte (utilisateur=%s, récolte=%s)",
            getattr(request.user, "pk", None),
            data.get('recolte_id') if isinstance(data, dict) else None,
        )
        return JsonResponse({
            'error': "Le serveur n'a pas pu terminer l'analyse. Consultez le terminal Django.",
            'code': 'ANALYSE_RECOLTE_ERROR',
        }, status=500)
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)


@login_required
def liste_pertes(request):
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
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
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
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
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
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
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
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
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
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
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
    data = _dashboard_data(agriculteur)
    return render(request, 'pertes/rapport.html', {'data': data, 'agriculteur': agriculteur})

@login_required
def export_rapport_csv(request):
    import csv
    from django.http import HttpResponse
    agriculteur, _ = Agriculteur.objects.get_or_create(user=request.user, defaults={'region': 'thies', 'nom_exploitation': ''})
    recoltes = Recolte.objects.filter(agriculteur=agriculteur, quantite_kg__gt=0).select_related('culture')
    response = HttpResponse(content_type='text/csv; charset=utf-8')
    response.write('\ufeff')  # BOM écrit une seule fois : Excel lit correctement les accents
    response['Content-Disposition'] = 'attachment; filename="samou_mbeymi_rapport.csv"'
    writer = csv.writer(response, delimiter=';', lineterminator='\r\n')
    writer.writerow(['Culture', 'Date de récolte', 'Quantité récoltée (kg)', 'Pertes (kg)', 'Taux de perte (%)', 'Lieu de stockage'])
    for r in recoltes:
        writer.writerow([r.culture.nom, r.date_recolte.strftime('%d/%m/%Y'), f'{float(r.quantite_kg):.2f}'.replace('.',','), f'{float(r.total_pertes_kg):.2f}'.replace('.',','), f'{r.pourcentage_perte:.1f}'.replace('.',','), r.lieu_stockage])
    return response


@login_required
def conservation_intelligente(request):
    from datetime import date
    recoltes = list(
        Recolte.objects.filter(agriculteur__user=request.user)
        .select_related('culture').prefetch_related('pertes')
        .order_by('-date_recolte')[:50]
    )
    for recolte in recoltes:
        recolte.age_jours = max(0, (date.today() - recolte.date_recolte).days)
        recolte.risque_perte_pct = recolte.pourcentage_perte
        recolte.niveau_surveillance = 'Élevé' if recolte.pourcentage_perte >= 12 else ('À surveiller' if recolte.pourcentage_perte >= 5 else 'Normal')
    produits = [
        {'nom':'Tomate','conseil':'Trier les fruits blessés, garder les caisses à l’ombre et limiter les chocs.'},
        {'nom':'Oignon','conseil':'Bien ressuyer, conserver dans un local sec et ventilé, et séparer les bulbes abîmés.'},
        {'nom':'Pomme de terre','conseil':'Conserver dans un endroit sombre et ventilé, et éviter l’exposition à la lumière.'},
        {'nom':'Carotte','conseil':'Limiter le dessèchement, éviter le soleil et utiliser des contenants propres.'},
        {'nom':'Chou','conseil':'Éviter les chocs, retirer les feuilles très abîmées et maintenir une bonne hygiène.'},
        {'nom':'Mangue','conseil':'Manipuler délicatement, trier selon la maturité et isoler les fruits abîmés.'},
    ]
    total_kg = sum((r.quantite_kg for r in recoltes), Decimal('0'))
    pertes_kg = sum((r.total_pertes_kg for r in recoltes), Decimal('0'))
    return render(request, 'pertes/conservation_intelligente.html', {
        'recoltes': recoltes, 'produits': produits, 'total_kg': total_kg,
        'pertes_kg': pertes_kg, 'nb_surveillance': sum(1 for r in recoltes if r.niveau_surveillance != 'Normal'),
    })

@login_required
def assistant_phytosanitaire(request):
    conseils = [
        {'titre':'Inspecter régulièrement','texte':'Examiner les feuilles, tiges et fruits, y compris le dessous des feuilles. Noter la date et la zone touchée.','icone':'search'},
        {'titre':'Limiter la propagation','texte':'Nettoyer les outils et éviter de déplacer des plants ou résidus suspects vers une parcelle saine.','icone':'shield'},
        {'titre':'Gérer l’eau et l’aération','texte':'Adapter l’arrosage et l’aération aux besoins de la culture ; éviter les excès d’humidité persistants.','icone':'droplet'},
        {'titre':'Documenter les symptômes','texte':'Photographier les symptômes avec une bonne lumière et noter leur évolution. Une photo ne garantit pas un diagnostic.','icone':'camera'},
        {'titre':'Demander un avis qualifié','texte':'Faire confirmer l’identification par un conseiller agricole avant toute décision de traitement.','icone':'user-check'},
    ]
    return render(request, 'pertes/assistant_phytosanitaire.html', {'conseils':conseils})

@login_required
def fournisseurs_engrais(request):
    engrais = [
        {'nom':'Compost / matière organique','usage':'Contribue à la structure du sol et à la matière organique.','prudence':'Utiliser un compost mûr et adapté ; éviter les matières insuffisamment décomposées.'},
        {'nom':'NPK','usage':'Apporte azote, phosphore et potassium selon la formule indiquée sur le sac.','prudence':'La formule doit correspondre à la culture et aux besoins du sol.'},
        {'nom':'Urée','usage':'Engrais azoté dont l’emploi dépend de la culture et du stade de croissance.','prudence':'Éviter les doses arbitraires ; demander conseil sur la dose et le calendrier.'},
        {'nom':'Engrais phosphaté','usage':'Apporte du phosphore lorsque les besoins agronomiques le justifient.','prudence':'Vérifier la formulation et les recommandations locales.'},
    ]
    return render(request, 'pertes/fournisseurs_engrais.html', {'engrais':engrais})

@login_required
def marketplace_agricole(request):
    offres = OffreRecolte.objects.select_related('recolte__culture','recolte__agriculteur__user').filter(statut='disponible').order_by('-date_creation')
    q = request.GET.get('q', '').strip()
    region = request.GET.get('region', '').strip()
    if q:
        offres = offres.filter(Q(recolte__culture__nom__icontains=q) | Q(commune__icontains=q) | Q(description__icontains=q) | Q(recolte__agriculteur__nom_exploitation__icontains=q))
    if region:
        offres = offres.filter(recolte__agriculteur__region=region)
    mes_commandes = CommandeLivraison.objects.filter(
        Q(acheteur=request.user) | Q(offre__recolte__agriculteur__user=request.user)
    ).select_related('offre__recolte__culture', 'offre__recolte__agriculteur__user', 'acheteur')[:30]
    mes_recoltes = Recolte.objects.filter(agriculteur__user=request.user).select_related('culture').order_by('-date_recolte')
    return render(request, 'pertes/marketplace_agricole.html', {
        'offres': offres, 'q': q, 'region': region, 'regions': Agriculteur._meta.get_field('region').choices,
        'mes_commandes': mes_commandes, 'mes_recoltes': mes_recoltes,
    })

@login_required
def publier_offre_marketplace(request):
    if request.method != 'POST':
        return redirect('marketplace_agricole')
    recolte = get_object_or_404(Recolte, pk=request.POST.get('recolte'), agriculteur__user=request.user)
    try:
        quantite = Decimal(request.POST.get('quantite_kg', ''))
        prix = Decimal(request.POST.get('prix_kg_fcfa', ''))
        if quantite <= 0 or prix <= 0:
            raise InvalidOperation
    except (InvalidOperation, TypeError, ValueError):
        messages.error(request, 'Saisissez une quantité et un prix strictement positifs.')
        return redirect('marketplace_agricole')
    pertes = recolte.pertes.aggregate(total=Sum('quantite_perdue_kg'))['total'] or Decimal('0')
    deja_annonce = recolte.offres_marche.exclude(statut='retiree').aggregate(total=Sum('quantite_kg'))['total'] or Decimal('0')
    if quantite + pertes + deja_annonce > recolte.quantite_kg:
        messages.error(request, 'La quantité proposée dépasse la quantité récoltée disponible après pertes et annonces existantes.')
        return redirect('marketplace_agricole')
    OffreRecolte.objects.create(
        recolte=recolte, quantite_kg=quantite, prix_kg_fcfa=prix,
        commune=request.POST.get('commune', '').strip()[:100],
        description=request.POST.get('description', '').strip(),
    )
    messages.success(request, 'Votre offre a été publiée.')
    return redirect('marketplace_agricole')

@login_required
def commander_offre_marketplace(request, pk):
    if request.method != 'POST':
        return redirect('marketplace_agricole')
    try:
        quantite = Decimal(request.POST.get('quantite_kg', ''))
        telephone = request.POST.get('telephone_contact', '').strip()
        adresse = request.POST.get('adresse_livraison', '').strip()
        if quantite <= 0 or not telephone or not adresse:
            raise InvalidOperation
    except (InvalidOperation, TypeError, ValueError):
        messages.error(request, 'Quantité, téléphone et adresse de livraison sont obligatoires.')
        return redirect('marketplace_agricole')
    with transaction.atomic():
        offre = get_object_or_404(OffreRecolte.objects.select_for_update().select_related('recolte__agriculteur'), pk=pk, statut='disponible')
        if offre.recolte.agriculteur.user_id == request.user.id:
            messages.error(request, 'Vous ne pouvez pas commander votre propre offre.')
            return redirect('marketplace_agricole')
        if quantite > offre.quantite_restante_kg:
            messages.error(request, f'Quantité indisponible. Stock restant : {offre.quantite_restante_kg} kg.')
            return redirect('marketplace_agricole')
        CommandeLivraison.objects.create(
            offre=offre, acheteur=request.user, quantite_kg=quantite,
            telephone_contact=telephone[:25], adresse_livraison=adresse[:255],
            notes=request.POST.get('notes', '').strip(),
        )
        if offre.quantite_restante_kg <= 0:
            offre.statut = 'vendue'
            offre.save(update_fields=['statut', 'date_modification'])
    messages.success(request, 'Demande envoyée au producteur. Le montant affiché reste estimatif jusqu’à confirmation.')
    return redirect('marketplace_agricole')

@login_required
def changer_statut_commande_marketplace(request, pk):
    if request.method != 'POST':
        return redirect('marketplace_agricole')
    with transaction.atomic():
        commande = get_object_or_404(CommandeLivraison.objects.select_for_update().select_related('offre__recolte__agriculteur'), pk=pk)
        is_producer = commande.offre.recolte.agriculteur.user_id == request.user.id
        is_buyer = commande.acheteur_id == request.user.id
        target = request.POST.get('statut', '').strip()
        if not (is_producer or is_buyer):
            messages.error(request, 'Vous ne pouvez pas modifier cette commande.')
            return redirect('marketplace_agricole')
        transitions_acheteur = {'demandee': {'annulee'}}
        transitions_producteur = {'demandee': {'confirmee', 'annulee'}, 'confirmee': {'preparation', 'annulee'}, 'preparation': {'expediee', 'annulee'}, 'expediee': {'livree'}, 'livree': set(), 'annulee': set()}
        autorises = transitions_producteur if is_producer else transitions_acheteur
        if target not in autorises.get(commande.statut, set()):
            messages.error(request, 'Cette transition de statut n’est pas autorisée.')
            return redirect('marketplace_agricole')
        commande.statut = target
        commande.save(update_fields=['statut', 'date_modification'])
        offre = OffreRecolte.objects.select_for_update().get(pk=commande.offre_id)
        if offre.statut == 'vendue' and offre.quantite_restante_kg > 0:
            offre.statut = 'disponible'
            offre.save(update_fields=['statut', 'date_modification'])
    messages.success(request, 'Statut de la commande mis à jour.')
    return redirect('marketplace_agricole')



@login_required
def assistant_agricole_web(request):
    """Interface Web unifiée de l'assistant agricole écrit et vocal."""
    return render(request, 'pertes/assistant_agricole.html')
