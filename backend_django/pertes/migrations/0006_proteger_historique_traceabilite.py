from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ('pertes', '0005_evenement_traceabilite'),
    ]

    operations = [
        migrations.AlterField(
            model_name='evenementtraceabilite',
            name='recolte',
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.PROTECT,
                related_name='evenements_traceabilite',
                to='pertes.recolte',
            ),
        ),
    ]
