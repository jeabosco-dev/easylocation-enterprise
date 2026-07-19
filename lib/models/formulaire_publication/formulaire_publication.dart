// lib/models/formulaire_publication/formulaire_publication.dart

import 'package:easylocation_mvp/models/property_model.dart';

import 'formulaire_publication_image_source.dart';
import 'formulaire_publication_factory.dart';

/// Sentinel utilisé par copyWith pour distinguer :
///
/// 1. paramètre non fourni
/// 2. paramètre fourni avec null
///
/// Exemple :
///
/// copyWith(
///   salonImage: null,
/// )
///
/// signifie : supprimer l'image.
///
/// Alors que :
///
/// copyWith()
///
/// signifie : conserver l'image existante.
const FormulairePublicationModelSentinel = Object();

class FormulairePublicationModel {
  // ***************************************************************
  // IDENTIFICATION
  // ***************************************************************

  String? id;

  // ***************************************************************
  // INFORMATIONS GÉNÉRALES
  // ***************************************************************

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

  final String? moderationStatus;

  // ***************************************************************
  // DESCRIPTION PHYSIQUE
  // ***************************************************************

  final int? nombreChambres;

  final bool? hasSalon;
  final bool? hasCuisine;
  final bool? hasToiletteParentale;

  final String? selectedTypeSol;

  // ***************************************************************
  // IMAGES SPÉCIFIQUES
  // ***************************************************************

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

  // ***************************************************************
  // AUTRES CARACTÉRISTIQUES
  // ***************************************************************

  final bool? maisonEnclos;
  final bool? possibiliteAnimaux;

  final String? typeMaison;

  // ***************************************************************
  // SERVICES ET INFRASTRUCTURES
  // ***************************************************************

  final bool? hasEau;
  final bool? compteurEau;

  final String? electricite;

  final bool? accessibiliteVoiture;
  final bool? bailleurHabiteAvec;

  final int? nombreMenages;

  final bool? estReactif;

  // ***************************************************************
  // INFORMATIONS PROPRIÉTAIRE
  // ***************************************************************

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

  // ***************************************************************
  // INFORMATIONS BAILLEUR / SERVICES
  // ***************************************************************

  final String? nomBailleur;
  final String? telBailleur;

  final String? categorieEligible;
  final String? serviceEligible;

  // ***************************************************************
  // CONSTRUCTEUR
  // ***************************************************************

  FormulairePublicationModel({
    this.id,

    // Informations générales
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

    this.moderationStatus,

    // Description physique
    this.nombreChambres,

    this.hasSalon,
    this.hasCuisine,
    this.hasToiletteParentale,

    this.selectedTypeSol,

    // Images
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

    // Caractéristiques
    this.maisonEnclos,
    this.possibiliteAnimaux,
    this.typeMaison,

    // Services
    this.hasEau,
    this.compteurEau,

    this.electricite,

    this.accessibiliteVoiture,
    this.bailleurHabiteAvec,

    this.nombreMenages,

    this.estReactif,

    // Propriétaire
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

    // Bailleur
    this.nomBailleur,
    this.telBailleur,

    this.categorieEligible,
    this.serviceEligible,
  });

  // ***************************************************************
  // FACTORY FIRESTORE
  // ***************************************************************

  factory FormulairePublicationModel.fromFirestore(
    Map<String, dynamic> json,
    String documentId,
  ) {
    return FormulairePublicationFactory.fromFirestore(
      json,
      documentId,
    );
  }

  // ***************************************************************
  // FACTORY PROPERTY
  // ***************************************************************

  factory FormulairePublicationModel.fromProperty(Property p) {
    return FormulairePublicationFactory.fromProperty(p);
  }
}