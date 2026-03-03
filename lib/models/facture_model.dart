// lib/models/facture_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';

class FactureModel {
  final String? id; 
  final String propertyId;
  final String clientId;
  final String nomClient;
  final String telClient;
  final String nomBailleur;
  final String telBailleur;
  final String refMaison;
  final double loyer;
  final int nbMoisGarantie;
  final String nomOffre;
  final double comLocatairePercent;
  final double comBailleurPercent;
  final bool transportChoisi;
  final double tauxApplique;

  final String? cadeauId;
  final String? cadeauTaille;
  final String? cadeauStyle;

  final String? province;
  final String? ville;
  final String? commune;

  final String statut;
  final dynamic dateCreation;
  final String? urlPreuve;
  final String? methodePaiement;
  final String? motifRejet;
  final String? adminValidator;
  final dynamic dateActionAdmin;

  final String? statutCadeau;
  final String? statutTransport;

  FactureModel({
    this.id,
    required this.propertyId,
    required this.clientId,
    required this.nomClient,
    required this.telClient,
    required this.nomBailleur,
    required this.telBailleur,
    required this.refMaison,
    required this.loyer,
    required this.nbMoisGarantie,
    required this.nomOffre,
    required double comLocatairePercent,
    required double comBailleurPercent,
    required this.transportChoisi,
    this.tauxApplique = 2500.0,
    this.cadeauId,
    this.cadeauTaille,
    this.cadeauStyle,
    this.province,
    this.ville,
    this.commune,
    this.statut = 'pending',
    this.dateCreation,
    this.urlPreuve,
    this.methodePaiement,
    this.motifRejet,
    this.adminValidator,
    this.dateActionAdmin,
    this.statutCadeau,
    this.statutTransport,
  }) : 
    this.comLocatairePercent = comLocatairePercent > 0 && comLocatairePercent < 1 
        ? comLocatairePercent * 100 
        : comLocatairePercent,
    this.comBailleurPercent = comBailleurPercent > 0 && comBailleurPercent < 1 
        ? comBailleurPercent * 100 
        : comBailleurPercent;

  // --- GETTERS ---
  double get commissionLocataireUSD => loyer * (comLocatairePercent / 100);
  double get commissionBailleurUSD => loyer * (comBailleurPercent / 100);

  double get totalUSD {
    double somme = commissionLocataireUSD + commissionBailleurUSD;
    return (somme * 100).roundToDouble() / 100;
  }

  // Calcul dynamique basé sur le taux enregistré à la création
  double get totalCDF => (totalUSD * tauxApplique).roundToDouble();

  static double _ensurePercentage(dynamic value) {
    double val = (value ?? 0.0).toDouble();
    if (val > 0 && val < 1) return val * 100;
    return val;
  }

