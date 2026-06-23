// lib/models/formulaire_publication_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

// ✅ Import des constantes pour la source de vérité des statuts
import 'package:easylocation_mvp/constants/all_constants.dart';

// ✅ On cache PropertyStatus du modèle s'il y est défini pour éviter le conflit
import 'property_model.dart' hide PropertyStatus; 

// ***************************************************************
// TYPE DÉDIÉ POUR LES IMAGES
// ***************************************************************
@immutable
class ImageSource {
  final XFile? file;
  final String? url;

  const ImageSource({this.file, this.url});

  bool get isEmpty => file == null && url == null;
  bool get isFile => file != null;
  bool get isUrl => url != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageSource && other.file?.path == file?.path && other.url == url;

  @override
  int get hashCode => file.hashCode ^ url.hashCode;
}

// ***************************************************************
// OBJET SENTINELLE POUR LE COPYWITH
// ***************************************************************
const FormulairePublicationModelSentinel = Object(); 

class FormulairePublicationModel {
  String? id; 

  // Informations Générales
  final ImageSource? mainImage; 
  final String? typeBien; 
  final String? province;
  final String? provinceSpecifique;
  final String? ville;
  final String? villeSpecifique;
  final String? commune;
  final String? communeSpecifique;
  final String? quartier;
  final String? quartierSpecifique;
  final String? avenue;
  final String? avenueSpecifique; 
  final String? numeroMaison;
  final double? price;
  final int? garantieIdeale;
  final int? garantieMinimale;
  final bool? disponibiliteImmediate;
  final DateTime? dateDisponibilite;
  final bool? maisonEnEtage;
  final int? niveauEtage;
  final String? description;

  // Description Physique
  final int? nombreChambres;
  final bool? hasSalon; 
  final bool? hasCuisine;
  final bool? hasToiletteParentale;
  final String? selectedTypeSol;
  
  final ImageSource? cuisineImage; 
  final ImageSource? toiletteParentaleImage;
  final ImageSource? salonImage; 
  
  final bool? hasGarage;
  final ImageSource? garageImage;
  final bool? hasCourRecreation;
  final ImageSource? courRecreationImage;
  final bool? hasDepot;
  final ImageSource? depotImage;

  final List<ImageSource> chambresImages; 
  
  final bool? maisonEnclos;
  final bool? possibiliteAnimaux;
  final String? typeMaison;

  // Services et Infrastructures
  final bool? hasEau;
  final bool? compteurEau;
  final String? electricite;
  final bool? accessibiliteVoiture;
  final bool? bailleurHabiteAvec;
  final int? nombreMenages;
  final bool? estReactif;

  // Informations Propriétaire
  final String? bailleurId;
  final String? nomProprietaire;
  final String? postnomProprietaire;
  final String? prenomProprietaire;
  final String? telephoneProprietaire;
  final String? emailProprietaire;
  final String? statutLegal;
  final String? statutLegalAutre; 
  final String? statutProfessionnel;
  final String? statutProAutre; 

  FormulairePublicationModel({
    this.id,
    this.mainImage, 
    this.typeBien,
    this.province,
    this.provinceSpecifique,
    this.ville,
    this.villeSpecifique,
    this.commune,
    this.communeSpecifique,
    this.quartier,
    this.quartierSpecifique,
    this.avenue,
    this.avenueSpecifique,
    this.numeroMaison,
    this.price,
    this.garantieIdeale,
    this.garantieMinimale,
    this.disponibiliteImmediate,
    this.dateDisponibilite,
    this.maisonEnEtage,
    this.niveauEtage,
    this.description,
    this.nombreChambres,
    this.hasSalon,
    this.hasCuisine,
    this.hasToiletteParentale,
    this.selectedTypeSol,
    this.cuisineImage, 
    this.toiletteParentaleImage, 
    this.salonImage, 
    this.hasGarage,
    this.garageImage, 
    this.hasCourRecreation,
    this.courRecreationImage, 
    this.hasDepot,
    this.depotImage, 
    this.chambresImages = const [], 
    this.maisonEnclos,
    this.possibiliteAnimaux,
    this.typeMaison,
    this.hasEau,
    this.compteurEau,
    this.electricite,
    this.accessibiliteVoiture,
    this.bailleurHabiteAvec,
    this.nombreMenages,
    this.estReactif,
    this.bailleurId,
    this.nomProprietaire,
    this.postnomProprietaire,
    this.prenomProprietaire,
    this.telephoneProprietaire,
    this.emailProprietaire,
    this.statutLegal,
    this.statutLegalAutre, 
    this.statutProfessionnel,
    this.statutProAutre, 
  });

