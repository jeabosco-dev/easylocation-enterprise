// lib/services/config_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/promotion_model.dart'; 

class ConfigService extends ChangeNotifier {
  // --- VARIABLES DE CONFIGURATION ---
  double tauxUsdCdf = 2500.0; 
  double refundServiceFee = 5.0; 

  // ✅ VARIABLES STATISTIQUES COMMUNAUTAIRES (Audit Trail Global)
  int totalLocataires = 0;
  int totalBailleurs = 0;

  // ✅ NOUVEAU : STATISTIQUES LOCALES (Social Proof par Ville)
  int totalLogesVille = 0;
  int ajoutsAujourdhuiVille = 0;
  String nomVilleActive = "Bukavu"; // Cette variable sera mise à jour par l'UI via le Provider

  // ✅ VARIABLES BONUS DE BIENVENUE
  double welcomeBonusAmount = 0.0; 
  int welcomeBonusDurationDays = 0;
  bool isWelcomeBonusActive = false;

  // ✅ VARIABLES PARRAINAGE C2C (Amis)
  double referralReferrerReward = 0.0; 
  double referralRefereeReward = 0.0; 
  bool isReferralActive = false;

  // ✅ VARIABLES PROGRAMME PARTENAIRES B2B
  bool isPartnerProgramActive = true; 

  // ✅ VARIABLES FIDÉLISATION (LOYALTY PROGRAM)
  bool isLoyaltyActive = false;
  double locataireCashbackPercent = 5.0; 
  double bailleurDiscountPercent = 10.0;  

  // ✅ VARIABLE : CHALLENGE COMMUNAUTAIRE
  String? activeCommunityGoalId;

  // ✅ VARIABLE : Promotion actuelle
  PromotionModel? currentPromo;

  // ✅ VARIABLE : Liste brute de tous les services
  List<Map<String, dynamic>> upsellServices = [];

  // ✅ FILTRES SERVICES
  List<Map<String, dynamic>> get boostServices =>
      upsellServices.where((s) => s['id'].toString().startsWith('BOOST')).toList();

  List<Map<String, dynamic>> get alerteServices =>
      upsellServices.where((s) => s['id'].toString().startsWith('VIP') || s['id'].toString().startsWith('ALERTE')).toList();

  Map<String, dynamic> tauxExpertise = {
    "bronze": {"bailleur": 15.0, "locataire": 10.0},
    "silver": {"bailleur": 15.0, "locataire": 13.0},
    "gold": {"bailleur": 15.0, "locataire": 17.0},
    "diamond": {"bailleur": 15.0, "locataire": 20.0},
  };

  // --- INFOS ENTREPRISE ---
  Map<String, String> companyInfo = {
    "name": "EasyLocation Enterprise",
    "n_impot": "A2301893J",
    "rccm": "CD/BKV/RCCM/22-B-03012",
    "id_nat": "22-F4300-N24678A",
    "adresse": "N° 220, Av. Industriel, Q. Nkafu, C. Kadutu, Bukavu, Sud-Kivu, RDC",
    "tel": "+243980361265",
    "email": "contact@easylocationrdc.com",
  };

  // --- COMPTES DE PAIEMENT ---
  Map<String, dynamic> paymentAccounts = {
    "mpesa": {"name": "JEAN BOSCO LANGE", "number": "0827969984"},
    "airtel": {"name": "lange", "number": "0993500174"},
    "orange": {"name": "JeanBosco LANGE", "number": "0859195584"},
    "africell": {"name": "lange muzaliwa", "number": "0901241207"},
  };