  // ✅ TO MAP (Pour Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'propertyId': propertyId,
      'clientId': clientId,
      FactureFields.nomClient: nomClient,
      FactureFields.telClient: telClient,
      'nomBailleur': nomBailleur,
      'telBailleur': telBailleur,
      FactureFields.refMaison: refMaison,
      'loyer': loyer,
      'nbMoisGarantie': nbMoisGarantie,
      'nomOffre': nomOffre,
      'comLocatairePercent': comLocatairePercent,
      'comBailleurPercent': comBailleurPercent,
      'transportChoisi': transportChoisi,
      'tauxApplique': tauxApplique,
      'cadeauId': cadeauId,
      'cadeauTaille': cadeauTaille,
      'cadeauStyle': cadeauStyle,
      FactureFields.province: province,
      'ville': ville,
      'commune': commune,
      FactureFields.totalUSD: totalUSD,
      'totalCDF': totalCDF, // 🔥 AJOUTÉ : Crucial pour le suivi comptable
      FactureFields.statut: statut,
      FactureFields.paymentStatus: statut,
      FactureFields.urlPreuve: urlPreuve,
      'methodePaiement': methodePaiement,
      FactureFields.motifRejet: motifRejet,
      FactureFields.adminValidator: adminValidator,
      FactureFields.dateCreation: dateCreation ?? FieldValue.serverTimestamp(),
      'dateActionAdmin': dateActionAdmin,
      'statutCadeau': statutCadeau ?? (cadeauId == 'Aucun' || cadeauId == null ? 'termine' : 'nouveau'),
      'statutTransport': statutTransport ?? (transportChoisi ? 'nouveau' : 'termine'),
    };
  }

  // ✅ FROM MAP
  factory FactureModel.fromMap(Map<String, dynamic> map) {
    return FactureModel(
      id: map['id'],
      propertyId: map['propertyId'] ?? '',
      clientId: map['clientId'] ?? '',
      nomClient: map[FactureFields.nomClient] ?? '',
      telClient: map[FactureFields.telClient] ?? '',
      nomBailleur: map['nomBailleur'] ?? '',
      telBailleur: map['telBailleur'] ?? '',
      refMaison: map[FactureFields.refMaison] ?? '',
      loyer: (map['loyer'] ?? 0).toDouble(),
      nbMoisGarantie: map['nbMoisGarantie'] ?? 3,
      nomOffre: map['nomOffre'] ?? '',
      comLocatairePercent: _ensurePercentage(map['comLocatairePercent']),
      comBailleurPercent: _ensurePercentage(map['comBailleurPercent']),
      transportChoisi: map['transportChoisi'] ?? false,
      tauxApplique: (map['tauxApplique'] ?? 2500.0).toDouble(),
      cadeauId: map['cadeauId'],
      cadeauTaille: map['cadeauTaille'],
      cadeauStyle: map['cadeauStyle'],
      province: map[FactureFields.province],
      ville: map['ville'],
      commune: map['commune'],
      statut: map[FactureFields.paymentStatus] ?? map[FactureFields.statut] ?? 'pending',
      urlPreuve: map[FactureFields.urlPreuve],
      methodePaiement: map['methodePaiement'],
      motifRejet: map[FactureFields.motifRejet],
      adminValidator: map[FactureFields.adminValidator],
      dateCreation: map[FactureFields.dateCreation],
      dateActionAdmin: map['dateActionAdmin'],
      statutCadeau: map['statutCadeau'],
      statutTransport: map['statutTransport'],
    );
  }

  // ✅ COPY WITH
  FactureModel copyWith({
    String? id,
    String? statut,
    String? urlPreuve,
    String? methodePaiement,
    String? motifRejet,
    String? province,
    String? statutCadeau,
    String? statutTransport,
    String? clientId,
    dynamic dateCreation,
  }) {
    return FactureModel(
      id: id ?? this.id,
      propertyId: propertyId,
      clientId: clientId ?? this.clientId,
      nomClient: nomClient,
      telClient: telClient,
      nomBailleur: nomBailleur,
      telBailleur: telBailleur,
      refMaison: refMaison,
      loyer: loyer,
      nbMoisGarantie: nbMoisGarantie,
      nomOffre: nomOffre,
      comLocatairePercent: comLocatairePercent,
      comBailleurPercent: comBailleurPercent,
      transportChoisi: transportChoisi,
      tauxApplique: tauxApplique,
      cadeauId: cadeauId,
      cadeauTaille: cadeauTaille,
      cadeauStyle: cadeauStyle,
      province: province ?? this.province,
      ville: ville,
      commune: commune,
      statut: statut ?? this.statut,
      urlPreuve: urlPreuve ?? this.urlPreuve,
      methodePaiement: methodePaiement ?? this.methodePaiement,
      motifRejet: motifRejet ?? this.motifRejet,
      adminValidator: adminValidator,
      dateCreation: dateCreation ?? this.dateCreation,
      dateActionAdmin: dateActionAdmin,
      statutCadeau: statutCadeau ?? this.statutCadeau,
      statutTransport: statutTransport ?? this.statutTransport,
    );
  }
}