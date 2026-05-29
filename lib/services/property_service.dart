// lib/services/property_service.dart

import 'dart:async'; 
import 'dart:math'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; 

// ✅ Imports des modèles et constantes
import 'package:easylocation_mvp/models/property_model.dart' hide PropertyStatus;
import 'package:easylocation_mvp/models/filtre_propriete_model.dart'; 
import 'package:easylocation_mvp/models/facture_model.dart'; 
import 'package:easylocation_mvp/models/stats_localite_model.dart'; 
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

// Intercepte le parsing global pour trier et nettoyer les critères complexes en mémoire
List<Property> _handleListParsing(List<_ParsingInput> inputs) {
  return inputs.map((e) => Property.fromMap(e.data, e.id)).toList();
}

// ====================================================================
// CLASSE PRINCIPALE DU SERVICE
// ====================================================================

class PropertyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; 
  final String _propertyCollection = FirestoreCollections.properties; 

  FirebaseFirestore get db => _db;

  // -----------------------------------------------------------------
  // 🛠 UTILITAIRES DE FORMATAGE (SLUGIFY)
  // -----------------------------------------------------------------

  String _slugify(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'\s+'), '') 
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  // -----------------------------------------------------------------
  // ✅ GESTION DES COMPTEURS DISTRIBUÉS
  // -----------------------------------------------------------------

  Future<void> incrementViewOptimized(String propertyId) async {
    try {
      const int numberOfShards = 20;
      int shardId = Random().nextInt(numberOfShards);
      
      DocumentReference shardRef = _db
          .collection(_propertyCollection)
          .doc(propertyId)
          .collection('shards')
          .doc(shardId.toString());

      return shardRef.set(
        {'count': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur incrementViewOptimized: $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  Stream<int> getDistributedCount(String propertyId) {
    return _db
        .collection(_propertyCollection)
        .doc(propertyId)
        .collection('shards')
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['count'] as num?)?.toInt() ?? 0;
      }
      return total;
    });
  }

  // -----------------------------------------------------------------
  // ✅ GESTION DES STATISTIQUES DE LOCALITÉ (URGENCY BANNER)
  // -----------------------------------------------------------------

  Future<StatsLocaliteModel?> getLocaliteStats({
    required String province,
    required String ville,
    required String commune,
    required String quartier,
  }) async {
    try {
      final String baseId = "rdc_${_slugify(province)}_${_slugify(ville)}";
      final String statsId = "${baseId}_${_slugify(commune)}_${_slugify(quartier)}";
      
      var doc = await _db.collection('stats_localites').doc(statsId).get();

      if (!doc.exists) {
        String fallbackId = "${baseId}_${_slugify(commune)}";
        doc = await _db.collection('stats_localites').doc(fallbackId).get();
      }

      if (doc.exists && doc.data() != null) {
        return StatsLocaliteModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur getLocaliteStats: $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
    }
    return null;
  }

  // -----------------------------------------------------------------
  // ✅ WORKFLOW TERRAIN (AUTOMATISATION DES STATS)
  // -----------------------------------------------------------------

  Future<void> finaliserRemiseCles(Property property, String agentTerrainId) async {
    final DateTime maintenant = DateTime.now();
    final int dureeHeures = maintenant.difference(property.createdAt).inHours;

    final String baseId = "rdc_${_slugify(property.province)}_${_slugify(property.ville)}";
    final String idQuartier = "${baseId}_${_slugify(property.commune)}_${_slugify(property.quartier)}";
    final String idCommune = "${baseId}_${_slugify(property.commune)}";

    try {
      await _db.runTransaction((transaction) async {
        DocumentReference propRef = _db.collection(_propertyCollection).doc(property.id);
        DocumentReference contractRef = _db.collection('contracts').doc();

        transaction.update(propRef, {
          FirestoreFields.status: PropertyStatus.rented,
          'estLouee': true,
          'lastUpdateBy': agentTerrainId,
          'rentedAt': Timestamp.fromDate(maintenant),
          'processingStatus': 'completed',
        });

        // 🎯 NETTOYAGE PUR : Enregistrement du contrat avec la clé unifiée sans dette technique
        transaction.set(contractRef, {
          'propertyId': property.id,
          'locataireId': property.lastLocataireId,
          'bailleurId': property.bailleurId,
          FactureFields.agentTerrainId: agentTerrainId, // ✅ MODIFIÉ : Clé unifiée et sécurisée
          'dateSignature': Timestamp.fromDate(maintenant),
          'montantLoyer': property.price,
          'statut': 'actif',
          'referenceContrat': "CTR-${property.referenceCourte}-${maintenant.millisecondsSinceEpoch.toString().substring(10)}",
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _updateZoneStatsInTransaction(transaction, idQuartier, dureeHeures);
        await _updateZoneStatsInTransaction(transaction, idCommune, dureeHeures);
      });
      debugPrint("✅ Workflow complet terminé.");
    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur lors de la finalisation du bail : $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _updateZoneStatsInTransaction(Transaction transaction, String docId, int nouvelleDuree) async {
    DocumentReference statRef = _db.collection('stats_localites').doc(docId);
    DocumentSnapshot statSnap = await transaction.get(statRef);

  if (statSnap.exists) {
      Map<String, dynamic> data = statSnap.data() as Map<String, dynamic>;
      int currentTotal = data['total_rented'] ?? 0;
      int currentAvg = data['avg_hours'] ?? 0;

      int newTotal = currentTotal + 1;
      int newAvg = ((currentAvg * currentTotal) + nouvelleDuree) ~/ newTotal;

      transaction.update(statRef, {
        'avg_hours': newAvg,
        'total_rented': newTotal,
        'last_update': FieldValue.serverTimestamp(),
      });
    } else {
      transaction.set(statRef, {
        'avg_hours': nouvelleDuree,
        'total_rented': 1,
        'last_update': FieldValue.serverTimestamp(),
      });
    }
  }

  // -----------------------------------------------------------------
  // ✅ ACTIONS DE GESTION (PRIX, PHOTOS)
  // -----------------------------------------------------------------

  Future<void> updatePrice(String propertyId, double newPrice) async {
    try {
      await _db.collection(_propertyCollection).doc(propertyId).update({
        'price': newPrice,
        'lastUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> addPhoto(String propertyId, String downloadUrl) async {
    try {
      await _db.collection(_propertyCollection).doc(propertyId).update({
        'imageUrls': FieldValue.arrayUnion([downloadUrl]),
        'lastUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> removePhoto(String propertyId, String url) async {
    try {
      await _db.collection(_propertyCollection).doc(propertyId).update({
        'imageUrls': FieldValue.arrayRemove([url]),
      });
      try {
        await _storage.refFromURL(url).delete();
      } catch (e) {
        debugPrint("⚠️ Note: Fichier Storage déjà supprimé.");
      }
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // -----------------------------------------------------------------
  // 🔥 RECHERCHE ET STREAMS (MODE PREUVE SOCIALE)
  // -----------------------------------------------------------------
  
  Future<List<Property>> searchProperties(FiltreProprieteModel filtre) async {
    try {
      Query query = _db.collection(_propertyCollection);

      if (filtre.queryReference != null && filtre.queryReference!.trim().isNotEmpty) {
        query = query.where('id', isEqualTo: filtre.queryReference!.trim().toUpperCase());
      } 
      else {
        // ✅ STRATÉGIE DE PREUVE SOCIALE : On inclut TOUS les états intermédiaires et finaux visibles.
        query = query.where(FirestoreFields.status, whereIn: [
          PropertyStatus.disponible, 
          PropertyStatus.booking,
          PropertyStatus.enAttentePaiement,
          PropertyStatus.reserved,
          PropertyStatus.rented, 
        ]);

        if (filtre.typeBien != null && filtre.typeBien != "Tous" && filtre.typeBien != "Toutes" && filtre.typeBien!.isNotEmpty) {
          query = query.where('typeBien', isEqualTo: filtre.typeBien);
        }
        if (filtre.province != null && filtre.province != "Toutes") {
          query = query.where('province', isEqualTo: filtre.province);
        }
        if (filtre.ville != "Toutes" && filtre.ville != null) {
          query = query.where('ville', isEqualTo: (filtre.ville == "Autre") ? filtre.villeSpecifique : filtre.ville);
        }
        if (filtre.commune != "Toutes" && filtre.commune != null) {
          query = query.where('commune', isEqualTo: (filtre.commune == "Autre") ? filtre.communeSpecifique : filtre.commune);
        }

        // 💡 Note de performance : Pour éviter l'obligation d'index complexes croisés entre le 'whereIn' des statuts 
        // et les inégalités (<, >, <=), les requêtes numériques et booléennes fines sont appliquées en mémoire.
        if (filtre.nbChambres != null && filtre.nbChambres! < 4) {
          query = query.where('nombreChambres', isEqualTo: filtre.nbChambres);
        }
        if (filtre.hasCuisine) query = query.where('hasCuisine', isEqualTo: true);
        if (filtre.hasSalon) query = query.where('hasSalon', isEqualTo: true);
        if (filtre.hasToiletteParentale) query = query.where('hasToiletteParentale', isEqualTo: true);
        if (filtre.maisonEnEtage) query = query.where('maisonEnEtage', isEqualTo: true);
        if (filtre.isEnclos) query = query.where('maisonEnclos', isEqualTo: true);
        if (filtre.bailleurAbsent) query = query.where('bailleurHabiteAvec', isEqualTo: false);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return [];

      final inputs = snapshot.docs
          .map((doc) => _ParsingInput(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Exécution lourde déportée dans l'isolat pour garder les 60 FPS fluides
      List<Property> properties = await compute(_handleListParsing, inputs);

      // ✅ FILTRAGE FIN EN MÉMOIRE (Résout les limites d'indexation complexes de Firestore)
      properties = properties.where((p) {
        if (filtre.maxPrice != null && filtre.maxPrice! > 0 && p.price > filtre.maxPrice!) return false;
        if (filtre.nbChambres == 4 && p.nombreChambres < 4) return false;
        if (filtre.garentieIdeale && p.garantieMinimale > 6) return false;
        if (filtre.hasEau && !p.hasEau) return false;
        if (filtre.hasGarage && !p.hasGarage) return false;
        if (filtre.hasCourRecreation && !p.hasCourRecreation) return false;
        if (filtre.hasDepot && !p.hasDepot) return false;
        if (filtre.accessibiliteVoiture && !p.accessibiliteVoiture) return false;
        if (filtre.peuDeMenages && (p.nombreMenages ?? 0) > 2) return false; // 💡 Corrigé ici (Null Safety)
        return true;
      }).toList();

      // Tri par pertinence (index de boost admin) puis par nouveauté
      properties.sort((a, b) {
        int cmp = (b.sortIndex).compareTo(a.sortIndex);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });

      return properties;

    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur searchProperties : $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
      return [];
    }
  }

  Stream<List<Property>> getAvailablePropertiesStream() {
    return _db.collection(_propertyCollection)
        .where(FirestoreFields.status, whereIn: [
          PropertyStatus.disponible, 
          PropertyStatus.booking,
          PropertyStatus.enAttentePaiement,
          PropertyStatus.reserved,
          PropertyStatus.rented 
        ])
        .snapshots()
        .asyncMap((snapshot) async {
          final inputs = snapshot.docs.map((doc) => _ParsingInput(doc.data() as Map<String, dynamic>, doc.id)).toList();
          List<Property> list = await compute(_handleListParsing, inputs);
          
          list.sort((a, b) {
            int cmp = (b.sortIndex).compareTo(a.sortIndex);
            if (cmp != 0) return cmp;
            return b.createdAt.compareTo(a.createdAt);
          });
          return list;
        });
  }

  // -----------------------------------------------------------------
  // ✅ GESTION DU NETTOYAGE ET VÉRIFICATIONS
  // -----------------------------------------------------------------
  
  Future<void> cleanExpiredReservations() async {
    try {
      final int maintenant = DateTime.now().millisecondsSinceEpoch;
      final int seuilExpiration = maintenant - (10 * 60 * 1000);

      final snapshot = await _db.collection(_propertyCollection)
          .where(FirestoreFields.status, isEqualTo: PropertyStatus.booking)
          .where('lockTimestamp', isLessThan: seuilExpiration)
          .get();

      if (snapshot.docs.isEmpty) return;

      WriteBatch batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          FirestoreFields.status: PropertyStatus.disponible,
          'lockTimestamp': FieldValue.delete(),
          'lockedBy': FieldValue.delete(),
        });
      }
      await batch.commit();
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  Future<void> cleanOldRentedProperties() async {
    try {
      final DateTime maintenant = DateTime.now();
      // On garde affiché le bien loué pendant 24h pour capitaliser au maximum sur la preuve sociale !
      final DateTime seuilExpiration = maintenant.subtract(const Duration(hours: 24));

      final snapshot = await _db.collection(_propertyCollection)
          .where(FirestoreFields.status, isEqualTo: PropertyStatus.rented)
          .where('rentedAt', isLessThan: Timestamp.fromDate(seuilExpiration))
          .get();

      if (snapshot.docs.isEmpty) return;

      WriteBatch batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          FirestoreFields.status: 'archived',
          'isVisible': false,
        });
      }
      await batch.commit();
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  Future<void> verifierEtLibererSiNonPaye(String propertyId, int localLockTimestamp, String factureId) async {
    try {
      DocumentSnapshot factureDoc = await _db.collection('factures').doc(factureId).get();
      if (factureDoc.exists) {
        String status = (factureDoc.data() as Map<String, dynamic>)['paymentStatus'] ?? 'pending';
        if (status == 'completed' || status == 'success' || status == 'paid') return; 
      }
      await verifierEtLibererVerrou(propertyId, localLockTimestamp);
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
          if (data[FirestoreFields.status] == PropertyStatus.booking && data['lockTimestamp'] == localLockTimestamp) {
            transaction.update(propRef, {
              FirestoreFields.status: PropertyStatus.disponible,
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
          .where(FirestoreFields.status, isEqualTo: PropertyStatus.booking)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final int? lockTimestamp = (doc.data() as Map<String, dynamic>)['lockTimestamp'];

        if (lockTimestamp != null) {
          final int maintenant = DateTime.now().millisecondsSinceEpoch;
          final int totalAllowedMs = 10 * 60 * 1000;
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

  Future<int> verrouillerTemporairement(String propertyId, String clientId) async {
    final DocumentReference propRef = _db.collection(_propertyCollection).doc(propertyId);
    final int timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      await _db.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(propRef);
        if (!snapshot.exists) throw Exception("Bien inexistant.");

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        String currentStatus = data[FirestoreFields.status] ?? PropertyStatus.disponible;
        String? lockedBy = data['lockedBy'];

        if (currentStatus == PropertyStatus.booking && lockedBy != clientId) {
          throw Exception("Ce bien est en cours de réservation par un autre client.");
        }
        if (currentStatus == PropertyStatus.enAttentePaiement || currentStatus == PropertyStatus.reserved || currentStatus == PropertyStatus.rented) {
          throw Exception("Ce bien n'est plus disponible.");
        }

        transaction.update(propRef, {
          FirestoreFields.status: PropertyStatus.booking,
          'lockTimestamp': timestamp,
          'lockedBy': clientId,
        });
      });
      return timestamp;
    } catch (e, stackTrace) {
      if (!e.toString().contains("réservation") && !e.toString().contains("disponible")) {
        await Sentry.captureException(e, stackTrace: stackTrace);
      }
      rethrow; 
    }
  }

  Future<void> reserverPropriete(FactureModel facture, String propertyId) async {
    await runWriteWithRetry(() async {
      await _db.runTransaction((transaction) async {
        DocumentReference propRef = _db.collection(_propertyCollection).doc(propertyId);
        
        transaction.update(propRef, {
          FirestoreFields.status: PropertyStatus.reserved,
          'lastLocataireId': facture.clientId,
          'reservedAt': FieldValue.serverTimestamp(),
          'lockTimestamp': FieldValue.delete(),
          'lockedBy': FieldValue.delete(),
        });

        DocumentReference factureRef = _db.collection('factures').doc(facture.id);
        transaction.set(factureRef, {
          ...facture.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'paymentStatus': 'completed',
        });
      });
    }, 'reserverPropriete');
  }

  Future<void> demanderVerification({
    required String propertyId,
    required String reference,
    required String clientName,
    required String clientPhone,
    required String clientId,
  }) async {
    try {
      await _db.collection(_propertyCollection).doc(propertyId).update({
        FirestoreFields.hasPriorityRequest: true, 
        FirestoreFields.priorityRequestAt: FieldValue.serverTimestamp(),
        'lastUpdateBy': clientId, 
        'priorityRequesterName': clientName,
        'priorityRequesterPhone': clientPhone,
        'priorityStatus': 'en_attente', 
      });
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow; 
    }
  }

  Future<void> certifierPropriete(String propertyId, bool status) async {
    try {
      Map<String, dynamic> updates = {
        FirestoreFields.isVerified: status, 
        'verifiedAt': FieldValue.serverTimestamp(),
      };

      if (status == true) {
        updates[FirestoreFields.hasPriorityRequest] = false;
        updates['priorityStatus'] = 'complete';
      }

      await _db.collection(_propertyCollection).doc(propertyId).update(updates);
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> runWriteWithRetry(Future<void> Function() action, String context) async {
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