  // ***************************************************************
  // ✅ LOGIQUE DE NORMALISATION (Gestion du "Autre")
  // ***************************************************************
  String get finalProvince => (province == "Autre" && provinceSpecifique != null && provinceSpecifique!.isNotEmpty) 
      ? provinceSpecifique! : (province ?? "");

  String get finalVille => (ville == "Autre" && villeSpecifique != null && villeSpecifique!.isNotEmpty) 
      ? villeSpecifique! : (ville ?? "");

  String get finalCommune => (commune == "Autre" && communeSpecifique != null && communeSpecifique!.isNotEmpty) 
      ? communeSpecifique! : (commune ?? "");

  String get finalQuartier => (quartier == "Autre" && quartierSpecifique != null && quartierSpecifique!.isNotEmpty) 
      ? quartierSpecifique! : (quartier ?? "");

  String get finalAvenue => (avenue == "Autre" && avenueSpecifique != null && avenueSpecifique!.isNotEmpty) 
      ? avenueSpecifique! : (avenue ?? "");

  // ***************************************************************
  // ✅ LOGIQUE DE RÉFÉRENCE UNIQUE HARMONISÉE
  // ***************************************************************
  String get referenceUnique {
    if (id != null && id!.length >= 6) {
      return id!.substring(0, 6).toUpperCase();
    }
    return id?.toUpperCase() ?? "PENDING"; 
  }

  // ***************************************************************
  // ✅ GETTER POUR LE RAPPORT D'EXPERTISE
  // ***************************************************************
  Map<String, ImageSource> get specificImages => {
    if (salonImage != null && !salonImage!.isEmpty) 'salonImage': salonImage!,
    if (cuisineImage != null && !cuisineImage!.isEmpty) 'cuisineImage': cuisineImage!,
    if (toiletteParentaleImage != null && !toiletteParentaleImage!.isEmpty) 'toiletteParentaleImage': toiletteParentaleImage!,
    if (garageImage != null && !garageImage!.isEmpty) 'garageImage': garageImage!,
    if (courRecreationImage != null && !courRecreationImage!.isEmpty) 'courRecreationImage': courRecreationImage!,
    if (depotImage != null && !depotImage!.isEmpty) 'depotImage': depotImage!,
  };

