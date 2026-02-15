// lib/services/auth_service.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:easylocation_mvp/models/user_model.dart';
import 'package:easylocation_mvp/services/user_service.dart'; 
import 'package:easylocation_mvp/constants/constants.dart';

class UiException implements Exception {
  final String message;
  UiException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();

  /// ✅ NOUVELLE MÉTHODE : Lier un Email pour l'accès au Back-office Web
  Future<void> linkEmailToPhoneAccount({
    required String email,
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw UiException("Aucun utilisateur connecté au téléphone.");

      // 1. Création du credential Email
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      // 2. Liaison au compte existant
      await user.linkWithCredential(credential);

      // 3. Mise à jour du profil dans Firestore via UserService
      await _userService.updateProfile(user.uid, {
        'email': email,
        'statut_web': 'active',
      });

    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        throw UiException("Cet utilisateur est déjà lié à un email.");
      } else if (e.code == 'email-already-in-use') {
        throw UiException("Cet email est déjà utilisé par un autre compte.");
      }
      await Sentry.captureException(e);
      throw UiException("Erreur Firebase : ${e.message}");
    } catch (e) {
      await Sentry.captureException(e);
      throw UiException("Une erreur est survenue lors de l'activation web.");
    }
  }

  /// Vérifie si un numéro est disponible avant l'inscription
  Future<void> checkRegistrationAvailability(String phoneNumber) async {
    try {
      final existingUser = await _userService.getUserByPhoneNumber(phoneNumber);
      if (existingUser != null) {
        throw UiException("Ce numéro est déjà associé à un compte. Veuillez vous connecter.");
      }
    } catch (e) {
      if (e is UiException) rethrow;
      await Sentry.captureException(e);
      throw UiException("Erreur lors de la vérification du numéro.");
    }
  }

  /// Procédure de vérification SMS
  Future<void> verifyNewPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) onVerificationCompleted,
    required void Function(FirebaseAuthException) onVerificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  /// Connexion d'un utilisateur existant
  Future<UserModel> signInUser(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) throw UiException("Échec de l'authentification.");

      final userProfile = await _userService.getUser(firebaseUser.uid);
      if (userProfile == null) {
        throw UiException("Profil introuvable. Veuillez finaliser votre inscription.");
      }

      unawaited(_firestore.collection(FirestoreCollections.utilisateurs).doc(firebaseUser.uid).update({
        'isVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }).catchError((e) => Sentry.captureException(e)));

      return userProfile;
    } catch (e) {
      if (e is UiException) rethrow;
      Sentry.captureException(e);
      throw UiException("Erreur de connexion.");
    }
  }

  /// Inscription et synchronisation initiale
  Future<User> signInAndSyncUser(PhoneAuthCredential credential, {
    required bool estLocataire,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) throw UiException("Erreur d'identité Firebase.");

      final String roleInitial = estLocataire ? 'locataire' : 'bailleur';
      final newUser = UserModel.fromMap(userData, firebaseUser.uid);

      await _userService.syncUser(newUser, roleInitial, userData);

      return firebaseUser;
    } catch (e, stack) {
      await Sentry.captureException(e, stackTrace: stack);
      throw UiException("Erreur lors de la création de votre profil.");
    }
  }

  Future<void> signOut() async => await _auth.signOut();
  User? getCurrentUser() => _auth.currentUser;
}
