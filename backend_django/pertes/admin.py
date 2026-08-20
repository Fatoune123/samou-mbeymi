from django.contrib import admin
from .models import Agriculteur, Culture, Recolte, Perte, Stockage


@admin.register(Agriculteur)
class AgriculteurAdmin(admin.ModelAdmin):
    list_display = ('user', 'region', 'nom_exploitation', 'telephone', 'date_inscription')
    list_filter = ('region',)
    search_fields = ('user__username', 'user__first_name', 'user__last_name', 'nom_exploitation')


@admin.register(Culture)
class CultureAdmin(admin.ModelAdmin):
    list_display = ('nom',)
    search_fields = ('nom',)


class PerteInline(admin.TabularInline):
    model = Perte
    extra = 0


@admin.register(Recolte)
class RecolteAdmin(admin.ModelAdmin):
    list_display = ('agriculteur', 'culture', 'quantite_kg', 'date_recolte', 'total_pertes_kg', 'pourcentage_perte')
    list_filter = ('culture', 'date_recolte')
    search_fields = ('agriculteur__user__username', 'culture__nom')
    inlines = [PerteInline]


@admin.register(Perte)
class PerteAdmin(admin.ModelAdmin):
    list_display = ('recolte', 'type_perte', 'quantite_perdue_kg', 'statut', 'date_signalement')
    list_filter = ('type_perte', 'statut')
    search_fields = ('recolte__culture__nom',)


@admin.register(Stockage)
class StockageAdmin(admin.ModelAdmin):
    list_display = ('nom', 'region', 'capacite_kg', 'disponible', 'contact')
    list_filter = ('region', 'disponible')
