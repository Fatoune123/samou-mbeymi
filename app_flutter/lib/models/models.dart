class Culture {
  final int id;
  final String nom;
  final String description;
  Culture({required this.id, required this.nom, this.description = ''});
  factory Culture.fromJson(Map<String, dynamic> json) => Culture(
    id: json['id'] ?? 0, nom: json['nom'] ?? '', description: json['description'] ?? '',
  );
}

class Recolte {
  final int id, culture;
  final String cultureNom, dateRecolte, lieuStockage, notes;
  final double quantiteKg, totalPertesKg, pourcentagePerte;
  Recolte({required this.id, required this.culture, required this.cultureNom, required this.quantiteKg,
    required this.dateRecolte, required this.lieuStockage, required this.notes,
    required this.totalPertesKg, required this.pourcentagePerte});
  factory Recolte.fromJson(Map<String, dynamic> json) => Recolte(
    id: json['id'] ?? 0, culture: json['culture'] ?? 0, cultureNom: json['culture_nom'] ?? '',
    quantiteKg: double.tryParse('${json['quantite_kg']}') ?? 0,
    dateRecolte: json['date_recolte'] ?? '', lieuStockage: json['lieu_stockage'] ?? '', notes: json['notes'] ?? '',
    totalPertesKg: double.tryParse('${json['total_pertes_kg']}') ?? 0,
    pourcentagePerte: double.tryParse('${json['pourcentage_perte']}') ?? 0,
  );
}

class Perte {
  final int id, recolte;
  final String cultureNom, typePerte, typePerteDisplay, dateSignalement, statut, statutDisplay;
  final double quantitePerdueKg;
  Perte({required this.id, required this.recolte, required this.cultureNom, required this.typePerte,
    required this.typePerteDisplay, required this.quantitePerdueKg, required this.dateSignalement,
    required this.statut, required this.statutDisplay});
  factory Perte.fromJson(Map<String, dynamic> json) => Perte(
    id: json['id'] ?? 0, recolte: json['recolte'] ?? 0, cultureNom: json['culture_nom'] ?? '',
    typePerte: json['type_perte'] ?? '', typePerteDisplay: json['type_perte_display'] ?? '',
    quantitePerdueKg: double.tryParse('${json['quantite_perdue_kg']}') ?? 0,
    dateSignalement: json['date_signalement'] ?? '', statut: json['statut'] ?? '', statutDisplay: json['statut_display'] ?? '',
  );
}

class DashboardPoint {
  final String mois; final double productionKg, perteKg, productionPct, pertePct;
  DashboardPoint({required this.mois, required this.productionKg, required this.perteKg, required this.productionPct, required this.pertePct});
  factory DashboardPoint.fromJson(Map<String, dynamic> j) => DashboardPoint(
    mois: j['mois'] ?? '', productionKg: double.tryParse('${j['production_kg']}') ?? 0,
    perteKg: double.tryParse('${j['perte_kg']}') ?? 0, productionPct: double.tryParse('${j['production_pct']}') ?? 0,
    pertePct: double.tryParse('${j['perte_pct']}') ?? 0,
  );
}

class TableauBord {
  final int nbRecoltes, nbPertes;
  final double totalRecolteKg, totalPerteKg, tauxPerte, rendementConserve;
  final String niveauRisque, recommandation;
  final List<dynamic> pertesParType, alertes, recoltesRecentes, pertesRecentes;
  final List<DashboardPoint> evolutionMensuelle;
  TableauBord({required this.nbRecoltes, required this.nbPertes, required this.totalRecolteKg,
    required this.totalPerteKg, required this.tauxPerte, required this.rendementConserve,
    required this.niveauRisque, required this.recommandation, required this.pertesParType,
    required this.alertes, required this.recoltesRecentes, required this.pertesRecentes, required this.evolutionMensuelle});
  factory TableauBord.fromJson(Map<String, dynamic> j) => TableauBord(
    nbRecoltes: j['nb_recoltes'] ?? 0, nbPertes: j['nb_pertes'] ?? 0,
    totalRecolteKg: double.tryParse('${j['total_recolte_kg']}') ?? 0,
    totalPerteKg: double.tryParse('${j['total_perte_kg']}') ?? 0,
    tauxPerte: double.tryParse('${j['taux_perte']}') ?? 0,
    rendementConserve: double.tryParse('${j['rendement_conserve']}') ?? 0,
    niveauRisque: j['niveau_risque'] ?? 'faible', recommandation: j['recommandation'] ?? '',
    pertesParType: j['pertes_par_type'] ?? [], alertes: j['alertes'] ?? [],
    recoltesRecentes: j['recoltes_recentes'] ?? [], pertesRecentes: j['pertes_recentes'] ?? [],
    evolutionMensuelle: (j['evolution_mensuelle'] as List? ?? []).map((e) => DashboardPoint.fromJson(e)).toList(),
  );
}

class ProfilAgriculteur {
  final int id; final String username, nomComplet, email, telephone, region, nomExploitation;
  ProfilAgriculteur({required this.id, required this.username, required this.nomComplet, required this.email,
    required this.telephone, required this.region, required this.nomExploitation});
  factory ProfilAgriculteur.fromJson(Map<String,dynamic> j)=>ProfilAgriculteur(
    id:j['id']??0, username:j['username']??'', nomComplet:j['nom_complet']??'', email:j['email']??'',
    telephone:j['telephone']??'', region:j['region_display']??j['region']??'', nomExploitation:j['nom_exploitation']??'',
  );
}
