// lib/models/property_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
// ✅ IMPORTATION DES CONSTANTES CENTRALISÉES
import 'package:easylocation_mvp/constants/constants.dart'; 

/// Classe utilitaire pour passer les données nécessaires à la fonction compute
class _PropertyParsingData {
  final Map<String, dynamic> data;
  final String id;
  _PropertyParsingData(this.data, this.id);
}

// ====================================================================
// Fonction de niveau supérieur pour le parsing hors du thread principal.
// ====================================================================
Future<Property> _parsePropertyData(_PropertyParsingData input) async {
  return Property.fromMap(input.data, input.id);
}
// ====================================================================

class Property {
  final String id;
  final String bailleurId;

  // 1. Informations Générales & Adresse
  final String? typeBien;
  final String province; 
  final String ville;     
  final String? villeSpecifique; 
  final String commune;
  final String? communeSpecifique; 
  final String quartier;
  final String? quartierSpecifique; 
  final String avenue;
  final String? avenueSpecifique; 
  final String numeroMaison;
  final double price;
  final int nombreChambres;
  final int garantieIdeale;
  final int garantieMinimale;
  final bool disponibiliteImmediate;
  final DateTime? dateDisponibilite;
  final bool maisonEnEtage;
  final int? niveauEtage;
  final String description;

  // 2. Description Physique
  final bool hasSalon; 
  final bool hasCuisine;
  final bool hasToiletteParentale;
  final String? selectedTypeSol;
  final bool hasGarage;
  final bool hasCourRecreation;
  final bool hasDepot;
  final bool maisonEnclos;
  final bool possibiliteAnimaux;
  final String? typeMaison;

  // 3. Services et Infrastructures
  final bool hasEau;
  final bool compteurEau;
  final String electricite;
  final bool accessibiliteVoiture;
  final bool bailleurHabiteAvec;
  final int? nombreMenages;

  // 4. Informations Propriétaire
  final String nomProprietaire;
  final String postnomProprietaire;
  final String prenomProprietaire;
  final String telephoneProprietaire;
  final String emailProprietaire;
  final String? statutLegal;
  final String? statutLegalAutre; 
  final String? statutProfessionnel;
  final String? statutProAutre; 
  final bool estReactif;

  // 5. Métadonnées, Boost & Compteurs
  final DateTime? publicationDate;
  final DateTime createdAt;       
  final DateTime? lastBoost;      
  final int sortIndex;            
  
  int views;          
  int shares;          
  int favoriteCount; 
  int ratingCount;   
  double totalRating; 
  
  final String status;
  final bool isHiddenFromBailleur;
  final bool isVerified; 
  final bool estLouee; // ✅ Cohérence avec les filtres Firestore
  
  final int? lockTimestamp;

  // Champs d'URLs
  final Map<String, String> specificImageUrls;
  final List<String> chambresImageUrls;
  final String? mainImageUrl; 
  final List<String> firestoreImageUrls; 

