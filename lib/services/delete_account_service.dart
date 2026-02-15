import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class DeleteAccountService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gère l'ensemble du processus de suppression du compte de l'utilisateur.
  /// Inclut l'envoi de la notification par email et la suppression des données.
  Future<void> deleteUserAccount({
    required String reason,
    required String role,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("Aucun utilisateur n'est connecté.");
    }

    try {
      // 1. Récupérer les informations de l'utilisateur pour l'e-mail
      final userDoc = await _firestore.collection('utilisateurs').doc(user.uid).get();
      final userData = userDoc.data();
      final userName = '${userData?['prenom'] ?? ''} ${userData?['nom'] ?? ''}';
      final userEmail = user.email ?? 'N/A';

      // 2. Envoyer l'e-mail de notification via Cloud Function
      await _sendDeletionEmail(reason, userEmail, userName, role);

      // 3. Supprimer les collections spécifiques au rôle de l'utilisateur
      await _deleteRoleSpecificData(user.uid, role);

      // 4. Supprimer le document utilisateur de Firestore
      await _firestore.collection('utilisateurs').doc(user.uid).delete();

      // 5. Supprimer le compte de Firebase Authentication
      await user.delete();
      
      // Si toutes les étapes se déroulent bien, la fonction se termine.

    } on FirebaseAuthException catch (e) {
      // Gère l'exception de re-connexion si le token est expiré
      if (e.code == 'requires-recent-login') {
        throw Exception('re-login');
      }
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      // Gère les erreurs spécifiques à Firebase Functions
      print('Erreur lors de l\'appel de la Cloud Function: ${e.message}');
      // On continue même si l'e-mail n'a pas pu être envoyé
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Utilise une Cloud Function pour envoyer une notification de suppression de compte.
  Future<void> _sendDeletionEmail(
      String reason, String userEmail, String userName, String role) async {
    // ✅ MODIFICATION : Pointage vers la région europe-west1
    final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('sendDeletionEmail');
        
    await callable.call({
      'reason': reason,
      'userEmail': userEmail,
      'userName': userName,
      'role': role,
    });
  }

  /// Supprime les données de l'utilisateur en fonction de son rôle.
  Future<void> _deleteRoleSpecificData(String userId, String role) async {
    if (role == 'locataire') {
      await _deleteAllDocumentsInCollection('utilisateurs/$userId/favoris');
      await _deleteAllDocumentsInCollection('utilisateurs/$userId/alertes');
      await _deleteAllDocumentsInCollection('historique/$userId/user_history');
    }
    if (role == 'bailleur') {
      final publishedProperties = await _firestore.collection('proprietes').where('proprietaireId', isEqualTo: userId).get();
      for (var doc in publishedProperties.docs) {
        await doc.reference.delete();
      }
    }
  }

  /// Fonction utilitaire pour supprimer tous les documents d'une sous-collection.
  Future<void> _deleteAllDocumentsInCollection(String collectionPath) async {
    final collection = await _firestore.collection(collectionPath).get();
    for (var doc in collection.docs) {
      await doc.reference.delete();
    }
  }
}
