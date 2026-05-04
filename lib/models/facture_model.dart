// lib/models/facture_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';

class FactureModel {
  final String? id;
  final String propertyId;
  final String? bailleurId; 
  final String clientId;
  final String? agentId; 
  final String? assignedAdminId; // 👈 1. AJOUT DU CHAMP
  final String nomClient;
  final String telClient;
  
  final String? nomBailleur;
  final String? telBailleur;
  final String refMaison;
  
  final double loyer;
  final int nbMoisGarantie;
  
  final String nomOffre;
  final double comLocatairePercent;
  final double comBailleurPercent;
  final double tauxApplique;

  final double montantWallet; 
  final double montantExterne; 
  final double montantCashback; 

  final double commissionSgaLocataire;
  final double commissionSgaBailleur;

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
  final String? adminValidator;
  final DateTime? dateActionAdmin;
  final String? statutCadeau;

  FactureModel({
    this.id,
    this.bailleurId,
    this.assignedAdminId, // 👈 2. AJOUT AU CONSTRUCTEUR
    required this.propertyId,
    required this.clientId,
    this.agentId,
    required this.nomClient,
    required this.telClient,
    this.nomBailleur,
    this.telBailleur,
    required this.refMaison,
    
    this.loyer = 0.0,
    this.nbMoisGarantie = 0,
    
    required this.nomOffre,
    required double comLocatairePercent,
    required double comBailleurPercent,
    this.tauxApplique = 2500.0,
    this.montantWallet = 0.0,
    this.montantExterne = 0.0,
    this.montantCashback = 0.0,

    this.commissionSgaLocataire = 0.0,
    this.commissionSgaBailleur = 0.0,

    this.cadeauId,
    this.cadeauTaille,
    this.cadeauStyle,
    this.province,
    this.ville,
    this.commune,
    this.villeSpecifique,   
    this.communeSpecifique, 
    this.paymentStatus = FactureFields.statusPending,
    this.etapeDossier = 'nouveau',
    this.dateCreation,
    this.dateExpiration,
    this.urlPreuve,
    this.methodePaiement,
    this.motifRejet,
    this.adminValidator,
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
    String? agentId,
    String? assignedAdminId, // 👈 AJOUT DANS COPYWITH
    String? paymentStatus,
    String? etapeDossier,
    String? urlPreuve,
    String? methodePaiement,
    String? motifRejet,
    String? adminValidator,
    DateTime? dateActionAdmin,
    DateTime? dateExpiration,
    String? statutCadeau,
    String? telBailleur,
    String? nomBailleur,
    double? montantWallet,
    double? montantExterne,
    double? montantCashback,
    double? loyer,
    int? nbMoisGarantie,
    String? ville,              
    String? commune,          
    String? villeSpecifique,   
    String? communeSpecifique, 
    double? commissionSgaLocataire,
    double? commissionSgaBailleur, 
  }) {
    return FactureModel(
      id: id ?? this.id,
      bailleurId: bailleurId ?? this.bailleurId,
      agentId: agentId ?? this.agentId,
      assignedAdminId: assignedAdminId ?? this.assignedAdminId, // 👈 LOGIQUE COPYWITH
      propertyId: this.propertyId,
      clientId: this.clientId,
      nomClient: this.nomClient,
      telClient: this.telClient,
      nomBailleur: nomBailleur ?? this.nomBailleur,
      telBailleur: telBailleur ?? this.telBailleur,
      refMaison: this.refMaison,
      loyer: loyer ?? this.loyer,
      nbMoisGarantie: nbMoisGarantie ?? this.nbMoisGarantie,
      nomOffre: this.nomOffre,
      comLocatairePercent: this.comLocatairePercent,
      comBailleurPercent: this.comBailleurPercent,
      tauxApplique: this.tauxApplique,
      montantWallet: montantWallet ?? this.montantWallet,
      montantExterne: montantExterne ?? this.montantExterne,
      montantCashback: montantCashback ?? this.montantCashback,
      commissionSgaLocataire: commissionSgaLocataire ?? this.commissionSgaLocataire,
      commissionSgaBailleur: commissionSgaBailleur ?? this.commissionSgaBailleur,
      cadeauId: this.cadeauId,
      cadeauTaille: this.cadeauTaille,
      cadeauStyle: this.cadeauStyle,
      province: this.province,
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
      adminValidator: adminValidator ?? this.adminValidator,
      dateActionAdmin: dateActionAdmin ?? this.dateActionAdmin,
      statutCadeau: statutCadeau ?? this.statutCadeau,
    );
  }

