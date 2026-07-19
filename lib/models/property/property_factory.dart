import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import 'package:easylocation_mvp/models/property/property.dart';
import 'package:easylocation_mvp/models/property/property_parsing_utils.dart';
import 'package:easylocation_mvp/models/property/property_status.dart';

class PropertyFactory {
  // ============================================================
  // FIRESTORE → PROPERTY
  // ============================================================

  static Property fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    if (data == null) {
      throw StateError(
        'Document nul pour l\'ID: ${doc.id}',
      );
    }

    return fromMap(data, doc.id);
  }

  // ============================================================
  // MAP → PROPERTY
  // ============================================================

  static Property fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    final Map<String, dynamic> specificImages =
        data['specificImageUrls'] != null
            ? Map<String, dynamic>.from(
                data['specificImageUrls'],
              )
            : {};

    // Normalisation du statut une seule fois ici
    final normalizedStatus = PropertyStatusNormalizer.normalize(
      data[FirestoreFields.status]?.toString(),
    );

    return Property(
      id: id,

      bailleurId: data['bailleurId']?.toString() ?? '',

      moderationStatus: data['moderationStatus']?.toString() ?? 'visible',

      // ========================================================
      // INFORMATIONS GÉNÉRALES & ADRESSE
      // ========================================================

      typeBien: data['typeBien']?.toString() ??
          data['type']?.toString() ??
          'Maison',

      categorie: data['categorie']?.toString(),

      province: data['province']?.toString() ?? '',

      provinceKey: data['provinceKey'] ??
          data['province']?.toString().toLowerCase(),

      provinceLabel: data['provinceLabel'] ??
          data['province'],

      provinceSpecifique: data['provinceSpecifique']?.toString(),

      ville: data['ville']?.toString() ?? '',

      villeKey: data['villeKey'] ??
          data['ville']?.toString().toLowerCase(),

      villeLabel: data['villeLabel'] ??
          data['ville'],

      villeSpecifique: data['villeSpecifique']?.toString(),

      commune: data['commune']?.toString() ?? '',

      communeKey: data['communeKey'] ??
          data['commune']?.toString().toLowerCase(),

      communeLabel: data['communeLabel'] ??
          data['commune'],

      communeSpecifique: data['communeSpecifique']?.toString(),

      quartier: data['quartier']?.toString() ?? '',

      quartierKey: data['quartierKey'] ??
          data['quartier']?.toString().toLowerCase(),

      quartierLabel: data['quartierLabel'] ??
          data['quartier'],

      quartierSpecifique: data['quartierSpecifique']?.toString(),

      avenue: data['avenue']?.toString() ?? '',

      avenueKey: data['avenueKey'] ??
          data['avenue']?.toString().toLowerCase(),

      avenueLabel: data['avenueLabel'] ??
          data['avenue'],

      avenueSpecifique: data['avenueSpecifique']?.toString(),

      numeroMaison: data['numeroMaison']?.toString() ?? '',

      price: (data[FirestoreFields.price] as num?)?.toDouble() ?? 0.0,

      nombreChambres: (data['nombreChambres'] as num?)?.toInt() ?? 0,

      garantieIdeale: (data['garantieIdeale'] as num?)?.toInt() ?? 0,

      garantieMinimale: (data['garantieMinimale'] as num?)?.toInt() ?? 0,

      disponibiliteImmediate: PropertyParsingUtils.readBool(
        data,
        'disponibiliteImmediate',
      ),

      dateDisponibilite: PropertyParsingUtils.parseDate(
        data['dateDisponibilite'],
      ),

      maisonEnEtage: PropertyParsingUtils.readBool(
        data,
        'maisonEnEtage',
      ),

      niveauEtage: (data['niveauEtage'] as num?)?.toInt(),

      description: data['description']?.toString() ?? '',

      // ========================================================
      // DESCRIPTION PHYSIQUE
      // ========================================================

      hasSalon: PropertyParsingUtils.readBool(
            data,
            'hasSalon',
          ) ||
          specificImages['salonImage'] != null,

      hasCuisine: PropertyParsingUtils.readBool(
            data,
            'hasCuisine',
          ) ||
          specificImages['cuisineImage'] != null,

      hasToiletteParentale: PropertyParsingUtils.readBool(
            data,
            'hasToiletteParentale',
          ) ||
          specificImages['toiletteParentaleImage'] != null,

      selectedTypeSol: data['selectedTypeSol']?.toString(),

      hasGarage: PropertyParsingUtils.readBool(
            data,
            'hasGarage',
          ) ||
          specificImages['garageImage'] != null,

      hasCourRecreation: PropertyParsingUtils.readBool(
            data,
            'hasCourRecreation',
          ) ||
          specificImages['courRecreationImage'] != null,

      hasDepot: PropertyParsingUtils.readBool(
            data,
            'hasDepot',
          ) ||
          specificImages['depotImage'] != null,

      maisonEnclos: PropertyParsingUtils.readBool(
        data,
        'maisonEnclos',
      ),

      possibiliteAnimaux: PropertyParsingUtils.readBool(
        data,
        'possibiliteAnimaux',
      ),

      typeMaison: data['typeMaison']?.toString(),

      // ========================================================
      // SERVICES & INFRASTRUCTURES
      // ========================================================

      hasEau: PropertyParsingUtils.readBool(
        data,
        'hasEau',
      ),

      compteurEau: PropertyParsingUtils.readBool(
        data,
        'compteurEau',
      ),

      electricite: data['electricite']?.toString() ?? 'Non spécifié',

      accessibiliteVoiture: PropertyParsingUtils.readBool(
        data,
        'accessibiliteVoiture',
      ),

      bailleurHabiteAvec: PropertyParsingUtils.readBool(
        data,
        'bailleurHabiteAvec',
      ),

      nombreMenages: (data['nombreMenages'] as num?)?.toInt(),

      // ========================================================
      // PROPRIÉTAIRE
      // ========================================================

      nomProprietaire: data['nomProprietaire']?.toString() ?? 'Inconnu',

      postnomProprietaire: data['postnomProprietaire']?.toString() ?? '',

      prenomProprietaire: data['prenomProprietaire']?.toString() ?? '',

      telephoneProprietaire: data['telephoneProprietaire']?.toString() ?? '',

      emailProprietaire: data['emailProprietaire']?.toString() ?? '',

      statutLegal: data['statutLegal']?.toString(),

      statutLegalAutre: data['statutLegalAutre']?.toString(),

      statutProfessionnel: data['statutProfessionnel']?.toString(),

      statutProAutre: data['statutProAutre']?.toString(),

      estReactif: PropertyParsingUtils.readBool(
        data,
        'estReactif',
      ),

      nomBailleur: data['nomBailleur']?.toString(),

      telBailleur: data['telBailleur']?.toString(),

      categorieEligible: data['categorieEligible']?.toString(),

      serviceEligible: data['serviceEligible']?.toString(),

      // ========================================================
      // MÉTADONNÉES
      // ========================================================

      publicationDate: PropertyParsingUtils.parseDate(
        data['publicationDate'],
      ),

      createdAt: PropertyParsingUtils.parseDate(
            data['createdAt'],
          ) ??
          DateTime.now(),

      lastBoost: PropertyParsingUtils.parseDate(
        data['lastBoost'],
      ),

      sortIndex: (data['sortIndex'] as num?)?.toInt() ?? 0,

      views: (data['views'] as num?)?.toInt() ??
          (data['nb_vues'] as num?)?.toInt() ??
          0,

      derniereVue: PropertyParsingUtils.parseDate(
        data['derniere_vue'],
      ),

      shares: (data['shares'] as num?)?.toInt() ?? 0,

      favoriteCount: (data['favoriteCount'] as num?)?.toInt() ?? 0,

      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,

      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,

      totalRating: (data['totalRating'] as num?)?.toDouble() ?? 0.0,

      // ========================================================
      // STATUTS
      // ========================================================

      status: normalizedStatus,

      statusPriority: (data['statusPriority'] as num?)?.toInt() ??
          PropertyStatusNormalizer.getStatusPriority(normalizedStatus),

      isHiddenFromBailleur: PropertyParsingUtils.readBool(
        data,
        'isHiddenFromBailleur',
      ),

      isVerified: PropertyParsingUtils.readBool(
        data,
        FirestoreFields.isVerified,
      ),

      hasPriorityRequest: PropertyParsingUtils.readBool(
        data,
        'hasPriorityRequest',
      ),

      priorityStatus: data['priorityStatus']?.toString(),

      priorityRequestAt: PropertyParsingUtils.parseDate(
        data['priorityRequestAt'],
      ),

      processingStatus: data[FirestoreFields.processingStatus]?.toString() ??
          WorkflowStatus.jachere,

      assignedAdminId: data[FirestoreFields.assignedAdminId]?.toString(),

      assignedAdminName: data[FirestoreFields.assignedAdminName]?.toString(),

      lastUpdateBy: data[FirestoreFields.lastUpdateBy]?.toString(),

      lockTimestamp: (data['lockTimestamp'] as num?)?.toInt(),

      lockedBy: data['lockedBy']?.toString(),

      lastLocataireId: data['lastLocataireId']?.toString(),

      // ========================================================
      // IMAGES
      // ========================================================

      specificImageUrls: PropertyParsingUtils.readStringMap(
        data,
        'specificImageUrls',
      ),

      chambresImageUrls: PropertyParsingUtils.readStringList(
        data,
        'chambresImageUrls',
      ),

      firestoreImageUrls: PropertyParsingUtils.readStringList(
        data,
        FirestoreFields.imageUrls,
      ),

      mainImageUrl: data['mainImageUrl']?.toString() ??
          (data[FirestoreFields.imageUrls] is List &&
                  (data[FirestoreFields.imageUrls] as List).isNotEmpty
              ? data[FirestoreFields.imageUrls][0].toString()
              : null),
    );
  }
}