from django.conf import settings
from decimal import Decimal
from django.db import migrations, models
import django.core.validators
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('pertes', '0003_agriculteur_localisation'),
    ]

    operations = [
        migrations.CreateModel(
            name='OffreRecolte',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('quantite_kg', models.DecimalField(decimal_places=2, max_digits=10, validators=[django.core.validators.MinValueValidator(Decimal('0.01'))])),
                ('prix_kg_fcfa', models.DecimalField(decimal_places=2, max_digits=12, validators=[django.core.validators.MinValueValidator(Decimal('1'))])),
                ('commune', models.CharField(blank=True, max_length=100)),
                ('latitude', models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ('longitude', models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ('description', models.TextField(blank=True)),
                ('statut', models.CharField(choices=[('disponible', 'Disponible'), ('reservee', 'Partiellement réservée'), ('vendue', 'Vendue'), ('retiree', 'Retirée')], db_index=True, default='disponible', max_length=15)),
                ('date_creation', models.DateTimeField(auto_now_add=True)),
                ('date_modification', models.DateTimeField(auto_now=True)),
                ('recolte', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='offres_marche', to='pertes.recolte')),
            ],
            options={'verbose_name': 'Offre de récolte', 'verbose_name_plural': 'Offres de récolte', 'ordering': ['-date_creation']},
        ),
        migrations.AddIndex(model_name='offrerecolte', index=models.Index(fields=['statut', 'date_creation'], name='offre_statut_date_idx')),
        migrations.CreateModel(
            name='CommandeLivraison',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('quantite_kg', models.DecimalField(decimal_places=2, max_digits=10, validators=[django.core.validators.MinValueValidator(Decimal('0.01'))])),
                ('telephone_contact', models.CharField(max_length=25)),
                ('adresse_livraison', models.CharField(max_length=255)),
                ('notes', models.TextField(blank=True)),
                ('statut', models.CharField(choices=[('demandee', 'Demande envoyée'), ('confirmee', 'Confirmée par le producteur'), ('preparation', 'En préparation'), ('expediee', 'Expédiée'), ('livree', 'Livrée'), ('annulee', 'Annulée')], db_index=True, default='demandee', max_length=15)),
                ('date_creation', models.DateTimeField(auto_now_add=True)),
                ('date_modification', models.DateTimeField(auto_now=True)),
                ('acheteur', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='commandes_agricoles', to=settings.AUTH_USER_MODEL)),
                ('offre', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='commandes', to='pertes.offrerecolte')),
            ],
            options={'verbose_name': 'Commande agricole', 'verbose_name_plural': 'Commandes agricoles', 'ordering': ['-date_creation']},
        ),
        migrations.AddIndex(model_name='commandelivraison', index=models.Index(fields=['statut', 'date_creation'], name='commande_statut_date_idx')),
    ]
