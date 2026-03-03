// lib/providers/user_profile_provider.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../models/user_model.dart';
import '../models/property_model.dart'; 
import '../models/facture_model.dart'; 
import '../services/user_service.dart';
import '../constants/constants.dart'; 

class UserProfileProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _userData;
  bool _isLoading = false;
  
  int _pendingRequestsCount = 0;
  StreamSubscription? _requestsSubscription;

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
  int get pendingRequestsCount => _pendingRequestsCount;
  String? get activeRole => _userData?.activeRole;
  bool get isAuthenticated => _auth.currentUser != null && _userData != null;

  List<Property> get cachedRecommendedProperties => _cachedRecommendedProperties;
  List<Property> get cachedFavoriteProperties => _cachedFavoriteProperties;
  
  FactureModel? get lastFactureGenere => _lastFactureGenere;

  bool get canReceiveGift => _userData != null && _userData!.hasReceivedWelcomeGift == false;

  bool get isRecommendationCacheValid {
    if (_lastRecommendationFetch == null) return false;
    return DateTime.now().difference(_lastRecommendationFetch!) < const Duration(minutes: 5);
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
    if (_userData!.activeRole == UserRoles.landlord) {
      _initRequestsListener(_userData!.uid);
    }
    _setSentryContext(_userData!);
    notifyListeners(); 
    log("👤 UserProvider : Données injectées pour ${user.prenom}");
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

  // --- GESTION LOGISTIQUE & CADEAUX ---
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
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Chargement Utilisateur ---
  Future<void> loadUser(String uid) async {
    if (_isLoading) return; 
    _isLoading = true;
    notifyListeners();

    try {
      UserModel? fetchedUser = await _userService.getUser(uid);
      if (fetchedUser != null) {
        _userData = fetchedUser;
        if (_userData!.activeRole == UserRoles.landlord) {
          _initRequestsListener(uid);
        }
        _setSentryContext(_userData!);
      }
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners(); 
    }
  }

  /// ✅ MÉTHODE DE RAFRAÎCHISSEMENT (Celle qui manquait !)
  Future<void> refreshUser() async {
    if (_userData == null) return;
    try {
      final updatedData = await _userService.getUser(_userData!.uid);
      if (updatedData != null) {
        _userData = updatedData;
        notifyListeners();
        log("🔄 UserProvider : Profil rafraîchi");
      }
    } catch (e, stackTrace) {
      log("🚨 Erreur refreshUser : $e");
      Sentry.captureException(e, stackTrace: stackTrace);
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
      
      if (normalizedRole == UserRoles.landlord) {
        _initRequestsListener(_userData!.uid);
      } else {
        await _requestsSubscription?.cancel();
        _pendingRequestsCount = 0;
      }
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners(); 
    }
  }

  // --- MÉTHODES UTILITAIRES ---
  Future<void> signOut() async {
    try {
      await _requestsSubscription?.cancel();
      _requestsSubscription = null;
      await _auth.signOut();
      
      _userData = null;
      _pendingRequestsCount = 0;
      _cachedRecommendedProperties = [];
      _cachedFavoriteProperties = [];
      _lastRecommendationFetch = null;
      
      notifyListeners();
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      _userData = null;
      notifyListeners();
    }
  }

  void _initRequestsListener(String bailleurId) {
    _requestsSubscription?.cancel(); 
    _requestsSubscription = _firestore
        .collection(FirestoreCollections.demandesVisites)
        .where('bailleurId', isEqualTo: bailleurId)
        .where('statut', isEqualTo: 'en_attente')
        .snapshots()
        .listen((snapshot) {
      _pendingRequestsCount = snapshot.docs.length;
      notifyListeners();
    });
  }

  void _setSentryContext(UserModel user) {
    Sentry.configureScope((scope) => scope.setUser(
      SentryUser(id: user.uid, data: {'activeRole': user.activeRole}),
    ));
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    super.dispose();
  }
}