from django.db import models
from decimal import Decimal
from django.contrib.auth.models import User
from django.urls import reverse
from django.core.validators import MinValueValidator


REGIONS_SENEGAL = [
    ('dakar', 'Dakar'),
    ('thies', 'Thiès'),
    ('diourbel', 'Diourbel'),
    ('fatick', 'Fatick'),
    ('kaolack', 'Kaolack'),
    ('kaffrine', 'Kaffrine'),
    ('kolda', 'Kolda'),
    ('louga', 'Louga'),
    ('matam', 'Matam'),
    ('saint_louis', 'Saint-Louis'),
    ('sedhiou', 'Sédhiou'),
    ('tambacounda', 'Tambacounda'),
    ('kedougou', 'Kédougou'),
    ('ziguinchor', 'Ziguinchor'),
]


class Agriculteur(models.Model):
    """Profil étendu d'un utilisateur agriculteur."""
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profil')
    telephone = models.CharField(max_length=20, blank=True)
    region = models.CharField(max_length=30, choices=REGIONS_SENEGAL, default='thies')
    nom_exploitation = models.CharField(max_length=150, blank=True)
    date_inscription = models.DateTimeField(auto_now_add=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    localisation_nom = models.CharField(max_length=150, blank=True)

    class Meta:
        verbose_name = "Agriculteur"
        verbose_name_plural = "Agriculteurs"

    def __str__(self):
        return f"{self.user.get_full_name() or self.user.username} ({self.get_region_display()})"


class Culture(models.Model):
    """Type de culture agricole (mil, maïs, tomate, mangue, etc.)."""
    nom = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)

    class Meta:
        verbose_name = "Culture"
        verbose_name_plural = "Cultures"
        ordering = ['nom']

    def __str__(self):
        return self.nom


class Recolte(models.Model):
    """Une récolte enregistrée par un agriculteur."""
    agriculteur = models.ForeignKey(Agriculteur, on_delete=models.CASCADE, related_name='recoltes')
    culture = models.ForeignKey(Culture, on_delete=models.CASCADE, related_name='recoltes')
    quantite_kg = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(0.01)], help_text="Quantité récoltée en kg")
    date_recolte = models.DateField()
    lieu_stockage = models.CharField(max_length=150, blank=True)
    notes = models.TextField(blank=True)
    date_creation = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Récolte"
        verbose_name_plural = "Récoltes"
        ordering = ['-date_recolte']

    def __str__(self):
        return f"{self.culture} - {self.quantite_kg} kg ({self.date_recolte})"

    @property
    def numero_lot(self):
        """Référence métier stable, dérivée de la date et de la clé primaire."""
        if not self.pk:
            return 'En attente de numéro'
        return f'SMB-{self.date_recolte:%Y}-{self.pk:05d}'

    @property
    def quantite_restante_kg(self):
        return max(Decimal('0.00'), self.quantite_kg - Decimal(str(self.total_pertes_kg)))

    def get_absolute_url(self):
        return reverse('detail_recolte', args=[self.pk])

    @property
    def total_pertes_kg(self):
        total = self.pertes.aggregate(models.Sum('quantite_perdue_kg'))['quantite_perdue_kg__sum']
        return total or 0

    @property
    def pourcentage_perte(self):
        if self.quantite_kg and self.quantite_kg > 0:
            return round((float(self.total_pertes_kg) / float(self.quantite_kg)) * 100, 1)
        return 0


class Perte(models.Model):
    """Une perte signalée sur une récolte."""

    TYPE_PERTE_CHOICES = [
        ('insectes', 'Insectes / ravageurs'),
        ('moisissure', 'Moisissure / pourriture'),
        ('transport', 'Perte pendant le transport'),
        ('stockage', 'Mauvaises conditions de stockage'),
        ('climat', 'Aléas climatiques'),
        ('maladie', 'Maladie de la plante'),
        ('autre', 'Autre'),
    ]

    STATUT_CHOICES = [
        ('signalee', 'Signalée'),
        ('en_cours', 'En cours de traitement'),
        ('resolue', 'Résolue'),
    ]

    recolte = models.ForeignKey(Recolte, on_delete=models.CASCADE, related_name='pertes')
    type_perte = models.CharField(max_length=20, choices=TYPE_PERTE_CHOICES)
    quantite_perdue_kg = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(0.01)])
    date_signalement = models.DateField(auto_now_add=True)
    description = models.TextField(blank=True)
    statut = models.CharField(max_length=15, choices=STATUT_CHOICES, default='signalee')
    photo = models.ImageField(upload_to='pertes_photos/', blank=True, null=True)

    class Meta:
        verbose_name = "Perte"
        verbose_name_plural = "Pertes"
        ordering = ['-date_signalement']

    def __str__(self):
        return f"{self.get_type_perte_display()} - {self.quantite_perdue_kg} kg"


