import 'package:cloud_firestore/cloud_firestore.dart';

class WalletModel {
  final String userId;
  final String phoneNumber;
  final double balance;
  final double bonusBalance;
  final double cashback;        // ✅ Nouveau champ
  final double commission;      // ✅ Nouveau champ
  final double pendingRefund;
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
    this.cashback = 0.0,
    this.commission = 0.0,
    this.pendingRefund = 0.0,
    this.currency = "USD",
    required this.lastUpdate,
    this.accountType = 'locataire',
    this.status = 'active',
    this.bonusExpiryDate,
  });

  // ✅ Calcul total unifié (le vrai "Total Disponible" qui inclut tout)
  double get totalAvailable => balance + bonusBalance + cashback + commission;

  // ✅ Total Asset incluant le remboursement en attente
  double get totalAsset => balance + bonusBalance + cashback + commission + pendingRefund;

  // ✅ Vérification expiration
  bool get isBonusExpired => bonusExpiryDate != null && DateTime.now().isAfter(bonusExpiryDate!);

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'phoneNumber': phoneNumber,
      'balance': balance,
      'bonusBalance': bonusBalance,
      'cashback_balance': cashback,
      'commission_balance': commission,
      'pendingRefund': pendingRefund,
      'currency': currency,
      'lastUpdate': FieldValue.serverTimestamp(),
      'accountType': accountType,
      'status': status,
      'bonusExpiryDate': bonusExpiryDate != null ? Timestamp.fromDate(bonusExpiryDate!) : null,
    };
  }

  factory WalletModel.fromMap(Map<String, dynamic> map, String docId) {
    // Logique d'expiration bonus
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
      cashback: (map['cashback_balance'] ?? 0.0).toDouble(),
      commission: (map['commission_balance'] ?? 0.0).toDouble(),
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