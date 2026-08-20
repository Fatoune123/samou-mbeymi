from django.db import models
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
