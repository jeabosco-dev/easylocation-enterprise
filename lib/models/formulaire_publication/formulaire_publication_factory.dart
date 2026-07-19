// lib/models/formulaire_publication/formulaire_publication_factory.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'formulaire_publication.dart'; // Import corrigé pour éviter la boucle circulaire
import 'formulaire_publication_image_source.dart';
import '../property_model.dart';

class FormulairePublicationFactory {
  static FormulairePublicationModel fromFirestore(
    Map<String, dynamic> json,
    String documentId,
  ) {
    final specific = json['specificImageUrls'] as Map<String, dynamic>? ?? {};

    // Correction : Récupération sécurisée de la date
    DateTime? dateDisponibilite;
    final rawDateDisponibilite = json['dateDisponibilite'];
    if (rawDateDisponibilite is Timestamp) {
      dateDisponibilite = rawDateDisponibilite.toDate();
    }

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
      moderationStatus: json['moderationStatus'] ?? 'visible',
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
      dateDisponibilite: dateDisponibilite, // Utilisation de la variable corrigée
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
      
      nomBailleur: json['nomBailleur'],
      telBailleur: json['telBailleur'],
      categorieEligible: json['categorieEligible'],
      serviceEligible: json['serviceEligible'],
    );
  }

  static FormulairePublicationModel fromProperty(Property p) {
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
      moderationStatus: p.moderationStatus, // Ajout du statut de modération
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
      
      nomBailleur: p.nomBailleur,
      telBailleur: p.telBailleur,
      categorieEligible: p.categorieEligible,
      serviceEligible: p.serviceEligible,
    );
  }
}