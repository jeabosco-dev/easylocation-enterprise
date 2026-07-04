import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/all_constants.dart';

class PaymentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Valide un paiement (manuel ou cash) et synchronise tous les documents liés.
  static Future<void> processPaymentUpdate({
    required String docId, // Maintenant utilisé aussi pour la création
    required String collectionTarget, // 'factures' ou 'services'
    required Map<String, dynamic> updateData,
    String? propertyId, // Optionnel (pour les locations)
    required String paymentMethod, // 'manuel' ou 'cash'
    required bool isNewCreation, // Indique si c'est une nouvelle création
    Map<String, dynamic>? newFactureData, // Données pour création si nécessaire
  }) async {
    final batch = _firestore.batch();
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? "unknown";

    if (isNewCreation && newFactureData != null) {
      // CAS 1: Création d'une nouvelle facture/service avec l'ID spécifié
      final newDocRef = _firestore.collection(collectionTarget).doc(docId);
      final Map<String, dynamic> dataToCreate = Map<String, dynamic>.from(newFactureData);
      
      // Fusion des données de création et des mises à jour
      dataToCreate.addAll(updateData);
      dataToCreate['clientId'] = userId;
      dataToCreate['etapeDossier'] = 'nouveau';
      
      batch.set(newDocRef, dataToCreate);
    } else {
      // CAS 2: Mise à jour d'un document existant
      final docRef = _firestore.collection(collectionTarget).doc(docId);
      batch.update(docRef, updateData);
    }

    // 2. Mise à jour de la propriété si c'est une location
    if (propertyId != null && propertyId.isNotEmpty) {
      final propRef = _firestore.collection(FirestoreCollections.properties).doc(propertyId);
      batch.update(propRef, {
        FirestoreFields.status: PropertyStatus.enAttentePaiement,
        FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
      });
    }

    // Exécution du batch
    await batch.commit();
  }
}