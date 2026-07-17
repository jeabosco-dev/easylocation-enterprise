// lib/providers/user_profile_provider.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../models/user_model.dart';
import '../models/property_model.dart'; 
import '../models/facture_model.dart'; 
import '../services/user_service.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

class UserProfileProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _userData;
  bool _isLoading = false;

  // --- Cache Recommandations ---
  List<Property> _cachedRecommendedProperties = [];
  DateTime? _lastRecommendationFetch;
  
  // --- Cache Favoris ---
  List<Property> _cachedFavoriteProperties = [];
  
  // --- Gestion Facture ---
  FactureModel? _lastFactureGenere;

  // --- Getters ---
  UserModel? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get activeRole => _userData?.activeRole;
  bool get isAuthenticated => _auth.currentUser != null && _userData != null;

  List<Property> get cachedRecommendedProperties => _cachedRecommendedProperties;
  List<Property> get cachedFavoriteProperties => _cachedFavoriteProperties;
  
  FactureModel? get lastFactureGenere => _lastFactureGenere;

  bool get canReceiveGift => _userData != null && _userData!.hasReceivedWelcomeGift == false;

  // ✅ Getter Uniformisé utilisant le modèle pour le Dashboard
  String get agentFullName => _userData?.nomComplet ?? "Utilisateur Inconnu";

  // ✅ SCALING : Getter sécurisé pour la ville active (utilisé par SocialProof)
  String get userVille => _userData?.ville ?? "Bukavu";

  // ✅ Getter pour la localisation rapide (Header/Profil)
  String get userLocationDisplay => "$userVille, ${_userData?.province ?? 'Sud-Kivu'}";

  bool get isAdminOrStaff => _userData?.activeRole == UserRoles.admin || _userData?.activeRole == 'agent' || _userData?.activeRole == 'staff';

  bool get isRecommendationCacheValid {
    if (_lastRecommendationFetch == null) return false;
    return DateTime.now().difference(_lastRecommendationFetch!) < const Duration(minutes: 5);
  }

  // --- ✅ GESTION DES NOTIFICATIONS PUSH (FCM) OPTIMISÉE ---
  
  Future<void> syncFCMToken(String userId) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Vérifie uniquement les permissions existantes sans demander à l'utilisateur
      final settings = await messaging.getNotificationSettings();

      // Si la permission n'est pas accordée, on arrête la synchronisation
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        log("ℹ️ UserProvider : Permission notifications non accordée, skip synchro token.");
        return;
      }

      // Si autorisé, on récupère le token
      final token = await messaging.getToken();

      if (token != null) {
        if (_userData?.fcmToken != token) {
          await _firestore
              .collection(FirestoreCollections.utilisateurs)
              .doc(userId)
              .set({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
          if (_userData != null) {
            _userData = _userData!.copyWith(fcmToken: token);
          }
            
          log("🚀 UserProvider : Nouveau Token FCM synchronisé pour $agentFullName");
        } else {
          log("✅ UserProvider : Token FCM déjà à jour.");
        }
      }
    } catch (e, stack) {
      log("🚨 UserProvider : Erreur synchro FCM : $e");
      await Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) => scope.setExtra("uid", userId),
      );
    }
  }

  // --- MISE À JOUR DES RECOMMANDATIONS ---
  void setRecommendedProperties(List<Property> properties) {
    _cachedRecommendedProperties = properties;
    _lastRecommendationFetch = DateTime.now();
    notifyListeners();
    log("🚀 UserProvider : Cache des recommandations mis à jour");
  }

  // --- GESTION DE LA PERSISTENCE DES FORMULAIRES ---
  Future<void> clearFormPersistence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_property_data'); 
      await prefs.remove('last_step_index');
      log("🧹 UserProvider : Persistance du formulaire nettoyée.");
    } catch (e) {
      log("🚨 Erreur lors du nettoyage de la persistance : $e");
    }
  }

  // --- Injection Manuelle ---
  void setUser(UserModel user) {
    _userData = user;
    
    _setSentryContext(_userData!);
    syncFCMToken(user.uid);
    
    notifyListeners(); 
    log("👤 UserProvider : Données injectées pour $agentFullName");
  }

  // --- MISE À JOUR ADRESSE ---
  Future<void> updateAddress({
    required String ville,
    required String province,
    required String commune,
  }) async {
    if (_userData == null) return;
    try {
      await _firestore
          .collection(FirestoreCollections.utilisateurs)
          .doc(_userData!.uid)
          .update({
        'ville': ville,
        'province': province,
        'commune': commune,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      _userData = _userData!.copyWith(
        ville: ville,
        province: province,
        commune: commune
      );
      notifyListeners();
      log("📍 UserProvider : Localisation mise à jour : $userLocationDisplay");
    } catch (e, stack) {
      log("🚨 Erreur updateAddress : $e");
      await Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) => scope.setExtra("uid", _userData!.uid),
      );
    }
  }

  // --- Gestion de la facture ---
  void setLastFacture(FactureModel? facture) {
    _lastFactureGenere = facture;
    notifyListeners();
  }

  void clearLastFacture() {
    _lastFactureGenere = null;
    notifyListeners();
  }

  // --- ✅ GESTION LOGISTIQUE & CADEAUX (ANTI-FRAUDE) ---

  Future<void> markGiftAsClaimed({String giftId = "Reçu"}) async {
    return await completeWelcomeGift(giftId);
  }

  Future<void> completeWelcomeGift(String giftId) async {
    if (_userData == null) return;
    try {
      _isLoading = true;
      notifyListeners();
      
      await _firestore
          .collection(FirestoreCollections.utilisateurs)
          .doc(_userData!.uid)
          .update({
        'hasReceivedWelcomeGift': true,
        'lastGiftId': giftId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _userData = _userData!.copyWith(
        hasReceivedWelcomeGift: true,
        lastGiftId: giftId,
      );
      
      log("🎁 UserProvider : Cadeau de bienvenue marqué comme consommé.");
    } catch (e, stack) {
      log("🚨 UserProvider : Erreur lors du marquage du cadeau : $e");
      await Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) {
          scope.setTag("action", "completeWelcomeGift");
          scope.setExtra("uid", _userData?.uid);
        },
      );
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ✅ CHARGEMENT UTILISATEUR
  Future<void> loadUser([String? uid]) async {
    if (_isLoading) return; 

    final targetUid = uid ?? _auth.currentUser?.uid;

    if (targetUid == null) {
      log("⚠️ UserProvider : Aucun UID trouvé pour le chargement.");
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      UserModel? fetchedUser = await _userService.getUser(targetUid);
      if (fetchedUser != null) {
        _userData = fetchedUser;
        
        _setSentryContext(_userData!);
        await syncFCMToken(targetUid);

        log("✅ UserProvider : Profil chargé pour $agentFullName (${_userData!.fullAddress})");
      } else {
        log("❌ UserProvider : Document utilisateur introuvable pour $targetUid");
      }
    } catch (e, stack) {
      log("🚨 Erreur loadUser : $e");
      await Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) => scope.setExtra("uid", targetUid),
      );
    } finally {
      _isLoading = false;
      notifyListeners(); 
    }
  }

  /// ✅ MÉTHODE DE RAFRAÎCHISSEMENT
  Future<void> refreshUser() async {
    if (_userData == null) return;
    try {
      final updatedData = await _userService.getUser(_userData!.uid);
      if (updatedData != null) {
        _userData = updatedData;
        notifyListeners();
        log("🔄 UserProvider : Profil rafraîchi pour $agentFullName");
      }
    } catch (e, stack) {
      log("🚨 Erreur refreshUser : $e");
      await Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) => scope.setExtra("uid", _userData!.uid),
      );
    }
  }

  /// ✅ CHANGEMENT DE RÔLE
  Future<void> setActiveRole(String role) async {
    if (_userData == null || _userData!.activeRole == role) return;
    final normalizedRole = role.toLowerCase();
    
    try {
      _isLoading = true; 
      notifyListeners();

      await _firestore
          .collection(FirestoreCollections.utilisateurs)
          .doc(_userData!.uid)
          .update({'activeRole': normalizedRole});

      _userData = _userData!.copyWith(activeRole: normalizedRole);
    } catch (e, stack) {
      await Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) {
          scope.setExtra("uid", _userData!.uid);
          scope.setExtra("requestedRole", normalizedRole);
        },
      );
    } finally {
      _isLoading = false;
      notifyListeners(); 
    }
  }

  // --- ✅ GESTION DES POINTS DE FIDÉLITÉ (COEXISTENCE) ---

  Future<void> deduirePoints(double pointsUtilises) async {
    if (pointsUtilises <= 0 || _userData == null) return;
    
    try {
      final double currentPoints = (_userData!.pointsLoyalty ?? 0).toDouble();
      final double newPoints = (currentPoints - pointsUtilises).clamp(0, double.infinity);
      
      await _firestore
          .collection(FirestoreCollections.utilisateurs)
          .doc(_userData!.uid)
          .update({
        'pointsLoyalty': newPoints,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      _userData = _userData!.copyWith(pointsLoyalty: newPoints.toInt());
      notifyListeners();
      
      log("📉 UserProvider : $pointsUtilises points déduits. Nouveau solde : ${_userData!.pointsLoyalty}");
    } catch (e, stack) {
      log("🚨 UserProvider : Erreur lors de la déduction des points : $e");
      await Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) {
          scope.setExtra("uid", _userData!.uid);
          scope.setExtra("pointsAttempted", pointsUtilises);
        },
      );
    }
  }

  // --- MÉTHODES UTILITAIRES ---
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await clearFormPersistence();

      _userData = null;
      _cachedRecommendedProperties = [];
      _cachedFavoriteProperties = [];
      _lastRecommendationFetch = null;
      
      notifyListeners();
      log("🚪 UserProvider : Déconnexion réussie");
    } catch (e, stack) {
      await Sentry.captureException(e, stackTrace: stack);
      _userData = null;
      notifyListeners();
    }
  }

  void _setSentryContext(UserModel user) {
    Sentry.configureScope((scope) => scope.setUser(
      SentryUser(id: user.uid, data: {'activeRole': user.activeRole}),
    ));
  }
}