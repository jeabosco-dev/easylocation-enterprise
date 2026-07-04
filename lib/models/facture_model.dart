// lib/models/facture_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

class FactureModel {
  final String? id;
  final String propertyId;
  final String? bailleurId;
  final String clientId;
  final String? agentTerrainId;
  final String? assignedAdminId;
  final String nomClient;
  final String telClient;

  final String? nomBailleur;
  final String? telBailleur;
  final String refMaison;
  
  final String? categorieBien;
  final String? serviceEligible;
  final String? categorieEligible;

  final double loyer;
  final int nbMoisGarantie;
  final double montantGarantieTotal;

  final String nomOffre;
  final String? typeService;
  final double comLocatairePercent;
  final double comBailleurPercent;
  final double tauxApplique;

  final double montantWallet;
  final double montantExterne;
  final double montantCashback;
  final double? partLocataire;

  final double commissionLocataire;
  final double commissionBailleur;

  final String? promoCode;
  final String? promoId;
  final double montantRemise;
  final double totalNetUSD;

  final String? cadeauId;
  final String? cadeauTaille;
  final String? cadeauStyle;
  final String? province;

  final String? ville;
  final String? commune;
  final String? villeSpecifique;
  final String? communeSpecifique;

  final String paymentStatus;
  final String etapeDossier;

  final DateTime? dateCreation;
  final DateTime? dateExpiration;
  final String? urlPreuve;
  final String? methodePaiement;
  final String? motifRejet;
  final DateTime? dateActionAdmin;
  final String? statutCadeau;

  FactureModel({
    this.id,
    this.bailleurId,
    this.assignedAdminId,
    required this.propertyId,
    required this.clientId,
    this.agentTerrainId,
    required this.nomClient,
    required this.telClient,
    this.nomBailleur,
    this.telBailleur,
    required this.refMaison,
    this.categorieBien,
    this.serviceEligible,
    this.categorieEligible,
    this.loyer = 0.0,
    this.nbMoisGarantie = 0,
    this.montantGarantieTotal = 0.0,
    required this.nomOffre,
    this.typeService = 'standard',
    required double comLocatairePercent,
    required double comBailleurPercent,
    this.tauxApplique = 2500.0,
    this.montantWallet = 0.0,
    this.montantExterne = 0.0,
    this.montantCashback = 0.0,
    this.partLocataire,
    this.commissionLocataire = 0.0,
    this.commissionBailleur = 0.0,
    this.promoCode,
    this.promoId,
    this.montantRemise = 0.0,
    this.totalNetUSD = 0.0,
    this.cadeauId,
    this.cadeauTaille,
    this.cadeauStyle,
    this.province,
    this.ville,
    this.commune,
    this.villeSpecifique,
    this.communeSpecifique,
    this.paymentStatus = FactureFields.statusPending,
    this.etapeDossier = FactureFields.etapeNouveau,
    this.dateCreation,
    this.dateExpiration,
    this.urlPreuve,
    this.methodePaiement,
    this.motifRejet,
    this.dateActionAdmin,
    this.statutCadeau,
  })  : this.comLocatairePercent = comLocatairePercent > 0 && comLocatairePercent < 1
            ? comLocatairePercent * 100
            : comLocatairePercent,
        this.comBailleurPercent = comBailleurPercent > 0 && comBailleurPercent < 1
            ? comBailleurPercent * 100
            : comBailleurPercent;

