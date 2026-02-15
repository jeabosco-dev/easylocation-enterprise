import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    // Sécurité : évite de requêter Firestore si l'UID est vide ou mal formé
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
      
      // On récupère le rôle de sécurité actuel (super_admin ou autre)
      final String currentSecurityRole = data['role'] ?? 'locataire'; 

      final WriteBatch batch = _db.batch();

      // Mise à jour document principal
      batch.update(_db.collection(_collection).doc(uid), {
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Gestion de l'index si le téléphone change
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
      
      // Fallback si l'index est manquant
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

  /// 4. SYNCHRONISATION MULTI-RÔLE (VERSION CORRIGÉE AVEC INDEX)
  Future<void> syncUser(UserModel user, String newRole, [Map<String, dynamic>? rawData]) async {
    if (user.uid.isEmpty) return;

    final WriteBatch batch = _db.batch();
    final userRef = _db.collection(_collection).doc(user.uid);
    final String roleLower = newRole.toLowerCase();

    try {
      final doc = await userRef.get();
      
      if (doc.exists) {
        // Mise à jour d'un utilisateur existant
        final existingData = doc.data()!;
        final String currentSecurityRole = existingData['role'] ?? roleLower;

        batch.update(userRef, {
          'roles': FieldValue.arrayUnion([roleLower]),
          'activeRole': roleLower, 
          'updatedAt': FieldValue.serverTimestamp(),
          if (rawData != null) ...rawData,
        });

        // Mise à jour de l'index pour garantir la cohérence
        if (user.telephone.isNotEmpty) {
          batch.set(_db.collection('phone_index').doc(user.telephone), {
            'uid': user.uid,
            'role': currentSecurityRole, // On garde le rôle de sécurité (ex: super_admin)
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        // Création d'un nouvel utilisateur
        final data = user.toMap();
        data['roles'] = [roleLower]; 
        data['activeRole'] = roleLower;
        data['role'] = roleLower; // Rôle de sécurité initial
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();

        batch.set(userRef, data);

        // Création de l'index
        if (user.telephone.isNotEmpty) {
          batch.set(_db.collection('phone_index').doc(user.telephone), {
            'uid': user.uid,
            'role': roleLower,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      
      // Rafraîchissement du token pour que les Custom Claims soient pris en compte si besoin
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
}
