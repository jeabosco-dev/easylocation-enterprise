part of 'property_service.dart';

extension PropertyServiceReservation on PropertyService {
  
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
      await db.runTransaction((transaction) async {
        DocumentReference propRef = db.collection(propertyCollection).doc(property.id);
        DocumentReference contractRef = db.collection('contracts').doc();

        transaction.update(propRef, {
          FirestoreFields.status: PropertyStatus.rented,
          'estLouee': true,
          'lastUpdateBy': agentTerrainId,
          'rentedAt': Timestamp.fromDate(maintenant),
          'processingStatus': 'completed',
        });

        transaction.set(contractRef, {
          'propertyId': property.id,
          'locataireId': property.lastLocataireId,
          'bailleurId': property.bailleurId,
          FactureFields.agentTerrainId: agentTerrainId,
          'dateSignature': Timestamp.fromDate(maintenant),
          'montantLoyer': property.price,
          'statut': 'actif',
          'referenceContrat': "CTR-${property.referenceCourte}-${maintenant.millisecondsSinceEpoch.toString().substring(10)}",
          'createdAt': FieldValue.serverTimestamp(),
        });

        await updateZoneStatsInTransaction(transaction, idQuartier, dureeHeures);
        await updateZoneStatsInTransaction(transaction, idCommune, dureeHeures);
      });
      debugPrint("✅ Workflow complet terminé.");
    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur lors de la finalisation du bail : $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // -----------------------------------------------------------------
  // ✅ GESTION DES RÉSERVATIONS ET VERROUILLAGE
  // -----------------------------------------------------------------

  Future<void> cleanExpiredReservations() async {
    try {
      final int maintenant = DateTime.now().millisecondsSinceEpoch;
      final int seuilExpiration = maintenant - (10 * 60 * 1000); // 10 minutes

      final snapshot = await db.collection(propertyCollection)
          .where(FirestoreFields.status, isEqualTo: PropertyStatus.booking)
          .where('lockTimestamp', isLessThan: seuilExpiration)
          .get();

      if (snapshot.docs.isEmpty) return;

      WriteBatch batch = db.batch();
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
      final DateTime seuilExpiration = DateTime.now().subtract(const Duration(hours: 24));
      
      final snapshot = await db.collection(propertyCollection)
          .where(FirestoreFields.status, isEqualTo: PropertyStatus.rented)
          .where('rentedAt', isLessThan: Timestamp.fromDate(seuilExpiration))
          .get();

      if (snapshot.docs.isEmpty) return;

      WriteBatch batch = db.batch();
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
      DocumentSnapshot factureDoc = await db.collection('factures').doc(factureId).get();
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
      final DocumentReference propRef = db.collection(propertyCollection).doc(propertyId);
      await db.runTransaction((transaction) async {
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
      final snapshot = await db.collection(propertyCollection)
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
    final DocumentReference propRef = db.collection(propertyCollection).doc(propertyId);
    final int timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      await db.runTransaction((transaction) async {
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
          FactureFields.clientId: clientId,
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
      await db.runTransaction((transaction) async {
        DocumentReference propRef = db.collection(propertyCollection).doc(propertyId);
        
        transaction.update(propRef, {
          FirestoreFields.status: PropertyStatus.reserved,
          'lastLocataireId': facture.clientId,
          'reservedAt': FieldValue.serverTimestamp(),
          'lockTimestamp': FieldValue.delete(),
          'lockedBy': FieldValue.delete(),
        });

        DocumentReference factureRef = db.collection('factures').doc(facture.id);
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
      await db.collection(propertyCollection).doc(propertyId).update({
        FirestoreFields.hasPriorityRequest: true, 
        FirestoreFields.priorityRequestAt: FieldValue.serverTimestamp(),
        FactureFields.clientId: clientId,
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

      await db.collection(propertyCollection).doc(propertyId).update(updates);
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }
}