  // ... (Getters inchangés) ...

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
      'id': id,
      'propertyId': propertyId,
      'bailleurId': bailleurId,
      'clientId': clientId,
      'agentId': agentId,
      'assignedAdminId': assignedAdminId, // 👈 3. AJOUT À LA SÉRIALISATION
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
      'tauxApplique': tauxApplique,
      'montantWallet': montantWallet,
      'montantExterne': montantExterne,
      'montantCashback': montantCashback, 
      'commissionSgaLocataire': commissionSgaLocataire,
      'commissionSgaBailleur': commissionSgaBailleur,
      'cadeauId': cadeauId,
      'cadeauTaille': cadeauTaille,
      'cadeauStyle': cadeauStyle,
      FactureFields.province: province,
      FactureFields.ville: ville?.toLowerCase().trim(),
      FactureFields.commune: commune,
      'villeSpecifique': villeSpecifique,      
      'communeSpecifique': communeSpecifique,  
      FactureFields.totalUSD: totalUSD,
      'totalCDF': totalCDF,
      FactureFields.paymentStatus: paymentStatus.toLowerCase(),
      FactureFields.etapeDossier: etapeDossier.toLowerCase(),
      FactureFields.urlPreuve: urlPreuve,
      FactureFields.methodePaiement: methodePaiement?.toLowerCase(),
      FactureFields.motifRejet: motifRejet,
      FactureFields.adminValidator: adminValidator,
      FactureFields.dateCreation: dateCreation != null 
          ? Timestamp.fromDate(dateCreation!) 
          : FieldValue.serverTimestamp(),
      'dateExpiration': dateExpiration != null ? Timestamp.fromDate(dateExpiration!) : null,
      'dateActionAdmin': dateActionAdmin != null ? Timestamp.fromDate(dateActionAdmin!) : null,
      'statutCadeau': statutCadeau ?? 
          (cadeauId == 'Aucun' || cadeauId == null ? 'termine' : 'nouveau'),
    };
  }

  factory FactureModel.fromMap(Map<String, dynamic> map, String docId) {
    return FactureModel(
      id: docId,
      propertyId: map['propertyId'] ?? '',
      bailleurId: map['bailleurId'],
      clientId: map['clientId'] ?? '',
      agentId: map['agentId'],
      assignedAdminId: map['assignedAdminId'], // 👈 4. AJOUT AU DESERIALISATION
      nomClient: map[FactureFields.nomClient] ?? '',
      telClient: map[FactureFields.telClient] ?? '',
      nomBailleur: map['nomBailleur'],
      telBailleur: map['telBailleur'],
      refMaison: map[FactureFields.refMaison] ?? '',
      loyer: (map['loyer'] ?? 0.0).toDouble(),
      nbMoisGarantie: map['nbMoisGarantie'] ?? 0,
      nomOffre: map['nomOffre'] ?? '',
      comLocatairePercent: _ensurePercentage(map['comLocatairePercent']),
      comBailleurPercent: _ensurePercentage(map['comBailleurPercent']),
      tauxApplique: (map['tauxApplique'] ?? 2500.0).toDouble(),
      montantWallet: (map['montantWallet'] ?? 0.0).toDouble(),
      montantExterne: (map['montantExterne'] ?? 0.0).toDouble(),
      montantCashback: (map['montantCashback'] ?? 0.0).toDouble(), 
      commissionSgaLocataire: (map['commissionSgaLocataire'] ?? 0.0).toDouble(),
      commissionSgaBailleur: (map['commissionSgaBailleur'] ?? 0.0).toDouble(),
      cadeauId: map['cadeauId'],
      cadeauTaille: map['cadeauTaille'],
      cadeauStyle: map['cadeauStyle'],
      province: map[FactureFields.province],
      ville: map[FactureFields.ville],
      commune: map[FactureFields.commune],
      villeSpecifique: map['villeSpecifique'],      
      communeSpecifique: map['communeSpecifique'],  
      paymentStatus: (map[FactureFields.paymentStatus] ?? map[FactureFields.statut] ?? 'pending')
          .toString()
          .toLowerCase(),
      etapeDossier: (map[FactureFields.etapeDossier] ?? map[FactureFields.statut] ?? 'nouveau')
          .toString()
          .toLowerCase(),
      urlPreuve: map[FactureFields.urlPreuve],
      methodePaiement: map[FactureFields.methodePaiement]?.toString().toLowerCase(),
      motifRejet: map[FactureFields.motifRejet],
      adminValidator: map[FactureFields.adminValidator],
      dateCreation: _convertToDateTime(map[FactureFields.dateCreation]),
      dateExpiration: _convertToDateTime(map['dateExpiration']),
      dateActionAdmin: _convertToDateTime(map['dateActionAdmin']),
      statutCadeau: map['statutCadeau'],
    );
  }

  factory FactureModel.fromServiceMap(Map<String, dynamic> map, String docId) {
    return FactureModel(
      id: docId,
      propertyId: 'SERVICE', 
      clientId: map['locataireId'] ?? '',
      nomClient: map['nomClient'] ?? 'Client',
      telClient: map['locataireTel'] ?? '',
      nomBailleur: "EasyLocation Service",
      telBailleur: "Administration",
      refMaison: map['typeService'] ?? 'REF-SERV', 
      loyer: (map['prix'] ?? 0.0).toDouble(),
      nbMoisGarantie: 0,
      nomOffre: map['nomAffichage'] ?? 'Prestation de service',
      comLocatairePercent: 0, 
      comBailleurPercent: 0,
      commissionSgaLocataire: 0,
      commissionSgaBailleur: 0,
      montantWallet: (map['montantWallet'] ?? 0.0).toDouble(),
      montantExterne: (map['montantExterne'] ?? 0.0).toDouble(),
      montantCashback: (map['montantCashback'] ?? 0.0).toDouble(),
      paymentStatus: (map['paymentStatus'] ?? (map['statut'] ?? 'pending')).toString().toLowerCase(),
      urlPreuve: map['urlPreuve'] ?? map['urlPreuvePaiement'],
      methodePaiement: map['methodePaiement'],
      motifRejet: map['motifRejet'],
      dateCreation: _convertToDateTime(map['timestamp']),
    );
  }
}