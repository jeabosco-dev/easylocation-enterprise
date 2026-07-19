// lib/models/formulaire_publication/formulaire_publication_serializer.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import 'formulaire_publication.dart';
import 'formulaire_publication_getters.dart';
import '../property_model.dart' hide PropertyStatus;

extension FormulairePublicationSerializer on FormulairePublicationModel {
  
  // ***************************************************************
  // ✅ SERIALISATION VERS FIRESTORE
  // ***************************************************************
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
      'moderationStatus': moderationStatus ?? 'visible',
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
      
      'nomBailleur': nomBailleur ?? '',
      'telBailleur': telBailleur ?? '',
      'categorieEligible': categorieEligible ?? '',
      'serviceEligible': serviceEligible ?? '',
      
      'searchKeywords': searchKeywords,
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

  // ***************************************************************
  // ✅ MISE À JOUR FIRESTORE
  // ***************************************************************
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
}