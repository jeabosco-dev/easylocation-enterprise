// lib/services/property_service.dart

import 'dart:async'; 
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ Correction : on cache PropertyStatus du modèle car on utilise celui des constantes
import 'package:easylocation_mvp/models/property_model.dart' hide PropertyStatus;
import 'package:easylocation_mvp/models/filtre_propriete_model.dart'; 

import 'package:easylocation_mvp/models/facture_model.dart'; 
import 'package:flutter/foundation.dart'; 
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:easylocation_mvp/constants/constants.dart';

// ====================================================================
// 🚀 FONCTIONS DE PREMIER NIVEAU (TOP-LEVEL) POUR LES ISOLATES
// ====================================================================

class _ParsingInput {
  final Map<String, dynamic> data;
  final String id;
  const _ParsingInput(this.data, this.id);
}

Property _handleSingleParsing(_ParsingInput input) {
  return Property.fromMap(input.data, input.id);
}

List<Property> _handleListParsing(List<_ParsingInput> inputs) {
  return inputs.map((e) => Property.fromMap(e.data, e.id)).toList();
}

// ====================================================================
// CLASSE PRINCIPALE DU SERVICE
// ====================================================================

class PropertyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  final String _propertyCollection = FirestoreCollections.properties; 
  final Random _rng = Random();

  FirebaseFirestore get db => _db;

  // -----------------------------------------------------------------
  // ✅ RECHERCHE AVANCÉE AVEC FILTRES ET TRI HARMONISÉ
  // -----------------------------------------------------------------
  Future<List<Property>> searchProperties(FiltreProprieteModel filtre) async {
    try {
      // Le filtre sur le status est la clé de la visibilité
      Query query = _db.collection(_propertyCollection)
          .where('status', whereIn: [PropertyStatus.disponible, PropertyStatus.booking]);

      // Filtres géographiques
      if (filtre.province != null && filtre.province != "Toutes") {
        query = query.where('province', isEqualTo: filtre.province);
      }
      if (filtre.ville != "Toutes" && filtre.ville != null) {
        query = query.where('ville', isEqualTo: (filtre.ville == "Autre") ? filtre.villeSpecifique : filtre.ville);
      }
      if (filtre.commune != "Toutes" && filtre.commune != null) {
        query = query.where('commune', isEqualTo: (filtre.commune == "Autre") ? filtre.communeSpecifique : filtre.commune);
      }

      // Filtres numériques
      if (filtre.maxPrice != null && filtre.maxPrice! > 0) {
        query = query.where('price', isLessThanOrEqualTo: filtre.maxPrice);
      }
      if (filtre.nbChambres != null) {
        if (filtre.nbChambres == 4) {
          query = query.where('nombreChambres', isGreaterThanOrEqualTo: 4);
        } else {
          query = query.where('nombreChambres', isEqualTo: filtre.nbChambres);
        }
      }
      if (filtre.garentieIdeale) {
        query = query.where('garantieMinimale', isLessThanOrEqualTo: 6);
      }

      // Filtres booléens (Equipements)
      if (filtre.hasCuisine) query = query.where('hasCuisine', isEqualTo: true);
      if (filtre.hasEau) query = query.where('hasEau', isEqualTo: true);
      if (filtre.hasElectricity) query = query.where('hasElectricity', isEqualTo: true);
      if (filtre.hasGarage) query = query.where('hasGarage', isEqualTo: true);
      if (filtre.hasToiletteParentale) query = query.where('hasToiletteParentale', isEqualTo: true);
      if (filtre.hasSalon) query = query.where('hasSalon', isEqualTo: true);
      if (filtre.hasCourRecreation) query = query.where('hasCourRecreation', isEqualTo: true);
      if (filtre.maisonEnEtage) query = query.where('maisonEnEtage', isEqualTo: true);
      if (filtre.hasDepot) query = query.where('hasDepot', isEqualTo: true);
      if (filtre.isEnclos) query = query.where('maisonEnclos', isEqualTo: true);
      if (filtre.accessibiliteVoiture) query = query.where('accessibiliteVoiture', isEqualTo: true);
      if (filtre.peuDeMenages) query = query.where('peuDeMenages', isEqualTo: true);
      if (filtre.bailleurAbsent) query = query.where('bailleurAbsent', isEqualTo: true);

      // 🔥 Tri par importance (sortIndex) puis par date
      // Note: Nécessite un index composite dans Firebase
      query = query.orderBy('sortIndex', descending: true)
                   .orderBy('publicationDate', descending: true);

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return [];

      final inputs = snapshot.docs
          .map((doc) => _ParsingInput(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      return await compute(_handleListParsing, inputs);

    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur searchProperties : $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
      return [];
    }
  }

  // -----------------------------------------------------------------
  // ✅ STREAM FILTRÉ POUR L'ACCUEIL
  // -----------------------------------------------------------------
  Stream<List<Property>> getAvailablePropertiesStream() {
    return _db.collection(_propertyCollection)
        .where('status', whereIn: [PropertyStatus.disponible, PropertyStatus.booking])
        .orderBy('sortIndex', descending: true) 
        .orderBy('publicationDate', descending: true) 
        .snapshots()
        .asyncMap((snapshot) async {
          final inputs = snapshot.docs.map((doc) => _ParsingInput(doc.data() as Map<String, dynamic>, doc.id)).toList();
          return await compute(_handleListParsing, inputs);
        });
  }

  // -----------------------------------------------------------------
  // ✅ GESTION DES RÉSERVATIONS ET VERROUS
  // -----------------------------------------------------------------
  Future<void> cleanExpiredReservations() async {
    try {
      final int maintenant = DateTime.now().millisecondsSinceEpoch;
      final int seuilExpiration = maintenant - (15 * 60 * 1000);

      final snapshot = await _db.collection(_propertyCollection)
          .where('status', isEqualTo: PropertyStatus.booking)
          .where('lockTimestamp', isLessThan: seuilExpiration)
          .get();

      if (snapshot.docs.isEmpty) return;

      WriteBatch batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': PropertyStatus.disponible,
          'lockTimestamp': FieldValue.delete(),
          'lockedBy': FieldValue.delete(),
        });
      }
      await batch.commit();
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  Future<void> verifierEtLibererVerrou(String propertyId, int localLockTimestamp) async {
    try {
      final DocumentReference propRef = _db.collection(_propertyCollection).doc(propertyId);
      await _db.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(propRef);
        if (snapshot.exists) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          if (data['status'] == PropertyStatus.booking && data['lockTimestamp'] == localLockTimestamp) {
            transaction.update(propRef, {
              'status': PropertyStatus.disponible,
              'lockTimestamp': FieldValue.delete(),
              'lockedBy': FieldValue.delete(),
            });
          }
        }
      });
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  Future<Map<String, dynamic>?> checkUserActiveReservation(String userId) async {
    try {
      final snapshot = await _db.collection(_propertyCollection)
          .where('lockedBy', isEqualTo: userId)
          .where('status', isEqualTo: PropertyStatus.booking)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final int? lockTimestamp = (doc.data() as Map<String, dynamic>)['lockTimestamp'];

        if (lockTimestamp != null) {
          final int maintenant = DateTime.now().millisecondsSinceEpoch;
          final int totalAllowedMs = 15 * 60 * 1000;
          final int tempsEcouleMs = maintenant - lockTimestamp;

          if (tempsEcouleMs < totalAllowedMs) {
            return {
              'propertyId': doc.id,
              'remainingSeconds': (totalAllowedMs - tempsEcouleMs) ~/ 1000,
            };
          }
        }
      }
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
    }
    return null;
  }

  Future<int> verrouillerTemporairement(String propertyId) async {
    final DocumentReference propRef = _db.collection(_propertyCollection).doc(propertyId);
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    final int timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      await _db.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(propRef);
        if (!snapshot.exists) throw Exception("Maison inexistante.");

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        String currentStatus = data['status'] ?? PropertyStatus.disponible;

        if (currentStatus != PropertyStatus.disponible) {
          throw Exception("Désolé, cette maison est déjà réservée.");
        }

        transaction.update(propRef, {
          'status': PropertyStatus.booking,
          'lockTimestamp': timestamp,
          'lockedBy': userId,
        });
      });
      return timestamp;
    } catch (e, stackTrace) {
      if (!e.toString().contains("déjà réservée")) await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow; 
    }
  }

  Future<void> reserverPropriete(FactureModel facture, String propertyId) async {
    await _runWriteWithRetry(() async {
      await _db.runTransaction((transaction) async {
        DocumentReference propRef = _db.collection(_propertyCollection).doc(propertyId);
        
        transaction.update(propRef, {
          'status': PropertyStatus.reserved,
          'lastLocataireId': facture.clientId,
          'reservedAt': FieldValue.serverTimestamp(),
          'lockTimestamp': FieldValue.delete(),
          'lockedBy': FieldValue.delete(),
        });

        DocumentReference factureRef = _db.collection('factures').doc();
        transaction.set(factureRef, {
          ...facture.toMap(),
          'id': factureRef.id,
          'createdAt': FieldValue.serverTimestamp(),
          'paymentStatus': 'completed',
        });
      });
    }, 'reserverPropriete');
  }

  // -----------------------------------------------------------------
  // 📂 CRÉATION PROPRIÉTÉ (Sécurisation des champs de tri)
  // -----------------------------------------------------------------
  Future<String> createProperty(Map<String, dynamic> preparedData) async {
    final newDocRef = _db.collection(_propertyCollection).doc();
    
    // 🔥 PROTECTION ULTIME : On s'assure que les champs de tri existent 
    // Même si SubmissionService a oublié de les mettre.
    preparedData['publicationDate'] = preparedData['publicationDate'] ?? FieldValue.serverTimestamp();
    preparedData['createdAt'] = preparedData['createdAt'] ?? FieldValue.serverTimestamp();
    preparedData['sortIndex'] = preparedData['sortIndex'] ?? 0;
    preparedData['status'] = preparedData['status'] ?? PropertyStatus.disponible;
    preparedData['estLouee'] = preparedData['estLouee'] ?? false;

    try {
      await _runWriteWithRetry(() => newDocRef.set(preparedData), 'createProperty');
      return newDocRef.id;
    } catch (e) {
      throw Exception("Impossible de créer la propriété : $e");
    }
  }

  // -----------------------------------------------------------------
  // 🛠 MÉCANISME DE RÉSILIENCE (RETRY)
  // -----------------------------------------------------------------
  Future<void> _runWriteWithRetry(Future<void> Function() action, String context) async {
    int maxRetries = 3;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await action();
      } catch (e) {
        if (attempt == maxRetries - 1) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
  }

  Future<List<Property>> getBailleurProperties(String bailleurId) async {
    final snapshot = await _db.collection(_propertyCollection).where('bailleurId', isEqualTo: bailleurId).get();
    final inputs = snapshot.docs.map((doc) => _ParsingInput(doc.data() as Map<String, dynamic>, doc.id)).toList();
    return await compute(_handleListParsing, inputs);
  }
}
