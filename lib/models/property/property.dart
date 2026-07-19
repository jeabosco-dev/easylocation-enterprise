import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import 'package:easylocation_mvp/models/property/property_factory.dart';

class Property {
  final String id;
  final String bailleurId;
  final String moderationStatus;

  // ============================================================
  // 1. INFORMATIONS GÉNÉRALES & ADRESSE
  // ============================================================

  final String typeBien;
  final String? categorie;

  final String province;
  final String? provinceKey;
  final String? provinceLabel;
  final String? provinceSpecifique;

  final String ville;
  final String? villeKey;
  final String? villeLabel;
  final String? villeSpecifique;

  final String commune;
  final String? communeKey;
  final String? communeLabel;
  final String? communeSpecifique;

  final String quartier;
  final String? quartierKey;
  final String? quartierLabel;
  final String? quartierSpecifique;

  final String avenue;
  final String? avenueKey;
  final String? avenueLabel;
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

  // ============================================================
  // 2. DESCRIPTION PHYSIQUE
  // ============================================================

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

  // ============================================================
  // 3. SERVICES ET INFRASTRUCTURES
  // ============================================================

  final bool hasEau;
  final bool compteurEau;
  final String electricite;
  final bool accessibiliteVoiture;
  final bool bailleurHabiteAvec;
  final int? nombreMenages;

  // ============================================================
  // 4. INFORMATIONS PROPRIÉTAIRE
  // ============================================================

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

  final String? nomBailleur;
  final String? telBailleur;

  final String? categorieEligible;
  final String? serviceEligible;

  // ============================================================
  // 5. MÉTADONNÉES, BOOST & COMPTEURS
  // ============================================================

  final DateTime? publicationDate;
  final DateTime createdAt;
  final DateTime? lastBoost;

  final int sortIndex;

  // ⚠️ Conservés non-final pour préserver le comportement existant
  int views;
  final DateTime? derniereVue;

  int shares;
  int favoriteCount;

  final double averageRating;
  final int ratingCount;
  final double totalRating;

  // ============================================================
  // 6. STATUTS & WORKFLOW
  // ============================================================

  final String status;
  final int statusPriority;
  final bool isHiddenFromBailleur;
  final bool isVerified;

  final bool hasPriorityRequest;
  final String? priorityStatus;
  final DateTime? priorityRequestAt;

  final String processingStatus;

  final String? assignedAdminId;
  final String? assignedAdminName;
  final String? lastUpdateBy;

  final int? lockTimestamp;
  final String? lockedBy;

  final String? lastLocataireId;

  // ============================================================
  // 7. IMAGES
  // ============================================================

  final Map<String, String> specificImageUrls;
  final List<String> chambresImageUrls;
  final List<String> firestoreImageUrls;
  final String? mainImageUrl;

  // ============================================================
  // CONSTRUCTEUR
  // ============================================================

  Property({
    required this.id,
    required this.bailleurId,
    this.moderationStatus = 'visible',
    required this.typeBien,
    this.categorie,
    required this.province,
    this.provinceKey,
    this.provinceLabel,
    this.provinceSpecifique,
    required this.ville,
    this.villeKey,
    this.villeLabel,
    this.villeSpecifique,
    required this.commune,
    this.communeKey,
    this.communeLabel,
    this.communeSpecifique,
    required this.quartier,
    this.quartierKey,
    this.quartierLabel,
    this.quartierSpecifique,
    required this.avenue,
    this.avenueKey,
    this.avenueLabel,
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
    this.nomBailleur,
    this.telBailleur,
    this.categorieEligible,
    this.serviceEligible,
    this.publicationDate,
    required this.createdAt,
    this.lastBoost,
    this.sortIndex = 0,
    this.views = 0,
    this.derniereVue,
    this.shares = 0,
    this.favoriteCount = 0,
    required this.averageRating,
    required this.ratingCount,
    required this.totalRating,
    this.status = PropertyStatus.disponible,
    this.statusPriority = 1,
    this.isHiddenFromBailleur = false,
    this.isVerified = false,
    this.hasPriorityRequest = false,
    this.priorityStatus,
    this.priorityRequestAt,
    this.processingStatus = WorkflowStatus.jachere,
    this.assignedAdminId,
    this.assignedAdminName,
    this.lastUpdateBy,
    this.lockTimestamp,
    this.lockedBy,
    this.lastLocataireId,
    this.specificImageUrls = const {},
    this.chambresImageUrls = const [],
    this.firestoreImageUrls = const [],
    this.mainImageUrl,
  });

  // ============================================================
  // FACTORIES PUBLIQUES
  // ============================================================

  factory Property.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PropertyFactory.fromFirestore(doc);
  }

  factory Property.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    return PropertyFactory.fromMap(data, id);
  }
}