class Stockage(models.Model):
    """Point de stockage disponible (utile pour phases suivantes)."""
    nom = models.CharField(max_length=150)
    region = models.CharField(max_length=30, choices=REGIONS_SENEGAL)
    capacite_kg = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(0)])
    disponible = models.BooleanField(default=True)
    contact = models.CharField(max_length=20, blank=True)

    class Meta:
        verbose_name = "Stockage"
        verbose_name_plural = "Stockages"

    def __str__(self):
        return f"{self.nom} ({self.get_region_display()})"


class OffreRecolte(models.Model):
    """Annonce commerciale liée à une récolte existante."""
    STATUT_CHOICES = [
        ('disponible', 'Disponible'),
        ('reservee', 'Partiellement réservée'),
        ('vendue', 'Vendue'),
        ('retiree', 'Retirée'),
    ]

    recolte = models.ForeignKey(Recolte, on_delete=models.PROTECT, related_name='offres_marche')
    quantite_kg = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal('0.01'))])
    prix_kg_fcfa = models.DecimalField(max_digits=12, decimal_places=2, validators=[MinValueValidator(Decimal('1'))])
    commune = models.CharField(max_length=100, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    description = models.TextField(blank=True)
    statut = models.CharField(max_length=15, choices=STATUT_CHOICES, default='disponible', db_index=True)
    date_creation = models.DateTimeField(auto_now_add=True)
    date_modification = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Offre de récolte'
        verbose_name_plural = 'Offres de récolte'
        ordering = ['-date_creation']
        indexes = [models.Index(fields=['statut', 'date_creation'], name='offre_statut_date_idx')]

    def __str__(self):
        return f'{self.recolte.culture.nom} — {self.quantite_kg} kg à {self.prix_kg_fcfa} FCFA/kg'

    @property
    def quantite_commandee_kg(self):
        total = self.commandes.exclude(statut='annulee').aggregate(total=models.Sum('quantite_kg'))['total']
        return total or 0

    @property
    def quantite_restante_kg(self):
        return max(0, self.quantite_kg - self.quantite_commandee_kg)


class CommandeLivraison(models.Model):
    """Demande d'achat et suivi de livraison d'une offre agricole."""
    STATUT_CHOICES = [
        ('demandee', 'Demande envoyée'),
        ('confirmee', 'Confirmée par le producteur'),
        ('preparation', 'En préparation'),
        ('expediee', 'Expédiée'),
        ('livree', 'Livrée'),
        ('annulee', 'Annulée'),
    ]

    offre = models.ForeignKey(OffreRecolte, on_delete=models.PROTECT, related_name='commandes')
    acheteur = models.ForeignKey(User, on_delete=models.PROTECT, related_name='commandes_agricoles')
    quantite_kg = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal('0.01'))])
    telephone_contact = models.CharField(max_length=25)
    adresse_livraison = models.CharField(max_length=255)
    notes = models.TextField(blank=True)
    statut = models.CharField(max_length=15, choices=STATUT_CHOICES, default='demandee', db_index=True)
    date_creation = models.DateTimeField(auto_now_add=True)
    date_modification = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Commande agricole'
        verbose_name_plural = 'Commandes agricoles'
        ordering = ['-date_creation']
        indexes = [models.Index(fields=['statut', 'date_creation'], name='commande_statut_date_idx')]

    def __str__(self):
        return f'Commande #{self.pk} — {self.offre.recolte.culture.nom} ({self.quantite_kg} kg)'

    @property
    def montant_estime_fcfa(self):
        return self.quantite_kg * self.offre.prix_kg_fcfa



class EvenementTraceabilite(models.Model):
    """Événement horodaté retraçant le cycle de vie d'une récolte/lot."""

    TYPE_CHOICES = [
        ('creation', 'Création du lot'),
        ('stockage', 'Mise en stockage'),
        ('deplacement', 'Déplacement'),
        ('controle', 'Contrôle du lot'),
        ('perte', 'Perte déclarée'),
        ('mise_a_jour', 'Mise à jour'),
        ('autre', 'Autre événement'),
    ]

    recolte = models.ForeignKey(
        Recolte, on_delete=models.PROTECT, related_name='evenements_traceabilite'
    )
    type_evenement = models.CharField(max_length=20, choices=TYPE_CHOICES, db_index=True)
    description = models.TextField(blank=True)
    lieu = models.CharField(max_length=150, blank=True)
    quantite_kg = models.DecimalField(
        max_digits=10, decimal_places=2, null=True, blank=True,
        validators=[MinValueValidator(Decimal('0.01'))],
        help_text="Quantité concernée, si applicable."
    )
    auteur = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='evenements_traceabilite'
    )
    date_evenement = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        verbose_name = "Événement de traçabilité"
        verbose_name_plural = "Événements de traçabilité"
        ordering = ['-date_evenement']
        indexes = [
            models.Index(fields=['recolte', 'date_evenement'], name='trace_recolte_date_idx')
        ]

    def __str__(self):
        return f"{self.get_type_evenement_display()} — récolte #{self.recolte_id}"
