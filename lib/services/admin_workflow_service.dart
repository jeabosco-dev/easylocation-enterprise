import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:easylocation_mvp/models/formulaire_publication_model.dart';
import 'package:flutter/foundation.dart'; // Pour debugPrint

class AdminWorkflowService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- SYSTÈME DE COMPTAGE POUR LES BADGES (OPTIMISÉ & CORRIGÉ) ---
  Future<Map<String, int>> getAllCounts() async {
    final coll = _db.collection(FirestoreCollections.properties);

    try {
      final results = await Future.wait([
        coll.where('hasPriorityRequest', isEqualTo: true)
            .where(FirestoreFields.isVerified, isEqualTo: false)
            .where(FirestoreFields.status, isNotEqualTo: PropertyStatus.rejected)
            .count().get(),
            
        coll.where(FirestoreFields.isVerified, isEqualTo: false)
            .where(FirestoreFields.status, isNotEqualTo: PropertyStatus.rejected)
            .count().get(),
            
        coll.where(FirestoreFields.isVerified, isEqualTo: true)
            .where(FirestoreFields.status, isEqualTo: PropertyStatus.disponible)
            .count().get(),
            
        coll.where(FirestoreFields.status, isEqualTo: PropertyStatus.enAttentePaiement)
            .count().get(),
            
        coll.where(FirestoreFields.status, isEqualTo: PropertyStatus.remiseCles)
            .count().get(),
            
        coll.where(FirestoreFields.status, isEqualTo: PropertyStatus.rejected)
            .count().get(),
      ]);

      return {
        'urgents': results[0].count ?? 0,
        'certifications': results[1].count ?? 0,
        'enLigne': results[2].count ?? 0,
        'paiements': results[3].count ?? 0,
        'cles': results[4].count ?? 0,
        'archives': results[5].count ?? 0,
      };
    } catch (e) {
      debugPrint("ALERTE COMPTAGE : Erreur AggregateQuery : $e");
      return {'urgents': 0, 'certifications': 0, 'enLigne': 0, 'paiements': 0, 'cles': 0, 'archives': 0};
    }
  }

  // 1. CAPTURER UN DOSSIER
  Future<void> captureProperty({
    required String propertyId,
    required String adminId,
    required String adminName,
    required Map<String, dynamic> fullData,
  }) async {
    final docRef = _db.collection(FirestoreCollections.properties).doc(propertyId);
    final logRef = _db.collection(FirestoreCollections.adminLogs).doc();

    return _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw "Le document n'existe plus.";

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      String? currentAdmin = data[FirestoreFields.assignedAdminId];

      if (currentAdmin != null && currentAdmin.isNotEmpty && currentAdmin != adminId) {
        throw "Ce dossier est déjà traité par ${data[FirestoreFields.assignedAdminName]}.";
      }

      transaction.update(docRef, {
        FirestoreFields.processingStatus: WorkflowStatus.ongoing,
        FirestoreFields.assignedAdminId: adminId,
        FirestoreFields.assignedAdminName: adminName,
        FirestoreFields.takenAt: FieldValue.serverTimestamp(),
        FirestoreFields.lastUpdateBy: adminId,
      });

      transaction.set(logRef, _generateLogMap(
        action: "CAPTURE",
        adminId: adminId,
        adminName: adminName,
        propertyId: propertyId,
        data: data,
      ));
    });
  }

  // 2. LIBÉRER UN DOSSIER
  Future<void> releaseProperty({
    required String propertyId,
    required String adminId,
    required String adminName,
    required Map<String, dynamic> fullData,
  }) async {
    final docRef = _db.collection(FirestoreCollections.properties).doc(propertyId);
    final logRef = _db.collection(FirestoreCollections.adminLogs).doc();

    return _db.runTransaction((transaction) async {
      transaction.update(docRef, {
        FirestoreFields.processingStatus: WorkflowStatus.jachere,
        FirestoreFields.assignedAdminId: null,
        FirestoreFields.assignedAdminName: null,
        FirestoreFields.takenAt: null,
        FirestoreFields.lastUpdateBy: adminId,
      });

      transaction.set(logRef, _generateLogMap(
        action: "LIBERATION",
        adminId: adminId,
        adminName: adminName,
        propertyId: propertyId,
        data: fullData,
      ));
    });
  }

  // 3. ACTION SÉCURISÉE (Générique) - MODIFIÉE POUR ACCEPTER UNE COLLECTION
  Future<void> executeSecureAction({
    required String propertyId,
    required Map<String, dynamic> updateData,
    required String actionType,
    required String adminId,
    required String adminName,
    required Map<String, dynamic> fullPropertyData,
    String customCollection = FirestoreCollections.properties, // ✅ Ajouté ici
    String details = "",
  }) async {
    final batch = _db.batch();
    
    // ✅ Utilise maintenant la collection spécifiée (factures ou properties)
    final propRef = _db.collection(customCollection).doc(propertyId);
    final logRef = _db.collection(FirestoreCollections.adminLogs).doc();

    batch.update(propRef, {
      ...updateData,
      FirestoreFields.lastUpdateBy: adminId,
    });

    batch.set(logRef, _generateLogMap(
      action: actionType,
      adminId: adminId,
      adminName: adminName,
      propertyId: propertyId,
      data: fullPropertyData,
      details: details,
    ));

    return batch.commit();
  }

  // --- HELPER : GÉNÉRATEUR DE LOGS ---
  Map<String, dynamic> _generateLogMap({
    required String action,
    required String adminId,
    required String adminName,
    required String propertyId,
    required Map<String, dynamic> data,
    String details = "",
  }) {
    try {
      // Pour les factures, on essaie de récupérer la ref, sinon on met une valeur par défaut
      String reference = data[FactureFields.refMaison] ?? "N/A";
      
      double price = 0;
      if (data[FirestoreFields.price] != null) {
        price = double.tryParse(data[FirestoreFields.price].toString()) ?? 0;
      } else if (data[FactureFields.totalUSD] != null) {
        price = double.tryParse(data[FactureFields.totalUSD].toString()) ?? 0;
      }

      return {
        'actionType': action,
        'adminId': adminId,
        'adminName': adminName,
        'propertyId': propertyId,
        'propertyRef': reference,
        'propertyName': data[FirestoreFields.typeBien] ?? "Document Workflow",
        'amount': price,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
      };
    } catch (e) {
      return {
        'actionType': action,
        'adminId': adminId,
        'timestamp': FieldValue.serverTimestamp(),
        'details': "Erreur parsing log: $e",
      };
    }
  }
}