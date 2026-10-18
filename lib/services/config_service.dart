import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/promotion_model.dart'; 
import '../models/service_model.dart'; 
import '../services/user_service.dart';

class ConfigService extends ChangeNotifier {
  // --- VARIABLES DE CONFIGURATION ---
  double tauxUsdCdf = 2500.0; 
  double refundServiceFee = 5.0; 
  double walletLimitPercentage = 0.25; // ✅ Variable pour la règle des 25%

  // ✅ VARIABLES STATISTIQUES COMMUNAUTAIRES
  int totalLocataires = 0;
  int totalBailleurs = 0;

  // ✅ STATISTIQUES LOCALES
  int totalLogesVille = 0;
  int ajoutsAujourdhuiVille = 0;
  String nomVilleActive = "Bukavu"; 

  // ✅ VARIABLES BONUS & PARRAINAGE (Passage en pourcentages)
  double welcomeBonusAmount = 0.0; 
  int welcomeBonusDurationDays = 0;
  bool isWelcomeBonusActive = false;
  double referralReferrerRate = 0.0; // Ancien referralReferrerReward
  double referralRefereeRate = 0.0;  // Ancien referralRefereeReward
  bool isReferralActive = false;
  bool isPartnerProgramActive = true; 

  // ✅ VARIABLES FIDÉLISATION
  bool isLoyaltyActive = false;
  double locataireCashbackPercent = 5.0; 
  double bailleurDiscountPercent = 5.0;  

  // ✅ LISTE DES CATÉGORIES IMMOBILIÈRES
  List<String> categoriesImmo = []; 

  String? activeCommunityGoalId;
  PromotionModel? currentPromo;

  // ✅ LISTE TYPÉE DES SERVICES (Source de vérité unique)
  List<ServiceModel> _services = [];

  // --- GETTERS ---
  
  List<ServiceModel> get servicesDisponibles => _services;

  List<ServiceModel> get mainServices => 
      _services.where((s) => s.famille == 'MAIN').toList();

  List<ServiceModel> get boostServices => 
      _services.where((s) => s.famille == 'BOOST').toList();

  List<ServiceModel> get alerteServices => 
      _services.where((s) => s.famille == 'ALERTE').toList();

  // ✅ CORRIGÉ : Correspondance exacte avec Firestore (underscore ajouté)
  List<ServiceModel> get installationServices => 
      _services.where((s) => 
          s.famille == 'ENTRETIEN' || 
          s.famille == 'DEMENAGEMENT' || 
          s.famille == 'PACK_DEMENAGEMENT'
      ).toList();

  Map<String, dynamic> tauxExpertise = {
    "bronze": {"bailleur": 15.0, "locataire": 10.0},
    "silver": {"bailleur": 15.0, "locataire": 13.0},
    "gold": {"bailleur": 15.0, "locataire": 17.0},
    "diamond": {"bailleur": 15.0, "locataire": 20.0},
  };

  Map<String, String> companyInfo = {
    "name": "EasyLocation Enterprise",
    "n_impot": "A2301893J",
    "rccm": "CD/BKV/RCCM/22-B-03012",
    "id_nat": "22-F4300-N24678A",
    "adresse": "N° 220, Av. Industriel, Q. Nkafu, C. Kadutu, Bukavu, Sud-Kivu, RDC",
    "tel": "+243980361265",
    "email": "contact@easylocationrdc.com",
  };

  Map<String, dynamic> paymentAccounts = {
    "mpesa": {"name": "JEAN BOSCO LANGE", "number": "0827969984"},
    "airtel": {"name": "lange", "number": "0993500174"},
    "orange": {"name": "JeanBosco LANGE", "number": "0859195584"},
    "africell": {"name": "lange muzaliwa", "number": "0901241207"},
  };

  double get commissionRate => (tauxExpertise["bronze"]?["bailleur"] ?? 15.0) / 100;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final UserService _userService = UserService();

