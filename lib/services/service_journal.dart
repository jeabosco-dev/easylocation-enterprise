// lib/services/service_journal.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ✅ IMPORT IMPORTANT : Pour utiliser FirestoreCollections.activityLog
import 'package:easylocation_mvp/constants/all_constants.dart';

class ServiceJournal {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Enregistre une nouvelle activité dans le journal
  static Future<void> enregistrerActivite({
    required String activite,
    required String type, // 'creation', 'modification', 'visite', etc.
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print("Journal : Aucun utilisateur connecté, enregistrement annulé.");
        return;
      }

      // ✅ Utilisation de la constante
      await _db.collection(FirestoreCollections.activityLog).add({
        'userId': user.uid,
        'activity': activite,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print("Journal : Activité enregistrée ($type)");
    } catch (e) {
      print("Erreur lors de l'enregistrement du journal : $e");
    }
  }

  /// ✅ Supprime une activité spécifique du journal
  static Future<void> supprimerActivite(String activiteId) async {
    try {
      if (activiteId.isEmpty) {
        print("Erreur : ID d'activité vide.");
        return;
      }
      
      // ✅ Utilisation de la constante
      await _db.collection(FirestoreCollections.activityLog).doc(activiteId).delete();
      
      print("Firestore : Document $activiteId supprimé du serveur.");
    } catch (e) {
      print("Erreur lors de la suppression de l'activité : $e");
    }
  }

  /// Supprimer tout l'historique d'un utilisateur spécifique (Batch)
  static Future<void> viderJournalUtilisateur(String userId) async {
    try {
      // ✅ Utilisation de la constante
      final snapshots = await _db
          .collection(FirestoreCollections.activityLog)
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshots.docs.isEmpty) {
        print("Journal : Aucun document à supprimer pour cet utilisateur.");
        return;
      }

      final batch = _db.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print("Journal : Historique de l'utilisateur $userId vidé avec succès.");
    } catch (e) {
      print("Erreur lors du nettoyage du journal : $e");
    }
  }
}