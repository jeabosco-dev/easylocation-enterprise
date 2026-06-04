// lib/services/property_service.dart

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// ✅ Imports des modèles et constantes
import 'package:easylocation_mvp/models/property_model.dart' hide PropertyStatus;
import 'package:easylocation_mvp/models/filtre_propriete_model.dart';
import 'package:easylocation_mvp/models/facture_model.dart';
import 'package:easylocation_mvp/models/stats_localite_model.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

// ✅ Import des extensions
part 'property_service_stats.dart';
part 'property_service_search.dart';
part 'property_service_reservation.dart';

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
// CLASSE PRINCIPALE DU SERVICE (NOYAU)
// ====================================================================

class PropertyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _propertyCollection = FirestoreCollections.properties;

  FirebaseFirestore get db => _db;
  FirebaseStorage get storage => _storage;
  String get propertyCollection => _propertyCollection;

  // -----------------------------------------------------------------
  // 🛠 UTILITAIRES DE BASE (COMMUNS)
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

  // -----------------------------------------------------------------
  // ✅ MÉTHODES AJOUTÉES POUR CORRIGER LES ERREURS (MANQUANTES)
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

  Future<void> addPhoto(String propertyId, String url) async {
    try {
      await _db.collection(_propertyCollection).doc(propertyId).update({
        'imageUrls': FieldValue.arrayUnion([url]),
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
        debugPrint("⚠️ Note: Fichier Storage déjà supprimé ou introuvable.");
      }
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
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
}