  factory FormulairePublicationModel.fromFirestore(Map<String, dynamic> json, String documentId) {
    final specific = json['specificImageUrls'] as Map<String, dynamic>? ?? {};

    return FormulairePublicationModel(
      id: documentId,
      bailleurId: json['bailleurId'],
      province: json['province'],
      provinceSpecifique: json['provinceSpecifique'],
      ville: json['ville'],
      villeSpecifique: json['villeSpecifique'],
      commune: json['commune'],
      communeSpecifique: json['communeSpecifique'],
      quartier: json['quartier'],
      quartierSpecifique: json['quartierSpecifique'],
      avenue: json['avenue'],
      avenueSpecifique: json['avenueSpecifique'],
      numeroMaison: json['numeroMaison'],
      price: (json['price'] as num?)?.toDouble(),
      garantieMinimale: json['garantieMinimale'] as int?,
      garantieIdeale: json['garantieIdeale'] as int?,
      description: json['description'],
      nombreChambres: json['nombreChambres'] as int?,
      
      hasSalon: (json['hasSalon'] == true) || (specific['salonImage'] != null),
      hasCuisine: (json['hasCuisine'] == true) || (specific['cuisineImage'] != null),
      hasToiletteParentale: (json['hasToiletteParentale'] == true) || (specific['toiletteParentaleImage'] != null),
      hasGarage: (json['hasGarage'] == true) || (specific['garageImage'] != null),
      hasCourRecreation: (json['hasCourRecreation'] == true) || (specific['courRecreationImage'] != null),
      hasDepot: (json['hasDepot'] == true) || (specific['depotImage'] != null),
      
      maisonEnclos: json['maisonEnclos'] == true,
      possibiliteAnimaux: json['possibiliteAnimaux'] == true,
      hasEau: json['hasEau'] == true,
      compteurEau: json['compteurEau'] == true,
      accessibiliteVoiture: json['accessibiliteVoiture'] == true,
      bailleurHabiteAvec: json['bailleurHabiteAvec'] == true,
      estReactif: json['estReactif'] == true,
      disponibiliteImmediate: json['disponibiliteImmediate'] ?? true,
      maisonEnEtage: json['maisonEnEtage'] == true,
      typeBien: json['typeBien'], 
      selectedTypeSol: (json['selectedTypeSol'] as String?)?.trim().toLowerCase(),
      typeMaison: (json['typeMaison'] as String?)?.trim().toLowerCase(),
      electricite: (json['electricite'] as String?)?.trim().toLowerCase(),
      nombreMenages: json['nombreMenages'] as int? ?? 1,
      niveauEtage: json['niveauEtage'] as int?,
      
      mainImage: json['mainImageUrl'] != null ? ImageSource(url: json['mainImageUrl']) : null,
      salonImage: specific['salonImage'] != null ? ImageSource(url: specific['salonImage']) : null,
      cuisineImage: specific['cuisineImage'] != null ? ImageSource(url: specific['cuisineImage']) : null,
      toiletteParentaleImage: specific['toiletteParentaleImage'] != null ? ImageSource(url: specific['toiletteParentaleImage']) : null,
      garageImage: specific['garageImage'] != null ? ImageSource(url: specific['garageImage']) : null,
      courRecreationImage: specific['courRecreationImage'] != null ? ImageSource(url: specific['courRecreationImage']) : null,
      depotImage: specific['depotImage'] != null ? ImageSource(url: specific['depotImage']) : null,
      
      chambresImages: (json['chambresImageUrls'] as List<dynamic>?)
              ?.map((url) => ImageSource(url: url as String))
              .toList() ?? [],
              
      nomProprietaire: json['nomProprietaire'],
      postnomProprietaire: json['postnomProprietaire'],
      prenomProprietaire: json['prenomProprietaire'],
      telephoneProprietaire: json['telephoneProprietaire'],
      emailProprietaire: json['emailProprietaire'],
      statutLegal: json['statutLegal'],
      statutLegalAutre: json['statutLegalAutre'],
      statutProfessionnel: json['statutProfessionnel'],
      statutProAutre: json['statutProAutre'],
    );
  }

