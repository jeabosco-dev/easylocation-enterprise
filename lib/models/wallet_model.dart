import 'package:cloud_firestore/cloud_firestore.dart';

class WalletModel {
  final String userId;
  final String phoneNumber;    // ✅ Pour lier le wallet aux demandes P2P
  final double balance;        // Argent réel retirable
  final double bonusBalance;   // EasyCredits / Points (Non retirable)
  final double pendingRefund;  // Argent en cours de remboursement (Bloqué)
  final String currency;
  final DateTime lastUpdate;
  final String accountType;    // 'locataire' ou 'bailleur'
  final String status;         // 'active', 'locked', 'pending_verification'

  // ✅ Date d'expiration pour les EasyCredits
  final DateTime? bonusExpiryDate;

  WalletModel({
    required this.userId,
    required this.phoneNumber, // ✅ Initialisation requise
    required this.balance,
    this.bonusBalance = 0.0,
    this.pendingRefund = 0.0,
    this.currency = "USD",
    required this.lastUpdate,
    this.accountType = 'locataire',
    this.status = 'active',
    this.bonusExpiryDate,
  });

  /// ⚠️ ATTENTION : Ce total ne représente que l'univers strict du document "wallets".
  /// Pour un calcul hybride complet (incluant les points de fidélité et les commissions bailleurs 
  /// stockés dans le document "utilisateurs"), préférez valider l'éligibilité finale directement 
  /// auprès du backend via la Cloud Function 'initiateHybridPayment'.
  double get totalAvailable => balance + bonusBalance;

  /// 🟢 AJUSTEMENT UI : Utilitaire indicatif pour le contrôle de premier niveau côté client.
  /// Renvoie vrai si les fonds de base du portefeuille suffisent à eux seuls.
  bool peutPayerEnLigneDirecte(double montant) => totalAvailable >= montant;

  /// ✅ TOTAL RÉEL (PATRIMOINE) : Tout ce qui appartient au client (Réel + Bonus + Pending).
  double get totalAsset => balance + bonusBalance + pendingRefund;

  /// ✅ EST EXPIRÉ : Vérifie si le bonus a dépassé sa date de validité
  bool get isBonusExpired => 
      bonusExpiryDate != null && DateTime.now().isAfter(bonusExpiryDate!);

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'phoneNumber': phoneNumber, // ✅ Stockage du numéro
      'balance': balance,
      'bonusBalance': bonusBalance,
      'pendingRefund': pendingRefund,
      'currency': currency,
      'lastUpdate': FieldValue.serverTimestamp(),
      'accountType': accountType,
      'status': status,
      'bonusExpiryDate': bonusExpiryDate != null 
          ? Timestamp.fromDate(bonusExpiryDate!) 
          : null,
    };
  }

  factory WalletModel.fromMap(Map<String, dynamic> map, String docId) {
    // 1. Récupération initiale du bonus
    double currentBonus = (map['bonusBalance'] ?? 0.0).toDouble();
    
    // 2. Récupération de la date d'expiration
    DateTime? expiry = map['bonusExpiryDate'] is Timestamp 
        ? (map['bonusExpiryDate'] as Timestamp).toDate() 
        : null;

    // ✅ LOGIQUE D'EXPIRATION : Si la date est passée, le bonus passe à 0 à la lecture
    if (expiry != null && DateTime.now().isAfter(expiry)) {
      currentBonus = 0.0;
    }

    return WalletModel(
      userId: docId,
      phoneNumber: map['phoneNumber'] ?? '', // ✅ Récupération du numéro
      balance: (map['balance'] ?? 0.0).toDouble(),
      bonusBalance: currentBonus,
      pendingRefund: (map['pendingRefund'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'USD',
      lastUpdate: map['lastUpdate'] is Timestamp 
          ? (map['lastUpdate'] as Timestamp).toDate() 
          : DateTime.now(),
      accountType: map['accountType'] ?? 'locataire',
      status: map['status'] ?? 'active',
      bonusExpiryDate: expiry,
    );
  }
}