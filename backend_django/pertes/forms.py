from django import forms
from django.contrib.auth.models import User
from django.contrib.auth.forms import UserCreationForm
from decimal import Decimal
from django.db.models import Sum
from .models import Agriculteur, Recolte, Perte, Culture, REGIONS_SENEGAL


class InscriptionForm(UserCreationForm):
    first_name = forms.CharField(label="Prénom", max_length=100, required=True)
    last_name = forms.CharField(label="Nom", max_length=100, required=True)
    email = forms.EmailField(label="Email", required=True)
    telephone = forms.CharField(label="Téléphone", max_length=20, required=False)
    region = forms.ChoiceField(label="Région", choices=REGIONS_SENEGAL)
    nom_exploitation = forms.CharField(label="Nom de l'exploitation", max_length=150, required=False)

    class Meta:
        model = User
        fields = ['first_name', 'last_name', 'username', 'email', 'password1', 'password2']

    def save(self, commit=True):
        user = super().save(commit=commit)
        if commit:
            Agriculteur.objects.create(
                user=user,
                telephone=self.cleaned_data['telephone'],
                region=self.cleaned_data['region'],
                nom_exploitation=self.cleaned_data['nom_exploitation'],
            )
        return user


class RecolteForm(forms.ModelForm):
    def clean_quantite_kg(self):
        quantite = self.cleaned_data['quantite_kg']
        if quantite <= 0:
            raise forms.ValidationError('La quantité récoltée doit être supérieure à 0 kg.')
        if self.instance and self.instance.pk:
            pertes = self.instance.pertes.aggregate(total=Sum('quantite_perdue_kg'))['total'] or Decimal('0.00')
            if pertes > quantite:
                raise forms.ValidationError(
                    f'Impossible de réduire la récolte à {quantite} kg : {pertes} kg de pertes sont déjà enregistrées. Corrigez les pertes avant de réduire la quantité.'
                )
        return quantite

    class Meta:
        model = Recolte
        fields = ['culture', 'quantite_kg', 'date_recolte', 'lieu_stockage', 'notes']
        widgets = {
            'quantite_kg': forms.NumberInput(attrs={'min': '0.01', 'step': '0.01', 'placeholder': 'Ex. : 250'}),
            'date_recolte': forms.DateInput(attrs={'type': 'date'}, format='%Y-%m-%d'),
            'lieu_stockage': forms.TextInput(attrs={'list': 'lieux-stockage', 'placeholder': 'Ex. : Magasin, silo, entrepôt…', 'autocomplete': 'off'}),
            'notes': forms.Textarea(attrs={'rows': 3}),
        }
        labels = {
            'quantite_kg': 'Quantité récoltée (kg)',
            'date_recolte': 'Date de récolte',
            'lieu_stockage': 'Lieu de stockage',
        }


class PerteForm(forms.ModelForm):
    class Meta:
        model = Perte
        fields = ['recolte', 'type_perte', 'quantite_perdue_kg', 'description', 'statut', 'photo']
        widgets = {
            'quantite_perdue_kg': forms.NumberInput(attrs={'min': '0.01', 'step': '0.01'}),
            'description': forms.Textarea(attrs={'rows': 3}),
        }
        labels = {
            'quantite_perdue_kg': 'Quantité perdue (kg)',
        }

    def __init__(self, *args, agriculteur=None, **kwargs):
        super().__init__(*args, **kwargs)
        if agriculteur is not None:
            self.fields['recolte'].queryset = Recolte.objects.filter(agriculteur=agriculteur)

    def clean(self):
        cleaned = super().clean()
        recolte = cleaned.get('recolte')
        quantite = cleaned.get('quantite_perdue_kg')
        if recolte and quantite is not None:
            current = recolte.pertes.exclude(pk=self.instance.pk).aggregate(
                total=Sum('quantite_perdue_kg')
            )['total'] or Decimal('0.00')
            if current + quantite > recolte.quantite_kg:
                disponible = recolte.quantite_kg - current
                self.add_error(
                    'quantite_perdue_kg',
                    f'Quantité excessive. Il reste au maximum {disponible} kg déclarables pour ce lot.'
                )
        return cleaned


class CultureForm(forms.ModelForm):
    class Meta:
        model = Culture
        fields = ['nom', 'description']


class PredictionForm(forms.Form):
    culture = forms.ModelChoiceField(queryset=Culture.objects.all(), label="Culture")
    date_recolte = forms.DateField(label="Date prévue de récolte", widget=forms.DateInput(attrs={"type": "date"}))
    quantite_kg = forms.DecimalField(label="Quantité prévue (kg)", min_value=Decimal("0.01"), max_digits=10, decimal_places=2, widget=forms.NumberInput(attrs={'min': '0.01', 'step': '0.01', 'placeholder': 'Ex. : 250'}))
    lieu_stockage = forms.CharField(label="Lieu / type de stockage", max_length=150, required=False, widget=forms.TextInput(attrs={"placeholder": "Entrepôt, silo, magasin…"}))
