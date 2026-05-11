import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Import ajouté
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../models/user_model.dart';
import '../constants/constants.dart';

// =========================================================================
// 🛑 OPTIMISATION PERFORMANCE (COMPUTE)
// =========================================================================

class _UserParsingData {
  final Map<String, dynamic> data;
  final String uid;
  _UserParsingData(this.data, this.uid);
}

Future<UserModel> _parseUserModelData(_UserParsingData input) async {
  return UserModel.fromMap(input.data, input.uid);
}

// =========================================================================
// 🚀 SERVICE UNIQUE : USER SERVICE
// =========================================================================

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = FirestoreCollections.utilisateurs; 

  /// 1. RÉCUPÉRATION (Par UID)
  Future<UserModel?> getUser(String uid) async {
    if (uid.isEmpty) return null;

    try {
      final doc = await _db.collection(_collection).doc(uid).get().timeout(
            const Duration(seconds: 15), 
          );

      if (!doc.exists || doc.data() == null) return null;

      return await compute(
        _parseUserModelData, 
        _UserParsingData(doc.data()!, doc.id)
      );
    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur UserService.getUser: $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
      return null;
    }
  }

  /// 2. MISE À JOUR DU PROFIL (Mise à jour atomique Utilisateur + Index)
  Future<void> updateProfile(String uid, Map<String, dynamic> updates) async {
    if (uid.isEmpty) return;
    
    try {
      final userDoc = await _db.collection(_collection).doc(uid).get();
      if (!userDoc.exists) throw Exception("Utilisateur introuvable");

      final data = userDoc.data()!;
      final String? oldPhone = data['telephone'];
      final String? newPhone = updates['telephone'];
      
      final String currentSecurityRole = data['role'] ?? 'locataire'; 

      final WriteBatch batch = _db.batch();

      batch.update(_db.collection(_collection).doc(uid), {
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (newPhone != null && oldPhone != null && newPhone != oldPhone) {
        batch.delete(_db.collection('phone_index').doc(oldPhone));
        batch.set(_db.collection('phone_index').doc(newPhone), {
          'uid': uid,
          'role': currentSecurityRole,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur updateProfile: $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 3. RÉCUPÉRATION PAR TÉLÉPHONE (Optimisée via phone_index)
  Future<UserModel?> getUserByPhoneNumber(String phoneNumber) async {
    if (phoneNumber.isEmpty) return null;

    try {
      final indexDoc = await _db.collection('phone_index').doc(phoneNumber).get();
      
      if (indexDoc.exists) {
        final String? uid = indexDoc.data()?['uid'];
        if (uid != null) return await getUser(uid); 
      }
      
      final snapshot = await _db
          .collection(_collection)
          .where('telephone', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return await compute(
          _parseUserModelData, 
          _UserParsingData(doc.data(), doc.id)
        );
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur getUserByPhoneNumber: $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
      return null;
    }
  }

  /// 4. SYNCHRONISATION MULTI-RÔLE
  Future<void> syncUser(UserModel user, String newRole, [Map<String, dynamic>? rawData]) async {
    if (user.uid.isEmpty) return;

    final WriteBatch batch = _db.batch();
    final userRef = _db.collection(_collection).doc(user.uid);
    final String roleLower = newRole.toLowerCase();

    try {
      final doc = await userRef.get();
      
      if (doc.exists) {
        final existingData = doc.data()!;
        final String currentSecurityRole = existingData['role'] ?? roleLower;

        batch.update(userRef, {
          'roles': FieldValue.arrayUnion([roleLower]),
          'activeRole': roleLower, 
          'updatedAt': FieldValue.serverTimestamp(),
          if (rawData != null) ...rawData,
        });

        if (user.telephone.isNotEmpty) {
          batch.set(_db.collection('phone_index').doc(user.telephone), {
            'uid': user.uid,
            'role': currentSecurityRole,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        final data = user.toMap();
        data['roles'] = [roleLower]; 
        data['activeRole'] = roleLower;
        data['role'] = roleLower;
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();

        batch.set(userRef, data);

        if (user.telephone.isNotEmpty) {
          batch.set(_db.collection('phone_index').doc(user.telephone), {
            'uid': user.uid,
            'role': roleLower,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      
    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur syncUser: $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 5. VÉRIFICATION DE DISPONIBILITÉ
  Future<bool> isPhoneNumberInUse(String phone) async {
    if (phone.isEmpty) return false;
    try {
      final indexDoc = await _db.collection('phone_index').doc(phone).get();
      return indexDoc.exists;
    } catch (e) {
      return false;
    }
  }

  /// 6. MISE À JOUR DU TOKEN DE NOTIFICATION (FCM)
  /// Permet au backend d'envoyer des notifications Push à cet appareil
  Future<void> updateFCMToken(String uid) async {
    if (uid.isEmpty) return;

    try {
      // Récupération du token unique de l'appareil
      String? token = await FirebaseMessaging.instance.getToken();
      
      if (token != null) {
        await _db.collection(_collection).doc(uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        debugPrint("🚀 Token FCM mis à jour pour l'utilisateur : $uid");
      }
    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur updateFCMToken: $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }
}