  Property({
    required this.id,
    required this.bailleurId,
    this.typeBien,
    this.province = '', 
    this.ville = '',      
    this.villeSpecifique, 
    required this.commune,
    this.communeSpecifique, 
    required this.quartier,
    this.quartierSpecifique, 
    required this.avenue,
    this.avenueSpecifique, 
    required this.numeroMaison,
    required this.price,
    required this.nombreChambres,
    required this.garantieIdeale,
    required this.garantieMinimale,
    required this.disponibiliteImmediate,
    this.dateDisponibilite,
    required this.maisonEnEtage,
    this.niveauEtage,
    required this.description,
    required this.hasSalon,
    required this.hasCuisine,
    required this.hasToiletteParentale,
    this.selectedTypeSol,
    required this.hasGarage,
    required this.hasCourRecreation,
    required this.hasDepot,
    required this.maisonEnclos,
    required this.possibiliteAnimaux,
    this.typeMaison,
    required this.hasEau,
    required this.compteurEau,
    required this.electricite,
    required this.accessibiliteVoiture,
    required this.bailleurHabiteAvec,
    this.nombreMenages,
    required this.nomProprietaire,
    required this.postnomProprietaire,
    required this.prenomProprietaire,
    required this.telephoneProprietaire,
    required this.emailProprietaire,
    this.statutLegal,
    this.statutLegalAutre, 
    this.statutProfessionnel,
    this.statutProAutre, 
    required this.estReactif,
    this.publicationDate,
    required this.createdAt,   
    this.lastBoost,            
    this.sortIndex = 0,        
    this.views = 0,
    this.shares = 0,
    this.favoriteCount = 0,
    this.ratingCount = 0,
    this.totalRating = 0.0,
    this.status = PropertyStatus.disponible,
    this.isHiddenFromBailleur = false,
    this.isVerified = false, 
    this.estLouee = false, 
    this.lockTimestamp,
    this.specificImageUrls = const {},
    this.chambresImageUrls = const [],
    this.firestoreImageUrls = const [],
    this.mainImageUrl, 
  });

  // -----------------------------------------------------------------
  // Logique de normalisation améliorée
  // -----------------------------------------------------------------
  static String _normalizeStatus(String? rawStatus) {
    if (rawStatus == null || rawStatus.isEmpty) return PropertyStatus.disponible;
    final String s = rawStatus.toLowerCase().trim();
    if (s == 'archive' || s == 'archivé') return 'archive'; 
    if (['publiée', 'active', 'published', 'disponible'].contains(s)) return PropertyStatus.disponible;
    if (['en_cours_de_reservation', 'in_progress', 'booking', 'en cours'].contains(s)) return PropertyStatus.booking;
    if (['reserve_paye', 'reserved', 'réservée', 'réservé'].contains(s)) return PropertyStatus.reserved;
    if (['rented', 'louée', 'loué', 'occupée', 'occupé'].contains(s)) return PropertyStatus.rented;
    return PropertyStatus.disponible;
  }

  // -----------------------------------------------------------------
  // Getters (Logique Métier Corrigée)
  // -----------------------------------------------------------------
  bool get isEnclos => maisonEnclos;
  bool get hasElectricity => electricite.toLowerCase() != 'non spécifié' && electricite.toLowerCase() != 'aucune' && electricite.toLowerCase() != 'pas d’électricité';
  String get referenceCourte => id.length >= 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase();
  double get averageRating => ratingCount <= 0 ? 0.0 : totalRating / ratingCount;
  String get title => id.isNotEmpty ? 'Référence $referenceCourte' : 'Propriété';
  
  String get location {
    String v = (ville == "Autre" && villeSpecifique != null) ? villeSpecifique! : ville;
    String c = (commune == "Autre" && communeSpecifique != null) ? communeSpecifique! : commune;
    String q = (quartier == "Autre" && quartierSpecifique != null) ? quartierSpecifique! : quartier;
    return '$province, $v, $c, $q';
  }

  String? get salonImageUrl => specificImageUrls['salonImage'];

  /// ✅ AFFICHAGE TEXTUEL DE LA DISPONIBILITÉ
  String get disponibiliteText {
    if (disponibiliteImmediate) return "Disponible immédiatement";
    if (dateDisponibilite != null) {
      return "Disponible le ${dateDisponibilite!.day.toString().padLeft(2, '0')}/${dateDisponibilite!.month.toString().padLeft(2, '0')}/${dateDisponibilite!.year}";
    }
    return "Disponibilité non spécifiée";
  }

  /// ✅ LOGIQUE CORRIGÉE : GESTION GRENIER (99) ET REZ-DE-CHAUSSÉE (0)
  String get niveauText {
    if (!maisonEnEtage) return "Maison de plain-pied (Rez-de-chaussée)";
    if (niveauEtage == 99) return "Grenier aménagé";
    if (niveauEtage == 0 || niveauEtage == null) return "Rez-de-chaussée";
    if (niveauEtage == 1) return "1er étage";
    return "$niveauEtageème étage";
  }

