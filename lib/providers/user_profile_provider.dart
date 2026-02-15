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
import '../services/settings_service.dart'; 
import '../constants/constants.dart'; 

class UserProfileProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final SettingsService _settingsService = SettingsService(); 
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _userData;
  bool _isLoading = false;
  
  double _tauxChange = 2500.0; 
  
  int _pendingRequestsCount = 0;
  StreamSubscription? _requestsSubscription;

  List<Property> _cachedRecommendedProperties = [];
  DateTime? _lastRecommendationFetch;
  List<Property> _cachedFavoriteProperties = [];
  
  FactureModel? _lastFactureGenere;

  // --- Getters ---
  UserModel? get userData => _userData;
  bool get isLoading => _isLoading;
  int get pendingRequestsCount => _pendingRequestsCount;
  String? get activeRole => _userData?.activeRole;
  bool get isAuthenticated => _auth.currentUser != null && _userData != null;

  double get tauxChange => (_tauxChange <= 0) ? 2500.0 : _tauxChange;

  List<Property> get cachedRecommendedProperties => _cachedRecommendedProperties;
  List<Property> get cachedFavoriteProperties => _cachedFavoriteProperties;
  
  FactureModel? get lastFactureGenere => _lastFactureGenere;

  /// ✅ LOGISTIQUE : Vérifie si l'utilisateur est éligible au cadeau de bienvenue (une seule fois dans sa vie)
  bool get canReceiveGift => _userData != null && _userData!.hasReceivedWelcomeGift == false;

  bool get isRecommendationCacheValid {
    if (_lastRecommendationFetch == null) return false;
    return DateTime.now().difference(_lastRecommendationFetch!) < const Duration(minutes: 5);
  }

  // --- Injection Manuelle (Utilisée après l'inscription/connexion OTP) ---

  void setUser(UserModel user) {
    _userData = user;
    
    if (_userData!.activeRole == UserRoles.landlord) {
      _initRequestsListener(_userData!.uid);
    }
    
    _setSentryContext(_userData!);
    notifyListeners(); 
    log("👤 UserProvider : Données injectées avec succès pour ${user.prenom}");
  }

  // --- Méthodes de gestion de la facture ---

  void setLastFacture(FactureModel? facture) {
    _lastFactureGenere = facture;
    notifyListeners();
  }

  void clearLastFacture() {
    _lastFactureGenere = null;
    notifyListeners();
  }

  // --- GESTION LOGISTIQUE & CADEAUX ---

  /// ✅ Marque le cadeau comme reçu définitivement dans Firestore et localement
  Future<void> completeWelcomeGift(String giftId) async {
    if (_userData == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      // 1. Mise à jour atomique sur Firestore
      await _firestore
          .collection(FirestoreCollections.utilisateurs)
          .doc(_userData!.uid)
          .update({
        'hasReceivedWelcomeGift': true,
        'lastGiftId': giftId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Mise à jour de l'état local pour bloquer l'accès immédiat aux futures tentatives
      _userData = _userData!.copyWith(
        hasReceivedWelcomeGift: true,
        lastGiftId: giftId,
      );

      log("🎁 Logistique : Cadeau [$giftId] validé pour ${_userData!.prenom}. Verrou activé.");
    } catch (e, stackTrace) {
      log("🚨 Erreur lors de la validation du cadeau : $e");
      Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Gestion du Taux de Change ---

  Future<void> _updateTauxChange() async {
    try {
      final nouveauTaux = await _settingsService.getTauxDuJour();
      if (nouveauTaux > 0) {
        _tauxChange = nouveauTaux;
        log("💵 Taux de change synchronisé : $_tauxChange CDF");
      } else {
        _tauxChange = 2500.0;
      }
    } catch (e) {
      log("🚨 Erreur critique Provider Taux : $e");
      _tauxChange = 2500.0; 
    }
  }

  // --- Chargement Utilisateur ---

  Future<void> loadUser(String uid) async {
    if (_isLoading) return; 
    
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _userService.getUser(uid),
        _updateTauxChange(),
      ]);

      UserModel? fetchedUser = results[0] as UserModel?;
      
      if (fetchedUser != null) {
        if (fetchedUser.roles.length > 1 && fetchedUser.activeRole.isEmpty) {
          log("🔄 Multi-rôle détecté ($uid). Attente de sélection.");
          _userData = fetchedUser.copyWith(activeRole: ''); 
        } else {
          _userData = fetchedUser;
          if (_userData!.activeRole == UserRoles.landlord) {
            _initRequestsListener(uid);
          }
        }
        _setSentryContext(_userData!);
      }
    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur Provider LoadUser: $e");
      Sentry.captureException(e, stackTrace: stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners(); 
    }
  }

  /// ✅ CHANGEMENT DE RÔLE
  Future<void> setActiveRole(String role) async {
    if (_userData == null || _userData!.activeRole == role) return;
    
    final normalizedRole = role.toLowerCase();
    if (!_userData!.roles.contains(normalizedRole)) return;

    try {
      _isLoading = true; 
      notifyListeners();

      await _firestore
          .collection(FirestoreCollections.utilisateurs)
          .doc(_userData!.uid)
          .update({'activeRole': normalizedRole})
          .timeout(const Duration(seconds: 5));

      _userData = _userData!.copyWith(activeRole: normalizedRole);
      
      _cachedRecommendedProperties = [];
      _cachedFavoriteProperties = [];
      _lastRecommendationFetch = null;
      
      if (normalizedRole == UserRoles.landlord) {
        _initRequestsListener(_userData!.uid);
      } else {
        await _requestsSubscription?.cancel();
        _pendingRequestsCount = 0;
      }
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      rethrow; 
    } finally {
      _isLoading = false;
      notifyListeners(); 
    }
  }

  // --- GESTION DES CACHES ---

  void setRecommendedProperties(List<Property> properties) {
    _cachedRecommendedProperties = properties;
    _lastRecommendationFetch = DateTime.now();
    notifyListeners();
  }

  void setFavoriteProperties(List<Property> properties) {
    _cachedFavoriteProperties = properties;
    notifyListeners();
  }

  void removeFavorite(String propertyId) {
    _cachedFavoriteProperties.removeWhere((p) => p.id == propertyId);
    notifyListeners();
  }

  // --- MÉTHODES UTILITAIRES ---

  Future<void> refreshUser() async {
    if (_userData == null) return;
    try {
      await _updateTauxChange(); 
      final updatedData = await _userService.getUser(_userData!.uid);
      if (updatedData != null) {
        _userData = updatedData;
        notifyListeners();
      }
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  Future<void> clearFormPersistence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('form_in_progress');
      debugPrint("✅ Persistence du formulaire réinitialisée");
      notifyListeners();
    } catch (e) {
      debugPrint("🚨 Erreur lors du clearFormPersistence: $e");
    }
  }

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
      _lastFactureGenere = null; 
      _tauxChange = 2500.0; 

      Sentry.configureScope((scope) => scope.setUser(null));
      notifyListeners();
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      await _auth.signOut().catchError((_) {});
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
    }, onError: (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
    });
  }

  void _setSentryContext(UserModel user) {
    Sentry.configureScope((scope) => scope.setUser(
      SentryUser(id: user.uid, data: {'roles': user.roles, 'activeRole': user.activeRole}),
    ));
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    super.dispose();
  }
}