  factory FormulairePublicationModel.fromProperty(Property p) {
    return FormulairePublicationModel(
      id: p.id, 
      bailleurId: p.bailleurId,
      typeBien: p.typeBien ?? "Maison Résidentielle",
      province: p.province,
      provinceSpecifique: p.provinceSpecifique,
      ville: p.ville,
      villeSpecifique: p.villeSpecifique, 
      commune: p.commune,
      communeSpecifique: p.communeSpecifique, 
      quartier: p.quartier,
      quartierSpecifique: p.quartierSpecifique, 
      avenue: p.avenue,
      avenueSpecifique: p.avenueSpecifique, 
      numeroMaison: p.numeroMaison,
      price: p.price,
      garantieIdeale: p.garantieIdeale,
      garantieMinimale: p.garantieMinimale,
      description: p.description,
      nombreChambres: p.nombreChambres,
      hasSalon: p.hasSalon,
      hasCuisine: p.hasCuisine,
      hasToiletteParentale: p.hasToiletteParentale,
      selectedTypeSol: p.selectedTypeSol?.trim().toLowerCase(),
      typeMaison: p.typeMaison?.trim().toLowerCase(),
      electricite: p.electricite?.trim().toLowerCase(),
      hasGarage: p.hasGarage,
      hasCourRecreation: p.hasCourRecreation,
      hasDepot: p.hasDepot, 
      maisonEnclos: p.maisonEnclos,
      possibiliteAnimaux: p.possibiliteAnimaux,
      hasEau: p.hasEau,
      compteurEau: p.compteurEau,
      accessibiliteVoiture: p.accessibiliteVoiture,
      bailleurHabiteAvec: p.bailleurHabiteAvec,
      nombreMenages: p.nombreMenages,
      estReactif: p.estReactif,
      disponibiliteImmediate: p.disponibiliteImmediate,
      dateDisponibilite: p.dateDisponibilite,
      maisonEnEtage: p.maisonEnEtage,
      niveauEtage: p.niveauEtage,
      nomProprietaire: p.nomProprietaire,
      postnomProprietaire: p.postnomProprietaire,
      prenomProprietaire: p.prenomProprietaire,
      telephoneProprietaire: p.telephoneProprietaire,
      emailProprietaire: p.emailProprietaire,
      statutLegal: p.statutLegal,
      statutLegalAutre: p.statutLegalAutre, 
      statutProfessionnel: p.statutProfessionnel,
      statutProAutre: p.statutProAutre, 
      mainImage: ImageSource(url: p.mainImageUrl),
      chambresImages: (p.chambresImageUrls ?? []).map((url) => ImageSource(url: url)).toList(),
      salonImage: p.specificImageUrls['salonImage'] != null ? ImageSource(url: p.specificImageUrls['salonImage']) : null,
      cuisineImage: p.specificImageUrls['cuisineImage'] != null ? ImageSource(url: p.specificImageUrls['cuisineImage']) : null,
      toiletteParentaleImage: p.specificImageUrls['toiletteParentaleImage'] != null ? ImageSource(url: p.specificImageUrls['toiletteParentaleImage']) : null,
      garageImage: p.specificImageUrls['garageImage'] != null ? ImageSource(url: p.specificImageUrls['garageImage']) : null,
      courRecreationImage: p.specificImageUrls['courRecreationImage'] != null ? ImageSource(url: p.specificImageUrls['courRecreationImage']) : null,
      depotImage: p.specificImageUrls['depotImage'] != null ? ImageSource(url: p.specificImageUrls['depotImage']) : null,
    );
  }