  List<String> get imageUrls {
    if (firestoreImageUrls.isNotEmpty) return firestoreImageUrls;
    final List<String> all = [];
    if (mainImageUrl != null && mainImageUrl!.isNotEmpty) all.add(mainImageUrl!);
    all.addAll(chambresImageUrls);
    all.addAll(specificImageUrls.values);
    return all.toSet().toList();
  }

  // -----------------------------------------------------------------
  // Factories
  // -----------------------------------------------------------------
  factory Property.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) throw StateError("Document nul pour l'ID: ${doc.id}");
    return Property.fromMap(data, doc.id);
  }
  
  factory Property.fromMap(Map<String, dynamic> data, String id) {
    bool _readBool(String key) {
      var val = data[key];
      if (val == null) return false;
      if (val is bool) return val;
      if (val is num) return val == 1;
      if (val is String) return val.toLowerCase() == 'true';
      return false;
    }

    Map<String, String> _readStringMap(String key) {
      final map = data[key];
      if (map is! Map) return {};
      return map.map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    List<String> _readStringList(String key) {
      final list = data[key];
      if (list is! List) return [];
      return list.map((e) => e.toString()).toList();
    }

    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    // ✅ CORRECTION CRITIQUE : Récupération de la map des images pour la logique "Image = Option"
    final Map<String, dynamic> specificImages = data['specificImageUrls'] != null 
        ? Map<String, dynamic>.from(data['specificImageUrls'])
        : {};

    return Property(
      id: id,
      bailleurId: data['bailleurId']?.toString() ?? '',
      typeBien: data['typeBien']?.toString(),
      province: data['province']?.toString() ?? '', 
      ville: data['ville']?.toString() ?? '',           
      villeSpecifique: data['villeSpecifique']?.toString(), 
      commune: data['commune']?.toString() ?? '',
      communeSpecifique: data['communeSpecifique']?.toString(), 
      quartier: data['quartier']?.toString() ?? '',
      quartierSpecifique: data['quartierSpecifique']?.toString(), 
      avenue: data['avenue']?.toString() ?? '',
      avenueSpecifique: data['avenueSpecifique']?.toString(), 
      numeroMaison: data['numeroMaison']?.toString() ?? '',
      price: (data[FirestoreFields.price] as num?)?.toDouble() ?? 0.0,
      nombreChambres: (data['nombreChambres'] as num?)?.toInt() ?? 0,
      garantieIdeale: (data['garantieIdeale'] as num?)?.toInt() ?? 0,
      garantieMinimale: (data['garantieMinimale'] as num?)?.toInt() ?? 0,
      disponibiliteImmediate: _readBool('disponibiliteImmediate'),
      dateDisponibilite: _parseDate(data['dateDisponibilite']),
      maisonEnEtage: _readBool('maisonEnEtage'),
      niveauEtage: (data['niveauEtage'] as num?)?.toInt(),
      description: data['description']?.toString() ?? '',
      
      // ✅ CORRECTION MAJEURE : On vérifie le booléen OU la présence de l'image
      hasSalon: _readBool('hasSalon') || (specificImages['salonImage'] != null),
      hasCuisine: _readBool('hasCuisine') || (specificImages['cuisineImage'] != null),
      hasToiletteParentale: _readBool('hasToiletteParentale') || (specificImages['toiletteParentaleImage'] != null),
      hasGarage: _readBool('hasGarage') || (specificImages['garageImage'] != null),
      hasCourRecreation: _readBool('hasCourRecreation') || (specificImages['courRecreationImage'] != null),
      hasDepot: _readBool('hasDepot') || (specificImages['depotImage'] != null),
      
      selectedTypeSol: data['selectedTypeSol']?.toString(),
      maisonEnclos: _readBool('maisonEnclos'),
      possibiliteAnimaux: _readBool('possibiliteAnimaux'),
      typeMaison: data['typeMaison']?.toString(),
      hasEau: _readBool('hasEau'),
      compteurEau: _readBool('compteurEau'),
      electricite: data['electricite']?.toString() ?? 'Non spécifié',
      accessibiliteVoiture: _readBool('accessibiliteVoiture'),
      bailleurHabiteAvec: _readBool('bailleurHabiteAvec'),
      nombreMenages: (data['nombreMenages'] as num?)?.toInt(),
      nomProprietaire: data['nomProprietaire']?.toString() ?? 'Inconnu',
      postnomProprietaire: data['postnomProprietaire']?.toString() ?? '',
      prenomProprietaire: data['prenomProprietaire']?.toString() ?? '',
      telephoneProprietaire: data['telephoneProprietaire']?.toString() ?? '',
      emailProprietaire: data['emailProprietaire']?.toString() ?? '',
      statutLegal: data['statutLegal']?.toString(),
      statutLegalAutre: data['statutLegalAutre']?.toString(),
      statutProfessionnel: data['statutProfessionnel']?.toString(),
      statutProAutre: data['statutProAutre']?.toString(), 
      estReactif: _readBool('estReactif'),
      publicationDate: _parseDate(data['publicationDate']),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      lastBoost: _parseDate(data['lastBoost']),
      sortIndex: (data['sortIndex'] as num?)?.toInt() ?? 0,
      views: (data['views'] as num?)?.toInt() ?? 0,
      shares: (data['shares'] as num?)?.toInt() ?? 0,
      favoriteCount: (data['favoriteCount'] as num?)?.toInt() ?? 0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      totalRating: (data['totalRating'] as num?)?.toDouble() ?? 0.0,
      status: _normalizeStatus(data[FirestoreFields.status]?.toString()), 
      isHiddenFromBailleur: _readBool('isHiddenFromBailleur'),
      isVerified: _readBool(FirestoreFields.isVerified), 
      estLouee: _readBool('estLouee'),
      lockTimestamp: (data['lockTimestamp'] as num?)?.toInt(), 
      specificImageUrls: _readStringMap('specificImageUrls'), 
      chambresImageUrls: _readStringList('chambresImageUrls'),
      firestoreImageUrls: _readStringList(FirestoreFields.imageUrls),
      mainImageUrl: data['mainImageUrl']?.toString() ?? 
                    (data[FirestoreFields.imageUrls] is List && (data[FirestoreFields.imageUrls] as List).isNotEmpty 
                    ? data[FirestoreFields.imageUrls][0].toString() 
                    : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bailleurId': bailleurId,
      'typeBien': typeBien, 
      'province': province, 
      'ville': ville,           
      'villeSpecifique': villeSpecifique, 
      'commune': commune,
      'communeSpecifique': communeSpecifique, 
      'quartier': quartier,
      'quartierSpecifique': quartierSpecifique, 
      'avenue': avenue,
      'avenueSpecifique': avenueSpecifique, 
      'numeroMaison': numeroMaison,
      FirestoreFields.price: price,
      'nombreChambres': nombreChambres,
      'garantieIdeale': garantieIdeale,
      'garantieMinimale': garantieMinimale,
      'disponibiliteImmediate': disponibiliteImmediate,
      'dateDisponibilite': dateDisponibilite != null ? Timestamp.fromDate(dateDisponibilite!) : null,
      'maisonEnEtage': maisonEnEtage,
      'niveauEtage': niveauEtage,
      'description': description,
      'hasSalon': hasSalon, 
      'hasCuisine': hasCuisine,
      'hasToiletteParentale': hasToiletteParentale,
      'selectedTypeSol': selectedTypeSol, 
      'hasGarage': hasGarage,
      'hasCourRecreation': hasCourRecreation,
      'hasDepot': hasDepot,
      'maisonEnclos': maisonEnclos,
      'possibiliteAnimaux': possibiliteAnimaux,
      'typeMaison': typeMaison, 
      'hasEau': hasEau,
      'compteurEau': compteurEau,
      'electricite': electricite,
      'accessibiliteVoiture': accessibiliteVoiture,
      'bailleurHabiteAvec': bailleurHabiteAvec,
      'nombreMenages': nombreMenages,
      'nomProprietaire': nomProprietaire,
      'postnomProprietaire': postnomProprietaire,
      'prenomProprietaire': prenomProprietaire,
      'telephoneProprietaire': telephoneProprietaire,
      'emailProprietaire': emailProprietaire,
      'statutLegal': statutLegal, 
      'statutLegalAutre': statutLegalAutre, 
      'statutProfessionnel': statutProfessionnel, 
      'statutProAutre': statutProAutre, 
      'estReactif': estReactif,
      'publicationDate': publicationDate != null ? Timestamp.fromDate(publicationDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastBoost': lastBoost != null ? Timestamp.fromDate(lastBoost!) : null,
      'sortIndex': sortIndex,
      'views': views,
      'shares': shares,
      'favoriteCount': favoriteCount,
      'ratingCount': ratingCount,
      'totalRating': totalRating,
      FirestoreFields.status: status,
      'isHiddenFromBailleur': isHiddenFromBailleur,
      FirestoreFields.isVerified: isVerified,
      'estLouee': estLouee,
      'lockTimestamp': lockTimestamp, 
      'specificImageUrls': specificImageUrls,
      'chambresImageUrls': chambresImageUrls,
      FirestoreFields.imageUrls: firestoreImageUrls,
      'mainImageUrl': mainImageUrl, 
    };
  }

  Property copyWith({
    String? id,
    String? bailleurId,
    String? typeBien,
    String? province, 
    String? ville,    
    String? villeSpecifique, 
    String? commune,
    String? communeSpecifique, 
    String? quartier,
    String? quartierSpecifique, 
    String? avenue,
    String? avenueSpecifique, 
    String? numeroMaison,
    double? price,
    int? nombreChambres,
    int? garantieIdeale,
    int? garantieMinimale,
    bool? disponibiliteImmediate,
    DateTime? dateDisponibilite,
    bool? maisonEnEtage,
    int? niveauEtage,
    String? description,
    bool? hasSalon,
    bool? hasCuisine,
    bool? hasToiletteParentale,
    String? selectedTypeSol,
    bool? hasGarage,
    bool? hasCourRecreation,
    bool? hasDepot,
    bool? maisonEnclos,
    bool? possibiliteAnimaux,
    String? typeMaison,
    bool? hasEau,
    bool? compteurEau,
    String? electricite,
    bool? accessibiliteVoiture,
    bool? bailleurHabiteAvec,
    int? nombreMenages,
    String? nomProprietaire,
    String? postnomProprietaire,
    String? prenomProprietaire,
    String? telephoneProprietaire,
    String? emailProprietaire,
    String? statutLegal,
    String? statutLegalAutre,
    String? statutProfessionnel,
    String? statutProAutre,
    bool? estReactif,
    DateTime? publicationDate,
    DateTime? createdAt,
    DateTime? lastBoost,
    int? sortIndex,
    int? views,
    int? shares,
    int? favoriteCount,
    int? ratingCount,
    double? totalRating,
    String? status,
    bool? isHiddenFromBailleur,
    bool? isVerified,
    bool? estLouee,
    int? lockTimestamp, 
    Map<String, String>? specificImageUrls,
    List<String>? chambresImageUrls,
    List<String>? firestoreImageUrls,
    String? mainImageUrl,
  }) {
    return Property(
      id: id ?? this.id,
      bailleurId: bailleurId ?? this.bailleurId,
      typeBien: typeBien ?? this.typeBien,
      province: province ?? this.province, 
      ville: ville ?? this.ville,           
      villeSpecifique: villeSpecifique ?? this.villeSpecifique, 
      commune: commune ?? this.commune,
      communeSpecifique: communeSpecifique ?? this.communeSpecifique, 
      quartier: quartier ?? this.quartier,
      quartierSpecifique: quartierSpecifique ?? this.quartierSpecifique, 
      avenue: avenue ?? this.avenue,
      avenueSpecifique: avenueSpecifique ?? this.avenueSpecifique, 
      numeroMaison: numeroMaison ?? this.numeroMaison,
      price: price ?? this.price,
      nombreChambres: nombreChambres ?? this.nombreChambres,
      garantieIdeale: garantieIdeale ?? this.garantieIdeale,
      garantieMinimale: garantieMinimale ?? this.garantieMinimale,
      disponibiliteImmediate: disponibiliteImmediate ?? this.disponibiliteImmediate,
      dateDisponibilite: dateDisponibilite ?? this.dateDisponibilite,
      maisonEnEtage: maisonEnEtage ?? this.maisonEnEtage,
      niveauEtage: niveauEtage ?? this.niveauEtage,
      description: description ?? this.description,
      hasSalon: hasSalon ?? this.hasSalon,
      hasCuisine: hasCuisine ?? this.hasCuisine,
      hasToiletteParentale: hasToiletteParentale ?? this.hasToiletteParentale,
      selectedTypeSol: selectedTypeSol ?? this.selectedTypeSol,
      hasGarage: hasGarage ?? this.hasGarage,
      hasCourRecreation: hasCourRecreation ?? this.hasCourRecreation,
      hasDepot: hasDepot ?? this.hasDepot,
      maisonEnclos: maisonEnclos ?? this.maisonEnclos,
      possibiliteAnimaux: possibiliteAnimaux ?? this.possibiliteAnimaux,
      typeMaison: typeMaison ?? this.typeMaison,
      hasEau: hasEau ?? this.hasEau,
      compteurEau: compteurEau ?? this.compteurEau,
      electricite: electricite ?? this.electricite,
      accessibiliteVoiture: accessibiliteVoiture ?? this.accessibiliteVoiture,
      bailleurHabiteAvec: bailleurHabiteAvec ?? this.bailleurHabiteAvec,
      nombreMenages: nombreMenages ?? this.nombreMenages,
      nomProprietaire: nomProprietaire ?? this.nomProprietaire,
      postnomProprietaire: postnomProprietaire ?? this.postnomProprietaire,
      prenomProprietaire: prenomProprietaire ?? this.prenomProprietaire,
      telephoneProprietaire: telephoneProprietaire ?? this.telephoneProprietaire,
      emailProprietaire: emailProprietaire ?? this.emailProprietaire,
      statutLegal: statutLegal ?? this.statutLegal,
      statutLegalAutre: statutLegalAutre ?? this.statutLegalAutre,
      statutProfessionnel: statutProfessionnel ?? this.statutProfessionnel,
      statutProAutre: statutProAutre ?? this.statutProAutre,
      estReactif: estReactif ?? this.estReactif,
      publicationDate: publicationDate ?? this.publicationDate,
      createdAt: createdAt ?? this.createdAt,
      lastBoost: lastBoost ?? this.lastBoost,
      sortIndex: sortIndex ?? this.sortIndex,
      views: views ?? this.views,
      shares: shares ?? this.shares,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      ratingCount: ratingCount ?? this.ratingCount,
      totalRating: totalRating ?? this.totalRating,
      status: status ?? this.status,
      isHiddenFromBailleur: isHiddenFromBailleur ?? this.isHiddenFromBailleur,
      isVerified: isVerified ?? this.isVerified,
      estLouee: estLouee ?? this.estLouee,
      lockTimestamp: lockTimestamp ?? this.lockTimestamp, 
      specificImageUrls: specificImageUrls ?? this.specificImageUrls,
      chambresImageUrls: chambresImageUrls ?? this.chambresImageUrls,
      firestoreImageUrls: firestoreImageUrls ?? this.firestoreImageUrls,
      mainImageUrl: mainImageUrl ?? this.mainImageUrl,
    );
  }
}