import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:easylocation_mvp/models/user_model.dart';
import 'package:easylocation_mvp/models/community_goal_model.dart';
import 'package:easylocation_mvp/services/user_service.dart'; 
import 'package:easylocation_mvp/services/config_service.dart';
import 'package:easylocation_mvp/services/goal_tracking_service.dart'; 
import 'package:easylocation_mvp/constants/all_constants.dart';

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
  final GoalTrackingService _goalService = GoalTrackingService();

  /// ✅ Lier un Email pour l'accès au Back-office Web
  Future<void> linkEmailToPhoneAccount({
    required String email,
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw UiException("Aucun utilisateur connecté au téléphone.");

      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.linkWithCredential(credential);

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

  /// ✅ Inscription et synchronisation initiale avec Sécurité Partenaire
  Future<User> signInAndSyncUser(
    PhoneAuthCredential credential, {
    required bool estLocataire,
    required Map<String, dynamic> userData,
    required ConfigService config,
    String? referrerId,
  }) async {
    try {
      // --- 1. SÉCURITÉ PARTENAIRE (B2B) ---
      if (referrerId != null && referrerId.startsWith('PART-')) {
        final partnerDoc = await _firestore.collection('partenaires').doc(referrerId).get();
        
        if (partnerDoc.exists) {
          final pData = partnerDoc.data()!;
          final bool isActive = pData['is_active'] ?? false;
          final String status = pData['status'] ?? 'inactive';

          if (!isActive || status != 'active') {
            throw UiException("Ce code partenaire n'est plus valide. Veuillez contacter le support.");
          }
        } else {
          throw UiException("Code partenaire introuvable.");
        }
      }

      // --- 2. AUTHENTIFICATION FIREBASE ---
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) throw UiException("Erreur d'identité Firebase.");

      // --- 3. PRÉPARATION DES DONNÉES ---
      // L'attribut 'ville' est récupéré depuis 'userData' passé par l'écran d'inscription
      final Map<String, dynamic> completeUserData = {
        ...userData,
        'referrerId': referrerId,
        'isFirstPaymentDone': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final String roleInitial = estLocataire ? 'locataire' : 'bailleur';
      final newUser = UserModel.fromMap(completeUserData, firebaseUser.uid);

      // --- 4. SYNCHRONISATION DU PROFIL ---
      await _userService.syncUser(newUser, roleInitial, completeUserData);

      // --- 5. ATTRIBUTION DU BONUS ET CRÉATION DU WALLET ---
      if (config.isWelcomeBonusActive && config.welcomeBonusAmount > 0) {
        DateTime expiry = DateTime.now().add(Duration(days: config.welcomeBonusDurationDays));

        await _firestore.collection(FirestoreCollections.wallets).doc(firebaseUser.uid).set({
          'userId': firebaseUser.uid,
          'phoneNumber': firebaseUser.phoneNumber, 
          'balance': 0.0,
          'bonusBalance': config.welcomeBonusAmount,
          'bonusExpiryDate': Timestamp.fromDate(expiry),
          'pendingRefund': 0.0,
          'currency': 'USD',
          'lastUpdate': FieldValue.serverTimestamp(),
          'accountType': roleInitial,
          'status': 'active',
          'ville': userData['ville'] ?? 'Bukavu', // On stocke aussi la ville dans le wallet pour faciliter les analytics
        }, SetOptions(merge: true));
        
        debugPrint("🎁 Bonus de bienvenue de ${config.welcomeBonusAmount} USD attribué");
      }

      // --- 6. TRACKING DU CHALLENGE COMMUNAUTAIRE ---
      // ✅ CORRECTION : On utilise la ville choisie par l'utilisateur ou Bukavu par défaut
      String userVille = userData['ville'] ?? 'Bukavu';
      unawaited(_goalService.trackAction(
        ville: userVille, 
        type: MissionType.inscriptions
      ));

      return firebaseUser;
    } catch (e, stack) {
      if (e is UiException) rethrow;
      await Sentry.captureException(e, stackTrace: stack);
      throw UiException("Erreur lors de la création de votre profil.");
    }
  }

  Future<void> signOut() async => await _auth.signOut();
  User? getCurrentUser() => _auth.currentUser;
}