  FactureModel copyWith({
    String? id,
    String? bailleurId,
    String? agentTerrainId,
    String? assignedAdminId,
    String? paymentStatus,
    String? etapeDossier,
    String? urlPreuve,
    String? methodePaiement,
    String? motifRejet,
    DateTime? dateActionAdmin,
    DateTime? dateExpiration,
    String? statutCadeau,
    String? telBailleur,
    String? nomBailleur,
    String? categorieBien,
    String? serviceEligible,
    String? categorieEligible,
    String? typeService,
    double? montantWallet,
    double? montantExterne,
    double? montantCashback,
    double? partLocataire,
    double? loyer,
    int? nbMoisGarantie,
    double? montantGarantieTotal,
    String? province,
    String? ville,
    String? commune,
    String? villeSpecifique,
    String? communeSpecifique,
    double? commissionLocataire,
    double? commissionBailleur,
    String? promoCode,
    String? promoId,
    double? montantRemise,
    double? totalNetUSD,
    String? cadeauId,
    String? cadeauTaille,
    String? cadeauStyle,
  }) {
    return FactureModel(
      id: id ?? this.id,
      bailleurId: bailleurId ?? this.bailleurId,
      agentTerrainId: agentTerrainId ?? this.agentTerrainId,
      assignedAdminId: assignedAdminId ?? this.assignedAdminId,
      propertyId: this.propertyId,
      clientId: this.clientId,
      nomClient: this.nomClient,
      telClient: this.telClient,
      nomBailleur: nomBailleur ?? this.nomBailleur,
      telBailleur: telBailleur ?? this.telBailleur,
      refMaison: this.refMaison,
      categorieBien: categorieBien ?? this.categorieBien,
      serviceEligible: serviceEligible ?? this.serviceEligible,
      categorieEligible: categorieEligible ?? this.categorieEligible,
      loyer: loyer ?? this.loyer,
      nbMoisGarantie: nbMoisGarantie ?? this.nbMoisGarantie,
      montantGarantieTotal: montantGarantieTotal ?? this.montantGarantieTotal,
      nomOffre: this.nomOffre,
      typeService: typeService ?? this.typeService,
      comLocatairePercent: this.comLocatairePercent,
      comBailleurPercent: this.comBailleurPercent,
      tauxApplique: this.tauxApplique,
      montantWallet: montantWallet ?? this.montantWallet,
      montantExterne: montantExterne ?? this.montantExterne,
      montantCashback: montantCashback ?? this.montantCashback,
      partLocataire: partLocataire ?? this.partLocataire,
      commissionLocataire: commissionLocataire ?? this.commissionLocataire,
      commissionBailleur: commissionBailleur ?? this.commissionBailleur,
      promoCode: promoCode ?? this.promoCode,
      promoId: promoId ?? this.promoId,
      montantRemise: montantRemise ?? this.montantRemise,
      totalNetUSD: totalNetUSD ?? this.totalNetUSD,
      cadeauId: cadeauId ?? this.cadeauId,
      cadeauTaille: cadeauTaille ?? this.cadeauTaille,
      cadeauStyle: cadeauStyle ?? this.cadeauStyle,
      province: province ?? this.province,
      ville: ville ?? this.ville,
      commune: commune ?? this.commune,
      villeSpecifique: villeSpecifique ?? this.villeSpecifique,
      communeSpecifique: communeSpecifique ?? this.communeSpecifique,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      etapeDossier: etapeDossier ?? this.etapeDossier,
      dateCreation: this.dateCreation,
      dateExpiration: dateExpiration ?? this.dateExpiration,
      urlPreuve: urlPreuve ?? this.urlPreuve,
      methodePaiement: methodePaiement ?? this.methodePaiement,
      motifRejet: motifRejet ?? this.motifRejet,
      dateActionAdmin: dateActionAdmin ?? this.dateActionAdmin,
      statutCadeau: statutCadeau ?? this.statutCadeau,
    );
  }

  double get commissionLocataireUSD => _round(loyer * (comLocatairePercent / 100));
  double get commissionBailleurUSD => _round(loyer * (comBailleurPercent / 100));

  double get totalUSD {
    if (comLocatairePercent == 0 && comBailleurPercent == 0) return loyer;
    return _round(commissionLocataireUSD + commissionBailleurUSD);
  }

  double get totalCDF => (totalUSD * tauxApplique).ceilToDouble();
  bool get estSoldee => (montantWallet + montantExterne + montantCashback) >= (totalUSD - 0.01);
  double _round(double value) => (value * 100).roundToDouble() / 100;

  static double _ensurePercentage(dynamic value) {
    double val = (value ?? 0.0).toDouble();
    if (val > 0 && val < 1) return val * 100;
    return val;
  }

