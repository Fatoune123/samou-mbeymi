from django.contrib.auth.models import User
from rest_framework import serializers
from .models import Agriculteur, Culture, Recolte, Perte, Stockage, REGIONS_SENEGAL


class AgriculteurSerializer(serializers.ModelSerializer):
    nom_complet = serializers.SerializerMethodField()
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.EmailField(source='user.email', read_only=True)
    first_name = serializers.CharField(source='user.first_name', required=False)
    last_name = serializers.CharField(source='user.last_name', required=False)
    region_display = serializers.CharField(source='get_region_display', read_only=True)

    class Meta:
        model = Agriculteur
        fields = [
            'id', 'username', 'nom_complet', 'email', 'first_name', 'last_name',
            'telephone', 'region', 'region_display', 'nom_exploitation', 'latitude', 'longitude', 'localisation_nom', 'date_inscription'
        ]
        read_only_fields = ['id', 'username', 'nom_complet', 'email', 'region_display', 'date_inscription']

    def get_nom_complet(self, obj):
        return obj.user.get_full_name() or obj.user.username

    def update(self, instance, validated_data):
        user_data = validated_data.pop('user', {})
        user = instance.user
        for field in ('first_name', 'last_name'):
            if field in user_data:
                setattr(user, field, user_data[field])
        user.save(update_fields=['first_name', 'last_name'])
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
            current = sum(
                float(p.quantite_perdue_kg) for p in recolte.pertes.exclude(pk=getattr(self.instance, 'pk', None))
            )
            if current + float(quantite) > float(recolte.quantite_kg):
                raise serializers.ValidationError({
                    'quantite_perdue_kg': 'La perte totale ne peut pas dépasser la quantité récoltée.'
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
        if float(value) <= 0:
            raise serializers.ValidationError('La quantité doit être supérieure à 0 kg.')
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
