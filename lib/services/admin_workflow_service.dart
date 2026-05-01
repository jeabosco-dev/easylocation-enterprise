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
      // Utilisation de Future.wait pour lancer les 6 requêtes en simultané
      final results = await Future.wait([
        // 1. URGENTS (CORRIGÉ : On filtre uniquement les non-vérifiés)
        coll.where('hasPriorityRequest', isEqualTo: true)
            .where(FirestoreFields.isVerified, isEqualTo: false) // S'assure que le compteur tombe à 0 après certification
            .where(FirestoreFields.status, isNotEqualTo: PropertyStatus.rejected)
            .count().get(),
            
        // 2. CERTIFICATIONS PENDING 
        coll.where(FirestoreFields.isVerified, isEqualTo: false)
            .where(FirestoreFields.status, isNotEqualTo: PropertyStatus.rejected)
            .count().get(),
            
        // 3. BIENS EN LIGNE (DISPONIBLES)
        coll.where(FirestoreFields.isVerified, isEqualTo: true)
            .where(FirestoreFields.status, isEqualTo: PropertyStatus.disponible)
            .count().get(),
            
        // 4. PAIEMENTS
        coll.where(FirestoreFields.status, isEqualTo: PropertyStatus.enAttentePaiement)
            .count().get(),
            
        // 5. REMISE DES CLÉS
        coll.where(FirestoreFields.status, isEqualTo: PropertyStatus.remiseCles)
            .count().get(),
            
        // 6. ARCHIVES & REJETS
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
      debugPrint("ALERTE COMPTAGE : Erreur AggregateQuery. Vérifiez les index Firebase : $e");
      
      return {
        'urgents': 0, 'certifications': 0, 'enLigne': 0, 
        'paiements': 0, 'cles': 0, 'archives': 0
      };
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

  // 3. ACTION SÉCURISÉE (Générique)
  Future<void> executeSecureAction({
    required String propertyId,
    required Map<String, dynamic> updateData,
    required String actionType,
    required String adminId,
    required String adminName,
    required Map<String, dynamic> fullPropertyData,
    String details = "",
  }) async {
    final batch = _db.batch();
    final propRef = _db.collection(FirestoreCollections.properties).doc(propertyId);
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
      final model = FormulairePublicationModel.fromFirestore(data, propertyId);
      
      double price = 0;
      if (data[FirestoreFields.price] != null) {
        price = double.tryParse(data[FirestoreFields.price].toString()) ?? 0;
      }

      return {
        'actionType': action,
        'adminId': adminId,
        'adminName': adminName,
        'propertyId': propertyId,
        'propertyRef': model.referenceUnique,
        'propertyName': data[FirestoreFields.typeBien] ?? "Bien inconnu",
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