  static DateTime? _convertToDateTime(dynamic date) {
    if (date == null) return null;
    if (date is Timestamp) return date.toDate();
    if (date is String) return DateTime.tryParse(date);
    if (date is DateTime) return date;
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      FactureFields.id: id,
      FactureFields.propertyId: propertyId,
      FactureFields.bailleurId: bailleurId,
      FactureFields.clientId: clientId,
      FactureFields.agentTerrainId: agentTerrainId,
      FactureFields.assignedAdminId: assignedAdminId,
      FactureFields.nomClient: nomClient,
      FactureFields.telClient: telClient,
      FactureFields.nomBailleur: nomBailleur,
      FactureFields.telBailleur: telBailleur,
      FactureFields.refMaison: refMaison,
      'categorieBien': categorieBien,
      'serviceEligible': serviceEligible,
      'categorieEligible': categorieEligible,
      FactureFields.loyer: loyer,
      FactureFields.nbMoisGarantie: nbMoisGarantie,
      'montantGarantieTotal': montantGarantieTotal,
      FactureFields.nomOffre: nomOffre,
      FactureFields.typeService: typeService ?? 'standard',
      FactureFields.comLocatairePercent: comLocatairePercent,
      FactureFields.comBailleurPercent: comBailleurPercent,
      FactureFields.tauxApplique: tauxApplique,
      FactureFields.montantWallet: montantWallet,
      FactureFields.montantExterne: montantExterne,
      FactureFields.montantCashback: montantCashback,
      'partLocataire': partLocataire,
      FactureFields.commissionLocataire: commissionLocataireUSD,
      FactureFields.commissionBailleur: commissionBailleurUSD,
      'promoCode': promoCode,
      'promoId': promoId,
      'montantRemise': montantRemise,
      'totalNetUSD': totalNetUSD,
      FactureFields.cadeauId: cadeauId,
      FactureFields.cadeauTaille: cadeauTaille,
      FactureFields.cadeauStyle: cadeauStyle,
      FactureFields.province: province,
      FactureFields.ville: ville?.toLowerCase().trim(),
      FactureFields.commune: commune,
      FactureFields.villeSpecifique: villeSpecifique,
      FactureFields.communeSpecifique: communeSpecifique,
      FactureFields.totalUSD: totalUSD,
      FactureFields.totalCDF: totalCDF,
      FactureFields.paymentStatus: paymentStatus.toLowerCase().trim(),
      FactureFields.etapeDossier: etapeDossier.toLowerCase().trim(),
      FactureFields.urlPreuve: urlPreuve,
      FactureFields.methodePaiement: methodePaiement?.toLowerCase().trim(),
      FactureFields.motifRejet: motifRejet,
      FactureFields.dateCreation: dateCreation != null ? Timestamp.fromDate(dateCreation!) : FieldValue.serverTimestamp(),
      FactureFields.dateExpiration: dateExpiration != null ? Timestamp.fromDate(dateExpiration!) : null,
      FactureFields.dateActionAdmin: dateActionAdmin != null ? Timestamp.fromDate(dateActionAdmin!) : null,
      FactureFields.statutCadeau: statutCadeau ?? (cadeauId == 'Aucun' || cadeauId == null ? FactureFields.statutTermine : FactureFields.etapeNouveau),
    };
  }

  factory FactureModel.fromMap(Map<String, dynamic> map, String docId) {
    return FactureModel(
      id: docId,
      propertyId: map[FactureFields.propertyId] ?? '',
      bailleurId: map[FactureFields.bailleurId],
      clientId: map[FactureFields.clientId] ?? '',
      agentTerrainId: map[FactureFields.agentTerrainId],
      assignedAdminId: map[FactureFields.assignedAdminId],
      nomClient: map[FactureFields.nomClient] ?? '',
      telClient: map[FactureFields.telClient] ?? '',
      nomBailleur: map[FactureFields.nomBailleur],
      telBailleur: map[FactureFields.telBailleur],
      refMaison: map[FactureFields.refMaison] ?? '',
      categorieBien: map['categorieBien'],
      serviceEligible: map['serviceEligible'],
      categorieEligible: map['categorieEligible'],
      loyer: (map[FactureFields.loyer] ?? 0.0).toDouble(),
      nbMoisGarantie: map[FactureFields.nbMoisGarantie] ?? 0,
      montantGarantieTotal: (map['montantGarantieTotal'] ?? 0.0).toDouble(),
      nomOffre: map[FactureFields.nomOffre] ?? '',
      typeService: map[FactureFields.typeService] ?? 'standard',
      comLocatairePercent: _ensurePercentage(map[FactureFields.comLocatairePercent]),
      comBailleurPercent: _ensurePercentage(map[FactureFields.comBailleurPercent]),
      tauxApplique: (map[FactureFields.tauxApplique] ?? 2500.0).toDouble(),
      montantWallet: (map[FactureFields.montantWallet] ?? 0.0).toDouble(),
      montantExterne: (map[FactureFields.montantExterne] ?? 0.0).toDouble(),
      montantCashback: (map[FactureFields.montantCashback] ?? 0.0).toDouble(),
      partLocataire: (map['partLocataire'] ?? 0.0).toDouble(),
      commissionLocataire: (map[FactureFields.commissionLocataire] ?? 0.0).toDouble(),
      commissionBailleur: (map[FactureFields.commissionBailleur] ?? 0.0).toDouble(),
      promoCode: map['promoCode'],
      promoId: map['promoId'],
      montantRemise: (map['montantRemise'] ?? 0.0).toDouble(),
      totalNetUSD: (map['totalNetUSD'] ?? 0.0).toDouble(),
      cadeauId: map[FactureFields.cadeauId],
      cadeauTaille: map[FactureFields.cadeauTaille],
      cadeauStyle: map[FactureFields.cadeauStyle],
      province: map[FactureFields.province],
      ville: map[FactureFields.ville],
      commune: map[FactureFields.commune],
      villeSpecifique: map[FactureFields.villeSpecifique],
      communeSpecifique: map[FactureFields.communeSpecifique],
      paymentStatus: (map[FactureFields.paymentStatus] ?? FactureFields.statusPending).toString().toLowerCase().trim(),
      etapeDossier: (map[FactureFields.etapeDossier] ?? FactureFields.etapeNouveau).toString().toLowerCase().trim(),
      urlPreuve: map[FactureFields.urlPreuve],
      methodePaiement: map[FactureFields.methodePaiement]?.toString().toLowerCase().trim(),
      motifRejet: map[FactureFields.motifRejet],
      dateCreation: _convertToDateTime(map[FactureFields.dateCreation]),
      dateExpiration: _convertToDateTime(map[FactureFields.dateExpiration]),
      dateActionAdmin: _convertToDateTime(map[FactureFields.dateActionAdmin]),
      statutCadeau: map[FactureFields.statutCadeau],
    );
  }

  factory FactureModel.fromServiceMap(Map<String, dynamic> map, String docId) {
    return FactureModel(
      id: docId,
      propertyId: 'SERVICE',
      clientId: map[FactureFields.clientId] ?? '',
      nomClient: map[FactureFields.nomClient] ?? 'Client',
      telClient: map[FactureFields.telClient] ?? '',
      nomBailleur: "EasyLocation Service",
      telBailleur: "Administration",
      refMaison: map[FactureFields.refMaison] ?? 'REF-SERV',
      loyer: (map[FactureFields.loyer] ?? 0.0).toDouble(),
      nbMoisGarantie: 0,
      montantGarantieTotal: 0.0,
      nomOffre: map[FactureFields.nomOffre] ?? 'Prestation de service',
      typeService: map[FactureFields.typeService] ?? 'standard',
      comLocatairePercent: 0,
      comBailleurPercent: 0,
      commissionLocataire: 0,
      commissionBailleur: 0,
      montantWallet: (map[FactureFields.montantWallet] ?? 0.0).toDouble(),
      montantExterne: (map[FactureFields.montantExterne] ?? 0.0).toDouble(),
      montantCashback: (map[FactureFields.montantCashback] ?? 0.0).toDouble(),
      paymentStatus: (map[FactureFields.paymentStatus] ?? FactureFields.statusPending).toString().toLowerCase().trim(),
      urlPreuve: map[FactureFields.urlPreuve],
      methodePaiement: map[FactureFields.methodePaiement],
      motifRejet: map[FactureFields.motifRejet],
      dateCreation: _convertToDateTime(map[FactureFields.dateCreation]),
    );
  }
}