  FormulairePublicationModel copyWith({
    String? id,
    ImageSource? mainImage, 
    String? typeBien,
    String? province,
    String? provinceSpecifique,
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
    int? garantieIdeale,
    int? garantieMinimale,
    bool? disponibiliteImmediate,
    DateTime? dateDisponibilite,
    bool? maisonEnEtage,
    int? niveauEtage,
    String? description,
    int? nombreChambres,
    bool? hasSalon,
    bool? hasCuisine,
    bool? hasToiletteParentale,
    String? selectedTypeSol,
    bool? hasGarage,
    bool? hasCourRecreation,
    bool? hasDepot,
    Object? cuisineImage = FormulairePublicationModelSentinel, 
    Object? toiletteParentaleImage = FormulairePublicationModelSentinel, 
    Object? salonImage = FormulairePublicationModelSentinel, 
    Object? garageImage = FormulairePublicationModelSentinel, 
    Object? courRecreationImage = FormulairePublicationModelSentinel, 
    Object? depotImage = FormulairePublicationModelSentinel, 
    List<ImageSource>? chambresImages, 
    bool? maisonEnclos,
    bool? possibiliteAnimaux,
    String? typeMaison,
    bool? hasEau,
    bool? compteurEau,
    String? electricite,
    bool? accessibiliteVoiture,
    bool? bailleurHabiteAvec,
    int? nombreMenages,
    bool? estReactif,
    String? bailleurId,
    String? nomProprietaire,
    String? postnomProprietaire,
    String? prenomProprietaire,
    String? telephoneProprietaire,
    String? emailProprietaire,
    String? statutLegal,
    String? statutLegalAutre, 
    String? statutProfessionnel,
    String? statutProAutre, 
  }) {
    return FormulairePublicationModel(
      id: id ?? this.id,
      mainImage: mainImage ?? this.mainImage, 
      typeBien: typeBien ?? this.typeBien,
      province: province ?? this.province,
      provinceSpecifique: provinceSpecifique ?? this.provinceSpecifique,
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
      garantieIdeale: garantieIdeale ?? this.garantieIdeale,
      garantieMinimale: garantieMinimale ?? this.garantieMinimale,
      disponibiliteImmediate: disponibiliteImmediate ?? this.disponibiliteImmediate,
      dateDisponibilite: dateDisponibilite ?? this.dateDisponibilite,
      maisonEnEtage: maisonEnEtage ?? this.maisonEnEtage,
      niveauEtage: niveauEtage ?? this.niveauEtage,
      description: description ?? this.description,
      nombreChambres: nombreChambres ?? this.nombreChambres,
      hasSalon: hasSalon ?? this.hasSalon,
      hasCuisine: hasCuisine ?? this.hasCuisine,
      hasToiletteParentale: hasToiletteParentale ?? this.hasToiletteParentale,
      selectedTypeSol: selectedTypeSol ?? this.selectedTypeSol,
      hasGarage: hasGarage ?? this.hasGarage,
      hasCourRecreation: hasCourRecreation ?? this.hasCourRecreation,
      hasDepot: hasDepot ?? this.hasDepot,
      cuisineImage: cuisineImage == FormulairePublicationModelSentinel ? this.cuisineImage : (cuisineImage as ImageSource?), 
      toiletteParentaleImage: toiletteParentaleImage == FormulairePublicationModelSentinel ? this.toiletteParentaleImage : (toiletteParentaleImage as ImageSource?), 
      salonImage: salonImage == FormulairePublicationModelSentinel ? this.salonImage : (salonImage as ImageSource?), 
      garageImage: garageImage == FormulairePublicationModelSentinel ? this.garageImage : (garageImage as ImageSource?), 
      courRecreationImage: courRecreationImage == FormulairePublicationModelSentinel ? this.courRecreationImage : (courRecreationImage as ImageSource?), 
      depotImage: depotImage == FormulairePublicationModelSentinel ? this.depotImage : (depotImage as ImageSource?), 
      chambresImages: chambresImages ?? this.chambresImages, 
      maisonEnclos: maisonEnclos ?? this.maisonEnclos,
      possibiliteAnimaux: possibiliteAnimaux ?? this.possibiliteAnimaux,
      typeMaison: typeMaison ?? this.typeMaison,
      hasEau: hasEau ?? this.hasEau,
      compteurEau: compteurEau ?? this.compteurEau,
      electricite: electricite ?? this.electricite,
      accessibiliteVoiture: accessibiliteVoiture ?? this.accessibiliteVoiture,
      bailleurHabiteAvec: bailleurHabiteAvec ?? this.bailleurHabiteAvec,
      nombreMenages: nombreMenages ?? this.nombreMenages,
      estReactif: estReactif ?? this.estReactif,
      bailleurId: bailleurId ?? this.bailleurId,
      nomProprietaire: nomProprietaire ?? this.nomProprietaire,
      postnomProprietaire: postnomProprietaire ?? this.postnomProprietaire,
      prenomProprietaire: prenomProprietaire ?? this.prenomProprietaire,
      telephoneProprietaire: telephoneProprietaire ?? this.telephoneProprietaire,
      emailProprietaire: emailProprietaire ?? this.emailProprietaire,
      statutLegal: statutLegal ?? this.statutLegal,
      statutLegalAutre: statutLegalAutre ?? this.statutLegalAutre, 
      statutProfessionnel: statutProfessionnel ?? this.statutProfessionnel,
      statutProAutre: statutProAutre ?? this.statutProAutre, 
    );
  }

  List<String> _generateSearchKeywords() {
    List<String> keywords = [];
    void addKeyword(String? value) {
      if (value != null && value.trim().isNotEmpty) {
        keywords.add(value.toLowerCase().trim());
      }
    }
    addKeyword(province); addKeyword(ville); addKeyword(commune);
    addKeyword(quartier); addKeyword(typeBien);
    return keywords.toSet().toList();
  }