  Future<void> init({String? newCity}) async {
    if (newCity != null) nomVilleActive = newCity;

    try {
      DocumentSnapshot doc = await _db
          .collection('settings')
          .doc('app_config')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _parseConfigData(data);
        debugPrint("✅ Configuration chargée.");
      }

      await _initLocalStats();
      await _loadCategoriesImmo(); 
      notifyListeners(); 
    } catch (e) {
      debugPrint("⚠️ ConfigService Error : $e");
    }
  }

  Future<void> _loadCategoriesImmo() async {
    try {
      DocumentSnapshot doc = await _db
          .collection('immobilier_config')
          .doc('categories_bien')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        categoriesImmo = List<String>.from(data['liste_categories'] ?? []);
        debugPrint("✅ Catégories chargées avec succès : $categoriesImmo");
      }
    } catch (e) {
      debugPrint("❌ Erreur lors du chargement de immobilier_config/categories_bien : $e");
    }
  }

  void _parseConfigData(Map<String, dynamic> data) {
    // ✅ Lecture de la limite dynamique depuis Firestore
    walletLimitPercentage = (data['wallet_limit_percentage'] as num?)?.toDouble() ?? 0.25;

    if (data['community_stats'] != null) {
      final stats = data['community_stats'];
      totalLocataires = (stats['total_locataires'] as num?)?.toInt() ?? 0;
      totalBailleurs = (stats['total_bailleurs'] as num?)?.toInt() ?? 0;
    }

    if (data['taux_usd_cdf'] != null) tauxUsdCdf = (data['taux_usd_cdf'] as num).toDouble();
    if (data['refund_service_fee'] != null) refundServiceFee = (data['refund_service_fee'] as num).toDouble();

    _services = [];

    if (data['main_services'] != null) {
      _services.addAll(
        (data['main_services'] as List)
            .map((e) => ServiceModel.fromConfig(Map<String, dynamic>.from(e))),
      );
    }

    if (data['upsell_services'] != null) {
      _services.addAll(
        (data['upsell_services'] as List)
            .map((e) => ServiceModel.fromConfig(Map<String, dynamic>.from(e))),
      );
    }

    if (data['welcome_bonus'] != null) {
      final wb = data['welcome_bonus'];
      welcomeBonusAmount = (wb['amount'] as num?)?.toDouble() ?? 0.0;
      welcomeBonusDurationDays = (wb['duration_days'] as num?)?.toInt() ?? 0;
      isWelcomeBonusActive = wb['status'] == 'active' || wb['is_active'] == true;
    }

    if (data['referral_config'] != null) {
      final rc = data['referral_config'];
      referralReferrerRate = (rc['referrer_rate'] as num?)?.toDouble() ?? (rc['referrer_reward'] as num?)?.toDouble() ?? 0.0;
      referralRefereeRate = (rc['referee_rate'] as num?)?.toDouble() ?? (rc['referee_reward'] as num?)?.toDouble() ?? 0.0;
      isReferralActive = rc['is_active'] ?? false;
      isPartnerProgramActive = rc['is_partner_active'] ?? true;
    }

    if (data['loyalty_config'] != null) {
      final lc = data['loyalty_config'];
      isLoyaltyActive = lc['is_active'] ?? false;
      locataireCashbackPercent = (lc['locataire_cashback_percent'] as num?)?.toDouble() ?? 5.0;
      bailleurDiscountPercent = (lc['bailleur_discount_percent'] as num?)?.toDouble() ?? 10.0;
    }

    if (data['taux_expertise'] != null) tauxExpertise = Map<String, dynamic>.from(data['taux_expertise']);
    if (data['company_info'] != null) companyInfo = Map<String, String>.from(data['company_info']);
    if (data['payment_accounts'] != null) paymentAccounts = Map<String, dynamic>.from(data['payment_accounts']);

    if (data['current_promo'] != null) {
      final p = data['current_promo'];
      currentPromo = PromotionModel(
        id: "global_active_promo",
        titre: p['titre'] ?? '',
        description: p['description'] ?? '',
        code: p['code'] ?? '',
        type: p['is_percentage'] == true ? PromoType.pourcentage : PromoType.montantFixe,
        beneficiaire: PromoBeneficiaire.tous, 
        valeur: (p['valeur'] as num?)?.toDouble() ?? 0.0,
        dateDebut: (p['date_debut'] as Timestamp).toDate(),
        dateFin: (p['date_fin'] as Timestamp).toDate(),
        statut: p['is_active'] == true ? 'actif' : 'inactif',
        provinces: [],
        villes: [],
        communes: [],
        servicesEligibles: [],
        categoriesEligibles: [],
      );
    }
  }

  Future<void> _initLocalStats() async {
    totalLogesVille = 0;
    ajoutsAujourdhuiVille = 0;
    try {
      DocumentSnapshot cityDoc = await _db.collection('stats_locales').doc(nomVilleActive.toLowerCase().trim()).get();
      if (cityDoc.exists) {
        final cityData = cityDoc.data() as Map<String, dynamic>;
        totalLogesVille = (cityData['total_loges'] as num?)?.toInt() ?? 0;
        ajoutsAujourdhuiVille = (cityData['ajouts_aujourdhui'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint("⚠️ Erreur stats locales : $e");
    }
  }

  /// Vérifie si un code promo spécifique est valide (dates, statut, limites et rôle utilisateur).
  Future<PromotionModel?> checkSpecificPromo(String inputCode) async {
    try {
      DocumentSnapshot doc = await _db
          .collection('promotions')
          .doc(inputCode.trim().toUpperCase())
          .get();

      if (doc.exists) {
        final promo = PromotionModel.fromFirestore(doc);

        // 1. Vérification de la validité générale (dates, statut, limites d'usage) via le modèle
        if (!promo.isValid) return null;

        // 2. Vérification du rôle bénéficiaire de l'utilisateur connecté
        if (promo.beneficiaire != PromoBeneficiaire.tous) {
          final user = FirebaseAuth.instance.currentUser;
          String userRole = 'locataire'; // Rôle par défaut si connecté
          
          if (user != null) {
            final userDoc = await _db.collection('utilisateurs').doc(user.uid).get();
            userRole = userDoc.data()?['role'] ?? 'locataire';
          } else {
            userRole = 'visiteur';
          }

          if (promo.beneficiaire.name != userRole) {
            debugPrint("❌ Promo non éligible pour le rôle utilisateur : $userRole");
            return null;
          }
        }

        return promo;
      }
    } catch (e) {
      debugPrint("❌ Erreur checkSpecificPromo : $e");
    }
    return null; 
  }

  Future<void> incrementPromoUsage(String promoCode) async {
    try {
      await _db.collection('promotions').doc(promoCode.trim().toUpperCase()).update({
        'usage_count': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint("❌ Erreur incrément : $e");
    }
  }
}