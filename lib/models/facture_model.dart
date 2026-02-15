// lib/models/facture_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class FactureModel {
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
  final bool transportChoisi;
  final double tauxApplique; 

  final String? cadeauId;
  final String? cadeauTaille;
  final String? cadeauStyle;

  final String? province;
  final String? ville;
  final String? commune;

  // --- CHAMPS DE PAIEMENT & ADMIN ---
  final String statut; // 'pending', 'completed', 'rejected'
  final dynamic dateCreation; 
  final String? urlPreuve; 
  final String? methodePaiement;
  final String? motifRejet;
  final String? adminValidator; 
  final dynamic dateActionAdmin; 

  // --- NOUVEAUX CHAMPS LOGISTIQUE ---
  final String? statutCadeau;    // 'nouveau', 'en_cours', 'termine'
  final String? statutTransport; // 'nouveau', 'en_cours', 'termine'

  FactureModel({
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
    required this.comLocatairePercent,
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
  });

  // ==========================================================
  // LOGIQUE DE CALCUL (Automatisée)
  // ==========================================================
  
  double get commissionUSD => loyer * comLocatairePercent;
  
  double get fraisTransportUSD => transportChoisi ? 10.0 : 0.0;
  
  double get totalUSD => double.parse(((loyer * 1) + commissionUSD + fraisTransportUSD).toStringAsFixed(2)); 
  
  double get totalCDF => totalUSD * tauxApplique;

  // ==========================================================
  // MÉTHODES FIRESTORE
  // ==========================================================

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'clientId': clientId,
      'nomClient': nomClient,
      'telClient': telClient,
      'nomBailleur': nomBailleur,
      'telBailleur': telBailleur,
      'refMaison': refMaison,
      'loyer': loyer,
      'nbMoisGarantie': nbMoisGarantie,
      'nomOffre': nomOffre,
      'comLocatairePercent': comLocatairePercent,
      'transportChoisi': transportChoisi,
      'tauxApplique': tauxApplique, 
      'cadeauId': cadeauId,
      'cadeauTaille': cadeauTaille,
      'cadeauStyle': cadeauStyle,
      'province': province, // DYNAMIQUE : Reçoit la valeur de la maison sélectionnée
      'ville': ville,
      'commune': commune,
      'totalUSD': totalUSD,
      'statut': statut, 
      'paymentStatus': statut,
      'urlPreuve': urlPreuve,
      'methodePaiement': methodePaiement,
      'motifRejet': motifRejet,
      'adminValidator': adminValidator,
      'dateCreation': dateCreation ?? FieldValue.serverTimestamp(),
      'dateActionAdmin': dateActionAdmin,
      'statutCadeau': statutCadeau ?? (cadeauId == 'Aucun' || cadeauId == null ? 'termine' : 'nouveau'),
      'statutTransport': statutTransport ?? (transportChoisi ? 'nouveau' : 'termine'),
    };
  }

  factory FactureModel.fromMap(Map<String, dynamic> map) {
    return FactureModel(
      propertyId: map['propertyId'] ?? '',
      clientId: map['clientId'] ?? '',
      nomClient: map['nomClient'] ?? '',
      telClient: map['telClient'] ?? '',
      nomBailleur: map['nomBailleur'] ?? '',
      telBailleur: map['telBailleur'] ?? '',
      refMaison: map['refMaison'] ?? '',
      loyer: (map['loyer'] ?? 0).toDouble(),
      nbMoisGarantie: map['nbMoisGarantie'] ?? 3,
      nomOffre: map['nomOffre'] ?? '',
      comLocatairePercent: (map['comLocatairePercent'] ?? 0.0).toDouble(),
      transportChoisi: map['transportChoisi'] ?? false,
      tauxApplique: (map['tauxApplique'] ?? 2500.0).toDouble(),
      cadeauId: map['cadeauId'],
      cadeauTaille: map['cadeauTaille'],
      cadeauStyle: map['cadeauStyle'],
      province: map['province'],
      ville: map['ville'],
      commune: map['commune'],
      statut: map['paymentStatus'] ?? map['statut'] ?? 'pending', 
      urlPreuve: map['urlPreuve'],
      methodePaiement: map['methodePaiement'],
      motifRejet: map['motifRejet'],
      adminValidator: map['adminValidator'],
      dateCreation: map['dateCreation'],
      dateActionAdmin: map['dateActionAdmin'],
      statutCadeau: map['statutCadeau'],
      statutTransport: map['statutTransport'],
    );
  }

  FactureModel copyWith({
    String? statut,
    String? urlPreuve,
    String? methodePaiement,
    String? motifRejet,
    String? province,
    String? statutCadeau,
    String? statutTransport,
  }) {
    return FactureModel(
      propertyId: propertyId,
      clientId: clientId,
      nomClient: nomClient,
      telClient: telClient,
      nomBailleur: nomBailleur,
      telBailleur: telBailleur,
      refMaison: refMaison,
      loyer: loyer,
      nbMoisGarantie: nbMoisGarantie,
      nomOffre: nomOffre,
      comLocatairePercent: comLocatairePercent,
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
      dateCreation: dateCreation,
      dateActionAdmin: dateActionAdmin,
      statutCadeau: statutCadeau ?? this.statutCadeau,
      statutTransport: statutTransport ?? this.statutTransport,
    );
  }
}