  Map<String, dynamic> toMap({
    required String mainImageUrl, 
    required List<String> chambresImageUrls,
    required Map<String, String> specificImageUrls,
  }) {
    final now = FieldValue.serverTimestamp(); 

    return {
      'bailleurId': bailleurId ?? '',
      'province': finalProvince, 
      'provinceSpecifique': provinceSpecifique ?? '',
      
      // ✅ Utilisation des getters normalisés pour la base de données
      'ville': finalVille,
      'villeSpecifique': villeSpecifique ?? '',
      'commune': finalCommune,
      'communeSpecifique': communeSpecifique ?? '',
      'quartier': finalQuartier,
      'quartierSpecifique': quartierSpecifique ?? '',
      'avenue': finalAvenue,
      'avenueSpecifique': avenueSpecifique ?? '',
      
      'numeroMaison': numeroMaison ?? '', 
      'price': price ?? 0.0, 
      'garantieIdeale': garantieIdeale ?? 0, 
      'garantieMinimale': garantieMinimale ?? 0, 
      'description': description ?? '', 
      'estReactif': estReactif ?? false, 
      'maisonEnEtage': maisonEnEtage ?? false, 
      'disponibiliteImmediate': disponibiliteImmediate ?? false, 
      'hasSalon': hasSalon ?? false,
      'hasCuisine': hasCuisine ?? false, 
      'hasToiletteParentale': hasToiletteParentale ?? false, 
      'hasGarage': hasGarage ?? false, 
      'hasCourRecreation': hasCourRecreation ?? false, 
      'hasDepot': hasDepot ?? false, 
      'maisonEnclos': maisonEnclos ?? false, 
      'possibiliteAnimaux': possibiliteAnimaux ?? false, 
      'hasEau': hasEau ?? false, 
      'compteurEau': compteurEau ?? false, 
      'accessibiliteVoiture': accessibiliteVoiture ?? false, 
      'bailleurHabiteAvec': bailleurHabiteAvec ?? false, 
      'electricite': electricite ?? '', 
      'nomProprietaire': nomProprietaire ?? '', 
      'postnomProprietaire': postnomProprietaire ?? '', 
      'prenomProprietaire': prenomProprietaire ?? '', 
      'telephoneProprietaire': telephoneProprietaire ?? '', 
      'emailProprietaire': emailProprietaire ?? '', 
      'mainImageUrl': mainImageUrl, 
      'chambresImageUrls': chambresImageUrls,
      'specificImageUrls': specificImageUrls,
      'typeBien': typeBien ?? 'Maison Résidentielle',
      'nombreChambres': nombreChambres ?? 0, 
      'selectedTypeSol': selectedTypeSol ?? '',
      'typeMaison': typeMaison ?? '',
      'nombreMenages': nombreMenages ?? 1,
      'dateDisponibilite': dateDisponibilite != null ? Timestamp.fromDate(dateDisponibilite!) : null,
      'niveauEtage': niveauEtage ?? 0,
      'statutLegal': statutLegal ?? '',
      'statutLegalAutre': statutLegalAutre ?? '', 
      'statutProfessionnel': statutProfessionnel ?? '',
      'statutProAutre': statutProAutre ?? '', 
      'searchKeywords': _generateSearchKeywords(),
      'createdAt': now,
      'publicationDate': now,
      'lastUpdated': now,
      'updatedAt': now,
      'sortIndex': 0,
      'status': PropertyStatus.disponible, 
      'estLouee': false, 
      'isVerified': false,
      FirestoreFields.processingStatus: WorkflowStatus.jachere, 
      'isHiddenFromBailleur': false,
      'views': 0,
    };
  }

  Map<String, dynamic> toUpdateMap({
    required String mainImageUrl,
    required List<String> chambresImageUrls,
    required Map<String, String> specificImageUrls,
    required int existingViewCount,
    required Timestamp? initialPublicationDate,
  }) {
    final data = toMap(
      mainImageUrl: mainImageUrl,
      chambresImageUrls: chambresImageUrls,
      specificImageUrls: specificImageUrls,
    );
    
    final updateTime = FieldValue.serverTimestamp();

    data['publicationDate'] = initialPublicationDate ?? updateTime; 
    data['views'] = existingViewCount; 
    
    data['lastUpdated'] = updateTime;
    data['updatedAt'] = updateTime;
    
    data.remove('createdAt'); 
    return data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FormulairePublicationModel &&
        other.id == id &&
        other.mainImage == mainImage &&
        other.typeBien == typeBien &&
        other.price == price &&
        other.hasDepot == hasDepot &&
        listEquals(other.chambresImages, chambresImages) &&
        other.bailleurId == bailleurId;
  }

  @override
  int get hashCode {
    return Object.hashAll([id, mainImage, typeBien, price, hasDepot, Object.hashAll(chambresImages), bailleurId]);
  }
}