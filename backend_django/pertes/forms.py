from django import forms
from django.contrib.auth.models import User
from django.contrib.auth.forms import UserCreationForm
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
    class Meta:
        model = Recolte
        fields = ['culture', 'quantite_kg', 'date_recolte', 'lieu_stockage', 'notes']
        widgets = {
            'date_recolte': forms.DateInput(attrs={'type': 'date'}),
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
            current = sum(float(p.quantite_perdue_kg) for p in recolte.pertes.exclude(pk=self.instance.pk))
            if current + float(quantite) > float(recolte.quantite_kg):
                self.add_error('quantite_perdue_kg', 'La perte totale ne peut pas dépasser la quantité récoltée.')
        return cleaned


class CultureForm(forms.ModelForm):
    class Meta:
        model = Culture
        fields = ['nom', 'description']


class PredictionForm(forms.Form):
    culture = forms.ModelChoiceField(queryset=Culture.objects.all(), label="Culture")
    date_recolte = forms.DateField(label="Date prévue de récolte", widget=forms.DateInput(attrs={"type": "date"}))
    quantite_kg = forms.DecimalField(label="Quantité prévue (kg)", min_value=0.01, max_digits=10, decimal_places=2)
    lieu_stockage = forms.CharField(label="Lieu / type de stockage", max_length=150, required=False, widget=forms.TextInput(attrs={"placeholder": "Entrepôt, silo, magasin…"}))