  double get commissionRate => (tauxExpertise["bronze"]?["bailleur"] ?? 15.0) / 100;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// --- INITIALISATION DES DONNÉES DEPUIS FIREBASE ---
  Future<void> init({String? newCity}) async {
    if (newCity != null) {
      nomVilleActive = newCity;
    }

    try {
      // 1. CHARGEMENT DE LA CONFIG GENERALE
      // Timeout augmenté à 15s pour les connexions instables
      DocumentSnapshot doc = await _db
          .collection('settings')
          .doc('app_config')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 15));

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _parseConfigData(data);
        debugPrint("✅ Configuration de l'application chargée avec succès.");
      }

      // ✅ 2. CHARGEMENT DU SOCIAL PROOF LOCAL
      await _initLocalStats();

      notifyListeners(); 
    } catch (e) {
      // En cas d'erreur ou timeout, on utilise les valeurs par défaut définies en haut du fichier
      debugPrint("⚠️ ConfigService : Erreur ou Timeout (utilisation des valeurs par défaut) : $e");
    }
  }

  void _parseConfigData(Map<String, dynamic> data) {
    // Statistiques globales
    if (data['community_stats'] != null) {
      final stats = data['community_stats'];
      totalLocataires = (stats['total_locataires'] as num?)?.toInt() ?? 0;
      totalBailleurs = (stats['total_bailleurs'] as num?)?.toInt() ?? 0;
    }

    // Taux et frais
    if (data['taux_usd_cdf'] != null) tauxUsdCdf = (data['taux_usd_cdf'] as num).toDouble();
    if (data['refund_service_fee'] != null) refundServiceFee = (data['refund_service_fee'] as num).toDouble();

    // Bonus Bienvenue
    if (data['welcome_bonus'] != null) {
      final wb = data['welcome_bonus'];
      welcomeBonusAmount = (wb['amount'] as num?)?.toDouble() ?? 0.0;
      welcomeBonusDurationDays = (wb['duration_days'] as num?)?.toInt() ?? 0;
      isWelcomeBonusActive = wb['status'] == 'active' || wb['is_active'] == true;
    }

    // Parrainage
    if (data['referral_config'] != null) {
      final rc = data['referral_config'];
      referralReferrerReward = (rc['referrer_reward'] as num?)?.toDouble() ?? 0.0;
      referralRefereeReward = (rc['referee_reward'] as num?)?.toDouble() ?? 0.0;
      isReferralActive = rc['is_active'] ?? false;
      isPartnerProgramActive = rc['is_partner_active'] ?? true;
    }

    // Fidélité
    if (data['loyalty_config'] != null) {
      final lc = data['loyalty_config'];
      isLoyaltyActive = lc['is_active'] ?? false;
      locataireCashbackPercent = (lc['locataire_cashback_percent'] as num?)?.toDouble() ?? 5.0;
      bailleurDiscountPercent = (lc['bailleur_discount_percent'] as num?)?.toDouble() ?? 10.0;
    }

    // Mapping des structures complexes
    if (data['taux_expertise'] != null) tauxExpertise = Map<String, dynamic>.from(data['taux_expertise']);
    if (data['company_info'] != null) companyInfo = Map<String, String>.from(data['company_info']);
    if (data['payment_accounts'] != null) paymentAccounts = Map<String, dynamic>.from(data['payment_accounts']);
    if (data['upsell_services'] != null) upsellServices = List<Map<String, dynamic>>.from(data['upsell_services']);

    // Promo
    if (data['current_promo'] != null) {
      final p = data['current_promo'];
      currentPromo = PromotionModel(
        id: "global_active_promo",
        titre: p['titre'] ?? '',
        description: p['description'] ?? '',
        code: p['code'] ?? '',
        type: p['is_percentage'] == true ? PromoType.pourcentage : PromoType.montantFixe,
        target: PromoTarget.commission,
        valeur: (p['valeur'] as num?)?.toDouble() ?? 0.0,
        dateDebut: (p['date_debut'] as Timestamp).toDate(),
        dateFin: (p['date_fin'] as Timestamp).toDate(),
        statut: p['is_active'] == true ? 'actif' : 'inactif',
      );
    }
  }

  /// ✅ Charge les stats spécifiques à la ville (Social Proof)
  Future<void> _initLocalStats() async {
    totalLogesVille = 0;
    ajoutsAujourdhuiVille = 0;

    try {
      DocumentSnapshot cityDoc = await _db
          .collection('stats_locales')
          .doc(nomVilleActive.toLowerCase().trim())
          .get()
          .timeout(const Duration(seconds: 10));

      if (cityDoc.exists) {
        final cityData = cityDoc.data() as Map<String, dynamic>;
        totalLogesVille = (cityData['total_loges'] as num?)?.toInt() ?? 0;
        ajoutsAujourdhuiVille = (cityData['ajouts_aujourdhui'] as num?)?.toInt() ?? 0;
        debugPrint("✅ Stats Locales chargées pour : $nomVilleActive");
      }
    } catch (e) {
      debugPrint("⚠️ Erreur chargement stats locales : $e");
    }
  }

  // --- LOGIQUE DE VÉRIFICATION PROMO ---
  Future<PromotionModel?> checkSpecificPromo(String inputCode) async {
    try {
      DocumentSnapshot doc = await _db.collection('promotions').doc(inputCode.trim().toUpperCase()).get();
      if (doc.exists) {
        final p = doc.data() as Map<String, dynamic>;
        int limit = p['usage_limit'] ?? 0;
        int count = p['usage_count'] ?? 0;
        if (limit > 0 && count >= limit) return null; 

        DateTime now = DateTime.now();
        DateTime debut = (p['date_debut'] as Timestamp).toDate();
        DateTime fin = (p['date_fin'] as Timestamp).toDate();

        if (now.isBefore(debut) || now.isAfter(fin)) return null;
        if (p['statut'] != 'actif') return null;

        return PromotionModel(
          id: doc.id,
          titre: p['titre'] ?? '',
          description: p['description'] ?? '',
          code: p['code'] ?? '',
          type: p['type'] == 'pourcentage' ? PromoType.pourcentage : PromoType.montantFixe,
          target: PromoTarget.commission,
          valeur: (p['valeur'] as num?)?.toDouble() ?? 0.0,
          dateDebut: debut,
          dateFin: fin,
          statut: p['statut'],
        );
      }
    } catch (e) {
      debugPrint("❌ Erreur promo : $e");
    }
    return null; 
  }
}