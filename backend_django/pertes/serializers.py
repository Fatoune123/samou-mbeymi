from django.contrib.auth.models import User
from django.core.exceptions import ValidationError
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from decimal import Decimal
from django.db.models import Sum
from .models import Agriculteur, Culture, Recolte, Perte, Stockage, EvenementTraceabilite, REGIONS_SENEGAL


class AgriculteurSerializer(serializers.ModelSerializer):
    nom_complet = serializers.SerializerMethodField()
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.EmailField(source='user.email', required=False, allow_blank=True)
    first_name = serializers.CharField(source='user.first_name', required=False)
    last_name = serializers.CharField(source='user.last_name', required=False)
    region_display = serializers.CharField(source='get_region_display', read_only=True)

    class Meta:
        model = Agriculteur
        fields = [
            'id', 'username', 'nom_complet', 'email', 'first_name', 'last_name',
            'telephone', 'region', 'region_display', 'nom_exploitation', 'latitude', 'longitude', 'localisation_nom', 'date_inscription'
        ]
        read_only_fields = ['id', 'username', 'nom_complet', 'region_display', 'date_inscription']

    def get_nom_complet(self, obj):
        return obj.user.get_full_name() or obj.user.username

    def update(self, instance, validated_data):
        user_data = validated_data.pop('user', {})
        user = instance.user
        for field in ('first_name', 'last_name', 'email'):
            if field in user_data:
                setattr(user, field, user_data[field])
        user.save(update_fields=['first_name', 'last_name', 'email'])
        return super().update(instance, validated_data)


class InscriptionSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    telephone = serializers.CharField(required=False, allow_blank=True)
    region = serializers.ChoiceField(choices=REGIONS_SENEGAL)
    nom_exploitation = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = User
        fields = ['username', 'first_name', 'last_name', 'email', 'password',
                  'telephone', 'region', 'nom_exploitation']

    def validate_username(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("Ce nom d'utilisateur est déjà pris.")
        return value

    def validate_password(self, value):
        user = User(
            username=self.initial_data.get('username', ''),
            first_name=self.initial_data.get('first_name', ''),
            last_name=self.initial_data.get('last_name', ''),
            email=self.initial_data.get('email', ''),
        )
        try:
            validate_password(value, user=user)
        except ValidationError as exc:
            raise serializers.ValidationError(list(exc.messages)) from exc
        return value

    def create(self, validated_data):
        telephone = validated_data.pop('telephone', '')
        region = validated_data.pop('region')
        nom_exploitation = validated_data.pop('nom_exploitation', '')
        password = validated_data.pop('password')
        user = User.objects.create_user(password=password, **validated_data)
        Agriculteur.objects.create(
            user=user, telephone=telephone, region=region, nom_exploitation=nom_exploitation
        )
        return user


class CultureSerializer(serializers.ModelSerializer):
    class Meta:
        model = Culture
        fields = ['id', 'nom', 'description']


class PerteSerializer(serializers.ModelSerializer):
    type_perte_display = serializers.CharField(source='get_type_perte_display', read_only=True)
    statut_display = serializers.CharField(source='get_statut_display', read_only=True)
    culture_nom = serializers.CharField(source='recolte.culture.nom', read_only=True)

    class Meta:
        model = Perte
        fields = ['id', 'recolte', 'culture_nom', 'type_perte', 'type_perte_display',
                  'quantite_perdue_kg', 'date_signalement', 'description', 'statut',
                  'statut_display', 'photo']
        read_only_fields = ['date_signalement']

    def validate_recolte(self, value):
        request = self.context['request']
        if value.agriculteur.user != request.user:
            raise serializers.ValidationError("Cette récolte ne vous appartient pas.")
        return value

    def validate(self, attrs):
        recolte = attrs.get('recolte') or getattr(self.instance, 'recolte', None)
        quantite = attrs.get('quantite_perdue_kg', getattr(self.instance, 'quantite_perdue_kg', 0))
        if recolte and quantite is not None and float(quantite) <= 0:
            raise serializers.ValidationError({'quantite_perdue_kg': 'La quantité doit être supérieure à 0.'})
        if recolte:
            current = recolte.pertes.exclude(
                pk=getattr(self.instance, 'pk', None)
            ).aggregate(total=Sum('quantite_perdue_kg'))['total'] or Decimal('0.00')
            if current + Decimal(str(quantite)) > recolte.quantite_kg:
                disponible = recolte.quantite_kg - current
                raise serializers.ValidationError({
                    'quantite_perdue_kg': f'Quantité excessive. Maximum déclarable pour ce lot : {disponible} kg.'
                })
        return attrs


class RecolteSerializer(serializers.ModelSerializer):
    culture_nom = serializers.CharField(source='culture.nom', read_only=True)
    total_pertes_kg = serializers.ReadOnlyField()
    pourcentage_perte = serializers.ReadOnlyField()
    pertes = PerteSerializer(many=True, read_only=True)

    class Meta:
        model = Recolte
        fields = ['id', 'culture', 'culture_nom', 'quantite_kg', 'date_recolte',
                  'lieu_stockage', 'notes', 'date_creation', 'total_pertes_kg',
                  'pourcentage_perte', 'pertes']

    def validate_quantite_kg(self, value):
        if value <= 0:
            raise serializers.ValidationError('La quantité doit être supérieure à 0 kg.')
        if self.instance:
            pertes = self.instance.pertes.aggregate(total=Sum('quantite_perdue_kg'))['total'] or Decimal('0.00')
            if pertes > value:
                raise serializers.ValidationError(
                    f'Impossible de réduire la récolte : {pertes} kg de pertes sont déjà enregistrées.'
                )
        return value

    def create(self, validated_data):
        request = self.context['request']
        agriculteur = Agriculteur.objects.get(user=request.user)
        validated_data['agriculteur'] = agriculteur
        return super().create(validated_data)


class StockageSerializer(serializers.ModelSerializer):
    region_display = serializers.CharField(source='get_region_display', read_only=True)

    class Meta:
        model = Stockage
        fields = ['id', 'nom', 'region', 'region_display', 'capacite_kg', 'disponible', 'contact']


class TableauBordSerializer(serializers.Serializer):
    nb_recoltes = serializers.IntegerField()
    nb_pertes = serializers.IntegerField()
    total_recolte_kg = serializers.FloatField()
    total_perte_kg = serializers.FloatField()
    taux_perte = serializers.FloatField()
    rendement_conserve = serializers.FloatField()
    niveau_risque = serializers.CharField()
    recommandation = serializers.CharField()
    pertes_par_type = serializers.ListField()
    evolution_mensuelle = serializers.ListField()
    alertes = serializers.ListField()
    recoltes_recentes = serializers.ListField()
    pertes_recentes = serializers.ListField()


class OffreRecolteSerializer(serializers.ModelSerializer):
    culture_nom = serializers.CharField(source='recolte.culture.nom', read_only=True)
    producteur = serializers.SerializerMethodField()
    region = serializers.CharField(source='recolte.agriculteur.get_region_display', read_only=True)
    quantite_restante_kg = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    distance_km = serializers.SerializerMethodField()

    class Meta:
        from .models import OffreRecolte
        model = OffreRecolte
        fields = [
            'id', 'recolte', 'culture_nom', 'producteur', 'region', 'commune',
            'quantite_kg', 'quantite_restante_kg', 'prix_kg_fcfa', 'latitude',
            'longitude', 'description', 'statut', 'distance_km', 'date_creation',
        ]
        read_only_fields = ['id', 'statut', 'date_creation', 'quantite_restante_kg', 'distance_km']

    def get_producteur(self, obj):
        profil = obj.recolte.agriculteur
        return profil.nom_exploitation or profil.user.get_full_name() or profil.user.username

    def get_distance_km(self, obj):
        request = self.context.get('request')
        if request is None:
            return None
        try:
            lat = float(request.query_params['latitude'])
            lon = float(request.query_params['longitude'])
            if obj.latitude is None or obj.longitude is None:
                return None
            from math import asin, cos, radians, sin, sqrt
            lat1, lon1, lat2, lon2 = map(radians, [lat, lon, float(obj.latitude), float(obj.longitude)])
            a = sin((lat2 - lat1) / 2) ** 2 + cos(lat1) * cos(lat2) * sin((lon2 - lon1) / 2) ** 2
            return round(6371 * 2 * asin(min(1, sqrt(a))), 2)
        except (KeyError, TypeError, ValueError):
            return None

    def validate_recolte(self, value):
        request = self.context['request']
        if value.agriculteur.user_id != request.user.id:
            raise serializers.ValidationError('Vous ne pouvez publier que vos propres récoltes.')
        return value

    def validate(self, attrs):
        recolte = attrs.get('recolte') or getattr(self.instance, 'recolte', None)
        quantite = attrs.get('quantite_kg', getattr(self.instance, 'quantite_kg', None))
        if recolte and quantite is not None:
            pertes = sum(float(p.quantite_perdue_kg) for p in recolte.pertes.all())
            offres_actives = recolte.offres_marche.exclude(statut='retiree').exclude(pk=getattr(self.instance, 'pk', None))
            deja_annonce = sum(float(o.quantite_kg) for o in offres_actives)
            if float(quantite) + deja_annonce + pertes > float(recolte.quantite_kg):
                raise serializers.ValidationError({'quantite_kg': 'La quantité annoncée, les autres annonces et les pertes dépassent la récolte disponible.'})
        lat = attrs.get('latitude', getattr(self.instance, 'latitude', None))
        lon = attrs.get('longitude', getattr(self.instance, 'longitude', None))
        if (lat is None) != (lon is None):
            raise serializers.ValidationError('La latitude et la longitude doivent être renseignées ensemble.')
        if lat is not None and not (-90 <= float(lat) <= 90):
            raise serializers.ValidationError({'latitude': 'Latitude invalide.'})
        if lon is not None and not (-180 <= float(lon) <= 180):
            raise serializers.ValidationError({'longitude': 'Longitude invalide.'})
        return attrs


class CommandeLivraisonSerializer(serializers.ModelSerializer):
    culture_nom = serializers.CharField(source='offre.recolte.culture.nom', read_only=True)
    producteur = serializers.SerializerMethodField()
    acheteur_nom = serializers.CharField(source='acheteur.username', read_only=True)
    prix_kg_fcfa = serializers.DecimalField(source='offre.prix_kg_fcfa', max_digits=12, decimal_places=2, read_only=True)
    montant_estime_fcfa = serializers.SerializerMethodField()
    est_producteur = serializers.SerializerMethodField()

    class Meta:
        from .models import CommandeLivraison
        model = CommandeLivraison
        fields = [
            'id', 'offre', 'culture_nom', 'producteur', 'acheteur_nom', 'quantite_kg',
            'prix_kg_fcfa', 'montant_estime_fcfa', 'telephone_contact', 'adresse_livraison',
            'notes', 'statut', 'date_creation', 'date_modification', 'est_producteur',
        ]
        read_only_fields = ['id', 'acheteur_nom', 'statut', 'date_creation', 'date_modification', 'montant_estime_fcfa', 'est_producteur']

    def get_producteur(self, obj):
        profil = obj.offre.recolte.agriculteur
        return profil.nom_exploitation or profil.user.get_full_name() or profil.user.username

    def get_montant_estime_fcfa(self, obj):
        return float(obj.quantite_kg * obj.offre.prix_kg_fcfa)

    def get_est_producteur(self, obj):
        request = self.context.get('request')
        return bool(request and request.user.is_authenticated and obj.offre.recolte.agriculteur.user_id == request.user.id)

    def validate_offre(self, value):
        if value.statut != 'disponible':
            raise serializers.ValidationError('Cette offre n’est plus disponible.')
        if value.recolte.agriculteur.user_id == self.context['request'].user.id:
            raise serializers.ValidationError('Vous ne pouvez pas commander votre propre récolte.')
        return value

    def validate(self, attrs):
        offre = attrs.get('offre') or getattr(self.instance, 'offre', None)
        quantite = attrs.get('quantite_kg', getattr(self.instance, 'quantite_kg', None))
        if offre and quantite is not None:
            deja_commandee = sum(
                float(c.quantite_kg) for c in offre.commandes.exclude(statut='annulee').exclude(pk=getattr(self.instance, 'pk', None))
            )
            if float(quantite) + deja_commandee > float(offre.quantite_kg):
                raise serializers.ValidationError({'quantite_kg': 'La quantité demandée dépasse le stock disponible.'})
        return attrs



class EvenementTraceabiliteSerializer(serializers.ModelSerializer):
    type_evenement_display = serializers.CharField(source='get_type_evenement_display', read_only=True)
    auteur_nom = serializers.CharField(source='auteur.username', read_only=True)
    culture_nom = serializers.CharField(source='recolte.culture.nom', read_only=True)

    class Meta:
        model = EvenementTraceabilite
        fields = [
            'id', 'recolte', 'culture_nom', 'type_evenement',
            'type_evenement_display', 'description', 'lieu', 'quantite_kg',
            'auteur_nom', 'date_evenement',
        ]
        read_only_fields = ['id', 'auteur_nom', 'culture_nom', 'date_evenement']

    def validate_recolte(self, value):
        request = self.context['request']
        if value.agriculteur.user_id != request.user.id:
            raise serializers.ValidationError('Cette récolte ne vous appartient pas.')
        return value

    def validate_quantite_kg(self, value):
        if value is not None and value <= 0:
            raise serializers.ValidationError('La quantité doit être supérieure à zéro.')
        return value
