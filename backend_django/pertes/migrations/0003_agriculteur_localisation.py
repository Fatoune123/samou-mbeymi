from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [("pertes", "0002_validators")]
    operations = [
        migrations.AddField(model_name="agriculteur", name="latitude", field=models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
        migrations.AddField(model_name="agriculteur", name="longitude", field=models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
        migrations.AddField(model_name="agriculteur", name="localisation_nom", field=models.CharField(blank=True, max_length=150)),
    ]
