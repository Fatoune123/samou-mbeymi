from decimal import Decimal
from datetime import datetime, time
from django.utils import timezone
from django.conf import settings
from django.db import migrations, models
import django.core.validators
import django.db.models.deletion


def creer_historique_initial(apps, schema_editor):
    """Initialise la traçabilité des récoltes et pertes déjà enregistrées."""
    Recolte = apps.get_model('pertes', 'Recolte')
    Perte = apps.get_model('pertes', 'Perte')
    Evenement = apps.get_model('pertes', 'EvenementTraceabilite')
    db = schema_editor.connection.alias

    evenements = []
    dates = []
    for recolte in Recolte.objects.using(db).select_related('agriculteur').iterator():
        auteur_id = None
        try:
            auteur_id = recolte.agriculteur.user_id
        except Exception:
            pass
        evenement = Evenement(
            recolte_id=recolte.pk,
            type_evenement='creation',
            description='Récolte existante importée dans l’historique de traçabilité.',
            lieu=recolte.lieu_stockage or '',
            quantite_kg=recolte.quantite_kg,
            auteur_id=auteur_id,
        )
        evenements.append(evenement)
        dates.append((len(evenements) - 1, recolte.date_recolte))

    Evenement.objects.using(db).bulk_create(evenements, batch_size=500)
    # La date métier de récolte est utilisée pour dater l'événement initial.
    for index, date_metier in dates:
        valeur = timezone.make_aware(datetime.combine(date_metier, time.min)) if timezone.is_naive(datetime.combine(date_metier, time.min)) else datetime.combine(date_metier, time.min)
        Evenement.objects.using(db).filter(
            recolte_id=evenements[index].recolte_id,
            type_evenement='creation',
            description='Récolte existante importée dans l’historique de traçabilité.',
        ).update(date_evenement=valeur)

    pertes = Perte.objects.using(db).select_related('recolte__agriculteur').iterator()
    for perte in pertes:
        auteur_id = None
        try:
            auteur_id = perte.recolte.agriculteur.user_id
        except Exception:
            pass
        evenement = Evenement.objects.using(db).create(
            recolte_id=perte.recolte_id,
            type_evenement='perte',
            description=f'Perte déjà enregistrée : {perte.get_type_perte_display()} (signalée le {perte.date_signalement:%d/%m/%Y}). {perte.description}'.strip(),
            lieu=perte.recolte.lieu_stockage or '',
            quantite_kg=perte.quantite_perdue_kg,
            auteur_id=auteur_id,
        )
        date_metier = datetime.combine(perte.date_signalement, time.min)
        if timezone.is_naive(date_metier):
            date_metier = timezone.make_aware(date_metier)
        Evenement.objects.using(db).filter(pk=evenement.pk).update(date_evenement=date_metier)


def annuler_historique_initial(apps, schema_editor):
    # Ne pas effacer l'historique : les événements sont conservés lors d'un rollback.
    pass


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('pertes', '0004_marketplace_livraisons'),
    ]

    operations = [
        migrations.CreateModel(
            name='EvenementTraceabilite',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('type_evenement', models.CharField(
                    choices=[
                        ('creation', 'Création du lot'),
                        ('stockage', 'Mise en stockage'),
                        ('deplacement', 'Déplacement'),
                        ('controle', 'Contrôle du lot'),
                        ('perte', 'Perte déclarée'),
                        ('mise_a_jour', 'Mise à jour'),
                        ('autre', 'Autre événement'),
                    ],
                    db_index=True, max_length=20
                )),
                ('description', models.TextField(blank=True)),
                ('lieu', models.CharField(blank=True, max_length=150)),
                ('quantite_kg', models.DecimalField(
                    blank=True, decimal_places=2, max_digits=10, null=True,
                    validators=[django.core.validators.MinValueValidator(Decimal('0.01'))],
                    help_text='Quantité concernée, si applicable.'
                )),
                ('date_evenement', models.DateTimeField(auto_now_add=True, db_index=True)),
                ('auteur', models.ForeignKey(
                    blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL,
                    related_name='evenements_traceabilite', to=settings.AUTH_USER_MODEL
                )),
                ('recolte', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='evenements_traceabilite', to='pertes.recolte'
                )),
            ],
            options={
                'verbose_name': 'Événement de traçabilité',
                'verbose_name_plural': 'Événements de traçabilité',
                'ordering': ['-date_evenement'],
                'indexes': [models.Index(fields=['recolte', 'date_evenement'], name='trace_recolte_date_idx')],
            },
        ),
        migrations.RunPython(creer_historique_initial, annuler_historique_initial),
    ]
