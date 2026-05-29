// lib/services/admin_workflow_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:easylocation_mvp/models/formulaire_publication_model.dart';
import 'package:flutter/foundation.dart'; // Pour debugPrint

class AdminWorkflowService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- SYSTÈME DE COMPTAGE POUR LES BADGES (MIS À JOUR ET SÉCURISÉ) ---
  Future<Map<String, int>> getAllCounts({String? adminId}) async { 
    final collProperties = _db.collection(FirestoreCollections.properties);
    final collFactures = _db.collection(FirestoreCollections.factures);

    // Fonction interne sécurisée pour exécuter chaque comptage individuellement
    Future<int> safeCount(Query query) async {
      try {
        final snapshot = await query.count().get();
        return snapshot.count ?? 0;
      } catch (e) {
        debugPrint("⚠️ Erreur de droits/permissions étouffée sur une sous-requête : $e");
        return 0; // Renvoie 0 au lieu de faire planter le Future.wait et Sentry
      }
    }

    try {
      final results = await Future.wait([
        // 0. Urgents
        safeCount(
          collProperties.where('hasPriorityRequest', isEqualTo: true)
              .where(FirestoreFields.isVerified, isEqualTo: false)
              .where(FirestoreFields.status, isNotEqualTo: PropertyStatus.rejected)
        ),
            
        // 1. Certifications
        safeCount(
          collProperties.where(FirestoreFields.isVerified, isEqualTo: false)
              .where(FirestoreFields.status, isNotEqualTo: PropertyStatus.rejected)
        ),
            
        // 2. En Ligne
        safeCount(
          collProperties.where(FirestoreFields.isVerified, isEqualTo: true)
              .where(FirestoreFields.status, isEqualTo: PropertyStatus.disponible)
        ),
            
        // 3. PAIEMENTS MOMO (Filtre strict : pas de cash)
        (adminId != null) 
            ? safeCount(
                collFactures
                    .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPending)
                    .where(FactureFields.methodePaiement, isNotEqualTo: 'cash')
                    // ✅ ALIGNÉ : Remplacement de 'agentId' par la constante FactureFields.agentTerrainId
                    .where(FactureFields.agentTerrainId, isEqualTo: adminId)
              )
            : safeCount(
                collFactures
                    .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPending)
                    .where(FactureFields.methodePaiement, isNotEqualTo: 'cash')
              ),

        // 4. PAIEMENTS CASH (Filtre strict : uniquement cash)
        (adminId != null) 
            ? safeCount(
                collFactures
                    .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPending)
                    .where(FactureFields.methodePaiement, isEqualTo: 'cash')
                    // ✅ ALIGNÉ : Remplacement de 'agentId' par la constante FactureFields.agentTerrainId
                    .where(FactureFields.agentTerrainId, isEqualTo: adminId)
              )
            : safeCount(
                collFactures
                    .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPending)
                    .where(FactureFields.methodePaiement, isEqualTo: 'cash')
              ),
            
        // 5. CLÉS
        (adminId != null)
            ? safeCount(
                collFactures
                    .where(FactureFields.paymentStatus, whereIn: const [FactureFields.statusPaid, 'success'])
                    .where(FirestoreFields.assignedAdminId, isEqualTo: adminId)
                    .where(FactureFields.etapeDossier, isNotEqualTo: FactureFields.etapeCloture)
              )
            : safeCount(
                collProperties.where(FirestoreFields.status, isEqualTo: PropertyStatus.remiseCles)
              ),
            
        // 6. Archives
        safeCount(
          collProperties.where(FirestoreFields.status, isEqualTo: PropertyStatus.rejected)
        ),

        // 7. Attribution Paiements
        safeCount(
          collFactures.where(FactureFields.etapeDossier, isEqualTo: 'paye') // ✅ NETTOYÉ : Remplacement de 'statut'/'payee' par les constantes standardisées
              .where(FirestoreFields.assignedAdminId, isNull: true)
        ),

        // 8. BIENS LOUÉS
        safeCount(
          collProperties.where(FirestoreFields.isVerified, isEqualTo: true)
              .where(FirestoreFields.status, whereIn: const ['rented', 'occupied'])
        ),
      ]);

      return {
        'urgents': results[0],
        'certifications': results[1],
        'enLigne': results[2],
        'paiementsMoMo': results[3], 
        'paiementsCash': results[4], 
        'cles': AntiquatedValuesSafeCheck(results, 5),
        'archives': results[6],
        'attribution': results[7],
        'loues': results[8],
      };
    } catch (e) {
      debugPrint("ALERTE COMPTAGE CRITIQUE : Erreur globale AggregateQuery : $e");
      return {
        'urgents': 0,
        'certifications': 0,
        'enLigne': 0,
        'paiementsMoMo': 0,
        'paiementsCash': 0,
        'cles': 0,
        'archives': 0,
        'attribution': 0,
        'loues': 0,
      };
    }
  }

  // Petit Helper de sécurité d'index
  int AntiquatedValuesSafeCheck(List<int> list, int index) {
    if (index >= list.length) return 0;
    return list[index];
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

  // 3. ACTION SÉCURISÉE (Générique & Multi-documents)
  Future<void> executeSecureAction({
    required String propertyId,
    required Map<String, dynamic> updateData,
    required String actionType,
    required String adminId,
    required String adminName,
    required Map<String, dynamic> fullPropertyData,
    String customCollection = FirestoreCollections.properties,
    String? factureId, 
    String details = "",
  }) async {
    final batch = _db.batch();
    final logRef = _db.collection(FirestoreCollections.adminLogs).doc();

    final Map<String, dynamic> finalUpdates = {
      ...updateData,
      FirestoreFields.lastUpdateBy: adminId,
    };

    if (factureId != null && factureId.isNotEmpty) {
      final factureRef = _db.collection(FirestoreCollections.factures).doc(factureId);
      batch.update(factureRef, finalUpdates);

      if (propertyId.isNotEmpty) {
        final propRef = _db.collection(FirestoreCollections.properties).doc(propertyId);
        batch.update(propRef, finalUpdates);
      }
    } else {
      final targetRef = _db.collection(customCollection).doc(propertyId);
      batch.update(targetRef, finalUpdates);
    }

    batch.set(logRef, _generateLogMap(
      action: actionType,
      adminId: adminId,
      adminName: adminName,
      propertyId: propertyId.isNotEmpty ? propertyId : (factureId ?? ''),
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