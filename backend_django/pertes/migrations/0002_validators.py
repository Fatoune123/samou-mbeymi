from django.db import migrations, models
from django.core.validators import MinValueValidator

class Migration(migrations.Migration):
    dependencies=[('pertes','0001_initial')]
    operations=[
        migrations.AlterField(model_name='recolte',name='quantite_kg',field=models.DecimalField(decimal_places=2,help_text='Quantité récoltée en kg',max_digits=10,validators=[MinValueValidator(0.01)])),
        migrations.AlterField(model_name='perte',name='quantite_perdue_kg',field=models.DecimalField(decimal_places=2,max_digits=10,validators=[MinValueValidator(0.01)])),
        migrations.AlterField(model_name='stockage',name='capacite_kg',field=models.DecimalField(decimal_places=2,max_digits=10,validators=[MinValueValidator(0)])),
    ]
