// lib/models/wallet_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class WalletModel {
  final String userId;
  final String phoneNumber;
  final double balance; // Argent réel (Balance principale)
  final double bonusBalance; 
  final double cashbackBalance; // Renommé pour correspondre à votre Firestore
  final double commissionBalance; // Renommé pour correspondre à votre Firestore
  final double pendingRefund;
  final double reliquatRemboursement; // 👈 Champ traçant la part remboursée non réinvestie (exonérée de frais)
  final bool hasReinvested; // 🛡️ 👈 Indicateur anti-fraude : true si le client a réinvesti une partie dans une nouvelle maison
  final String currency;
  final DateTime lastUpdate;
  final String accountType;
  final String status;
  final DateTime? bonusExpiryDate;

  WalletModel({
    required this.userId,
    required this.phoneNumber,
    required this.balance,
    this.bonusBalance = 0.0,
    this.cashbackBalance = 0.0,
    this.commissionBalance = 0.0,
    this.pendingRefund = 0.0,
    this.reliquatRemboursement = 0.0,
    this.hasReinvested = false, // 👈 Par défaut à false (pas de réinvestissement tant qu'il n'a pas pris de maison)
    this.currency = "USD",
    required this.lastUpdate,
    this.accountType = 'locataire',
    this.status = 'active',
    this.bonusExpiryDate,
  });

  // --- GETTERS POUR L'AFFICHAGE ---
  
  // Balance principale (le vrai argent)
  double get mainBalance => balance;

  // Total disponible (somme de tout)
  double get totalAvailable => balance + bonusBalance + cashbackBalance + commissionBalance;

  // --- GETTERS COMPLÉMENTAIRES (Pour compatibilité Widget) ---
  
  // Le solde retirable est simplement la balance principale
  double get realBalance => balance;

  // Le solde non-retirable est la somme des bonus, cashback et commissions
  double get nonWithdrawableBalance => bonusBalance + cashbackBalance + commissionBalance;

  // --- LOGIQUE ---

  bool get isRetirable => balance > 0;
  bool get isBonusExpired => bonusExpiryDate != null && DateTime.now().isAfter(bonusExpiryDate!);

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'phoneNumber': phoneNumber,
      'balance': balance,
      'bonusBalance': bonusBalance,
      'cashback_balance': cashbackBalance,
      'commission_balance': commissionBalance,
      'pendingRefund': pendingRefund,
      'reliquatRemboursement': reliquatRemboursement, // 👈 Sauvegarde dans Firestore
      'hasReinvested': hasReinvested, // 🛡️ 👈 Sauvegarde du témoin de réinvestissement
      'currency': currency,
      'lastUpdate': FieldValue.serverTimestamp(),
      'accountType': accountType,
      'status': status,
      'bonusExpiryDate': bonusExpiryDate != null ? Timestamp.fromDate(bonusExpiryDate!) : null,
    };
  }

  factory WalletModel.fromMap(Map<String, dynamic> map, String docId) {
    double currentBonus = (map['bonusBalance'] ?? 0.0).toDouble();
    DateTime? expiry = map['bonusExpiryDate'] is Timestamp 
        ? (map['bonusExpiryDate'] as Timestamp).toDate() 
        : null;
        
    if (expiry != null && DateTime.now().isAfter(expiry)) {
      currentBonus = 0.0;
    }

    return WalletModel(
      userId: docId,
      phoneNumber: map['phoneNumber'] ?? '',
      balance: (map['balance'] ?? 0.0).toDouble(),
      bonusBalance: currentBonus,
      cashbackBalance: (map['cashback_balance'] ?? 0.0).toDouble(),
      commissionBalance: (map['commission_balance'] ?? 0.0).toDouble(),
      pendingRefund: (map['pendingRefund'] ?? 0.0).toDouble(),
      reliquatRemboursement: (map['reliquatRemboursement'] ?? 0.0).toDouble(), // 👈 Lecture depuis Firestore
      hasReinvested: map['hasReinvested'] ?? false, // 🛡️ 👈 Lecture du témoin anti-fraude (false par défaut)
      currency: map['currency'] ?? 'USD',
      lastUpdate: map['lastUpdate'] is Timestamp ? (map['lastUpdate'] as Timestamp).toDate() : DateTime.now(),
      accountType: map['accountType'] ?? 'locataire',
      status: map['status'] ?? 'active',
      bonusExpiryDate: expiry,
    );
  }
}