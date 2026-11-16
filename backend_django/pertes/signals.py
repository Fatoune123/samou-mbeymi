"""Signaux de traçabilité : chaque opération métier alimente l'historique du lot."""

from django.db.models.signals import pre_save, post_save, pre_delete
from django.dispatch import receiver

from .models import Recolte, Perte, EvenementTraceabilite


@receiver(pre_save, sender=Recolte)
def memoriser_etat_recolte(sender, instance, **kwargs):
    if instance.pk:
        ancien = sender.objects.filter(pk=instance.pk).only(
            "lieu_stockage", "quantite_kg", "culture_id", "date_recolte"
        ).first()
        if ancien:
            instance._ancien_lieu_stockage = ancien.lieu_stockage
            instance._ancienne_quantite_kg = ancien.quantite_kg
            instance._ancienne_culture_id = ancien.culture_id
            instance._ancienne_date_recolte = ancien.date_recolte


@receiver(post_save, sender=Recolte)
def tracer_cycle_recolte(sender, instance, created, **kwargs):
    auteur = instance.agriculteur.user
    if created:
        EvenementTraceabilite.objects.create(
            recolte=instance,
            type_evenement="creation",
            description="Création initiale de la récolte et ouverture du lot.",
            lieu=instance.lieu_stockage,
            quantite_kg=instance.quantite_kg,
            auteur=auteur,
        )
        return

    ancien_lieu = getattr(instance, "_ancien_lieu_stockage", instance.lieu_stockage)
    ancienne_quantite = getattr(instance, "_ancienne_quantite_kg", instance.quantite_kg)

    if ancien_lieu != instance.lieu_stockage:
        EvenementTraceabilite.objects.create(
            recolte=instance,
            type_evenement="deplacement" if ancien_lieu else "stockage",
            description=(
                f"Changement de lieu : {ancien_lieu or 'non renseigné'} "
                f"→ {instance.lieu_stockage or 'non renseigné'}."
            ),
            lieu=instance.lieu_stockage,
            quantite_kg=instance.quantite_kg,
            auteur=auteur,
        )

    if ancienne_quantite != instance.quantite_kg:
        EvenementTraceabilite.objects.create(
            recolte=instance,
            type_evenement="mise_a_jour",
            description=(
                f"Quantité de récolte modifiée : {ancienne_quantite} kg "
                f"→ {instance.quantite_kg} kg."
            ),
            lieu=instance.lieu_stockage,
            quantite_kg=instance.quantite_kg,
            auteur=auteur,
        )

    ancienne_culture_id = getattr(instance, "_ancienne_culture_id", instance.culture_id)
    if ancienne_culture_id != instance.culture_id:
        EvenementTraceabilite.objects.create(
            recolte=instance, type_evenement="mise_a_jour",
            description="Culture du lot modifiée.", lieu=instance.lieu_stockage,
            quantite_kg=instance.quantite_kg, auteur=auteur,
        )

    ancienne_date = getattr(instance, "_ancienne_date_recolte", instance.date_recolte)
    if ancienne_date != instance.date_recolte:
        EvenementTraceabilite.objects.create(
            recolte=instance, type_evenement="mise_a_jour",
            description=f"Date de récolte modifiée : {ancienne_date:%d/%m/%Y} → {instance.date_recolte:%d/%m/%Y}.",
            lieu=instance.lieu_stockage, quantite_kg=instance.quantite_kg, auteur=auteur,
        )


@receiver(pre_save, sender=Perte)
def memoriser_etat_perte(sender, instance, **kwargs):
    if instance.pk:
        ancienne = sender.objects.filter(pk=instance.pk).first()
        if ancienne:
            instance._ancienne_valeur_perte = {
                "type_perte": ancienne.type_perte,
                "quantite_perdue_kg": ancienne.quantite_perdue_kg,
                "statut": ancienne.statut,
                "description": ancienne.description,
                "recolte_id": ancienne.recolte_id,
            }


@receiver(post_save, sender=Perte)
def tracer_declaration_ou_modification_perte(sender, instance, created, **kwargs):
    recolte = instance.recolte
    auteur = recolte.agriculteur.user

    if created:
        EvenementTraceabilite.objects.create(
            recolte=recolte,
            type_evenement="perte",
            description=(
                f"Perte déclarée : {instance.get_type_perte_display()}. "
                f"{instance.description}"
            ).strip(),
            lieu=recolte.lieu_stockage,
            quantite_kg=instance.quantite_perdue_kg,
            auteur=auteur,
        )
        return

    ancien = getattr(instance, "_ancienne_valeur_perte", None)
    if ancien:
        changements = []
        if ancien["type_perte"] != instance.type_perte:
            changements.append(
                f"cause : {ancien['type_perte']} → {instance.type_perte}"
            )
        if ancien["quantite_perdue_kg"] != instance.quantite_perdue_kg:
            changements.append(
                f"quantité : {ancien['quantite_perdue_kg']} kg "
                f"→ {instance.quantite_perdue_kg} kg"
            )
        if ancien["statut"] != instance.statut:
            changements.append(
                f"statut : {ancien['statut']} → {instance.statut}"
            )
        if ancien["description"] != instance.description:
            changements.append("description modifiée")
        if ancien["recolte_id"] != instance.recolte_id:
            changements.append("perte rattachée à un autre lot")

        if changements:
            # Si la perte change de lot, conserver une trace sur les deux lots :
            # l'ancien lot enregistre le retrait et le nouveau lot le rattachement.
            ancien_recolte_id = ancien["recolte_id"]
            if ancien_recolte_id != instance.recolte_id:
                ancienne_recolte = Recolte.objects.select_related("agriculteur__user").get(pk=ancien_recolte_id)
                EvenementTraceabilite.objects.create(
                    recolte=ancienne_recolte,
                    type_evenement="mise_a_jour",
                    description=(
                        f"Une perte de {ancien['quantite_perdue_kg']} kg a été retirée de ce lot "
                        f"et rattachée au lot {recolte.numero_lot}."
                    ),
                    lieu=ancienne_recolte.lieu_stockage,
                    quantite_kg=ancien["quantite_perdue_kg"],
                    auteur=ancienne_recolte.agriculteur.user,
                )
                EvenementTraceabilite.objects.create(
                    recolte=recolte,
                    type_evenement="perte",
                    description=(
                        f"Perte de {instance.quantite_perdue_kg} kg transférée depuis le lot "
                        f"{ancienne_recolte.numero_lot}."
                    ),
                    lieu=recolte.lieu_stockage,
                    quantite_kg=instance.quantite_perdue_kg,
                    auteur=auteur,
                )
            else:
                EvenementTraceabilite.objects.create(
                    recolte=recolte,
                    type_evenement="mise_a_jour",
                    description="Modification d'une perte : " + "; ".join(changements) + ".",
                    lieu=recolte.lieu_stockage,
                    quantite_kg=instance.quantite_perdue_kg,
                    auteur=auteur,
                )


@receiver(pre_delete, sender=Perte)
def tracer_suppression_perte(sender, instance, **kwargs):
    recolte = instance.recolte
    EvenementTraceabilite.objects.create(
        recolte=recolte,
        type_evenement="mise_a_jour",
        description=(
            f"Suppression d'un signalement de perte : "
            f"{instance.get_type_perte_display()}, {instance.quantite_perdue_kg} kg."
        ),
        lieu=recolte.lieu_stockage,
        quantite_kg=instance.quantite_perdue_kg,
        auteur=recolte.agriculteur.user,
    )
