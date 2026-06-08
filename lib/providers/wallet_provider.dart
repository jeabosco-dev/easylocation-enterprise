// lib/providers/wallet_provider.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';

class WalletProvider with ChangeNotifier {
  WalletModel? _wallet;
  List<TransactionModel> _transactions = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  WalletModel? get wallet => _wallet;
  List<TransactionModel> get transactions => _transactions;
  List<Map<String, dynamic>> get incomingRequests => _incomingRequests;
  bool get isLoading => _isLoading;

  /// Écouter le wallet ET ses transactions en temps réel
  void listenToWallet(String userId) {
    _isLoading = true;
    notifyListeners();

    FirebaseFirestore.instance
        .collection('wallets')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        _wallet = WalletModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (_wallet?.phoneNumber != null) listenToIncomingRequests(_wallet!.phoneNumber);
        _isLoading = false;
        notifyListeners();
      } else {
        _isLoading = false;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint("Erreur stream wallet: $e");
      _isLoading = false;
      notifyListeners();
    });

    FirebaseFirestore.instance
        .collection('transactions')
        .where('walletId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      _transactions = snapshot.docs.map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      notifyListeners();
    });
  }

  /// Logique centralisée de déduction séquentielle : Bonus -> Cashback -> Commission -> Balance
  Map<String, double> calculerDeduction(Map<String, dynamic> data, double montant) {
    double b = (data['balance'] ?? 0.0).toDouble();
    double bonus = (data['bonusBalance'] ?? 0.0).toDouble();
    double cash = (data['cashback_balance'] ?? 0.0).toDouble();
    double com = (data['commission_balance'] ?? 0.0).toDouble();

    // Gestion expiration bonus
    DateTime? expiry = data['bonusExpiryDate'] is Timestamp ? (data['bonusExpiryDate'] as Timestamp).toDate() : null;
    if (expiry != null && DateTime.now().isAfter(expiry)) bonus = 0.0;

    if ((b + bonus + cash + com) < montant) throw Exception("Solde total insuffisant.");

    double restant = montant;
    double dBonus = math.min(bonus, restant); restant -= dBonus;
    double dCash = math.min(cash, restant); restant -= dCash;
    double dCom = math.min(com, restant); restant -= dCom;
    double dBal = restant;

    return {'bonus': dBonus, 'cash': dCash, 'com': dCom, 'bal': dBal};
  }

  // ==========================================
  // SECTION : PARTENARIAT & COMMISSIONS
  // ==========================================

  Future<void> sendCreditsFromPartner({required String partnerId, required String receiverPhone, required double amount}) async {
    final db = FirebaseFirestore.instance;
    final partnerDoc = await db.collection('partenaires').doc(partnerId).get();
    final String partnerName = partnerDoc.data()?['nom'] ?? "Un Partenaire";

    final receiverQuery = await db.collection('utilisateurs').where('phoneNumber', isEqualTo: receiverPhone).limit(1).get();
    if (receiverQuery.docs.isEmpty) throw Exception("Destinataire introuvable.");
    
    final String receiverId = receiverQuery.docs.first.id;
    final receiverWalletRef = db.collection('wallets').doc(receiverId);
    final partnerRef = db.collection('partenaires').doc(partnerId);

    return db.runTransaction((transaction) async {
      final partnerSnap = await transaction.get(partnerRef);
      if (!partnerSnap.exists) throw Exception("Compte partenaire inexistant.");

      double currentCommission = (partnerSnap.data()?['solde_commission'] ?? 0.0).toDouble();
      if (currentCommission < amount) throw Exception("Solde de commission insuffisant.");

      transaction.update(partnerRef, {'solde_commission': FieldValue.increment(-amount)});
      transaction.update(receiverWalletRef, {'bonusBalance': FieldValue.increment(amount), 'lastUpdate': FieldValue.serverTimestamp()});

      final txReceiver = db.collection('transactions').doc();
      transaction.set(txReceiver, {'walletId': receiverId, 'userId': receiverId, 'title': "Crédit reçu de $partnerName", 'amount': amount, 'isPositive': true, 'date': FieldValue.serverTimestamp(), 'type': 'partner_transfer'});
      
      final auditRef = db.collection('audit_commissions').doc();
      transaction.set(auditRef, {'partnerId': partnerId, 'type': 'CONVERSION_CREDIT', 'amount': amount, 'receiverPhone': receiverPhone, 'receiverId': receiverId, 'date': FieldValue.serverTimestamp()});
    });
  }

  // ==========================================
  // SECTION : TRANSFERT & PAIEMENT (LOGIQUE P2P & MIXTE)
  // ==========================================

  Future<void> sendCreditsToUser({required String receiverPhone, required double amount}) async {
    final String senderId = _auth.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    final senderWalletRef = db.collection('wallets').doc(senderId);
    
    final receiverQuery = await db.collection('utilisateurs').where('phoneNumber', isEqualTo: receiverPhone).limit(1).get();
    if (receiverQuery.docs.isEmpty) throw Exception("Destinataire introuvable.");
    final String receiverId = receiverQuery.docs.first.id;
    final String receiverName = receiverQuery.docs.first.data()['displayName'] ?? "Destinataire";
    final receiverWalletRef = db.collection('wallets').doc(receiverId);

    return db.runTransaction((transaction) async {
      final senderSnap = await transaction.get(senderWalletRef);
      if (!senderSnap.exists) throw Exception("Portefeuille introuvable.");

      final ded = calculerDeduction(senderSnap.data()!, amount);

      transaction.update(senderWalletRef, {
        'balance': FieldValue.increment(-ded['bal']!),
        'bonusBalance': FieldValue.increment(-ded['bonus']!),
        'cashback_balance': FieldValue.increment(-ded['cash']!),
        'commission_balance': FieldValue.increment(-ded['com']!),
        'lastUpdate': FieldValue.serverTimestamp(),
      });

      transaction.update(receiverWalletRef, {'bonusBalance': FieldValue.increment(amount), 'lastUpdate': FieldValue.serverTimestamp()});

      final txSender = db.collection('transactions').doc();
      transaction.set(txSender, {'walletId': senderId, 'userId': senderId, 'title': "Envoi à $receiverName", 'amount': amount, 'isPositive': false, 'date': FieldValue.serverTimestamp(), 'type': 'p2p_transfer'});
    });
  }

  Future<String> initierPaiementCashMixte({required String bienId, required String refBien, required double montantTotal, required double montantWallet}) async {
    final String userId = _auth.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    final walletRef = db.collection('wallets').doc(userId);
    final factureRef = db.collection('factures').doc();
    final bienRef = db.collection('properties').doc(bienId);

    await db.runTransaction((transaction) async {
      final walletSnap = await transaction.get(walletRef);
      if (!walletSnap.exists) throw Exception("Portefeuille introuvable.");
      
      if (montantWallet > 0) {
        final ded = calculerDeduction(walletSnap.data()!, montantWallet);
        transaction.update(walletRef, {
          'balance': FieldValue.increment(-ded['bal']!),
          'bonusBalance': FieldValue.increment(-ded['bonus']!),
          'cashback_balance': FieldValue.increment(-ded['cash']!),
          'commission_balance': FieldValue.increment(-ded['com']!),
          'lastUpdate': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(factureRef, {
        'clientUid': userId, 'propertyId': bienId, 'refBien': refBien, 'methodePaiement': 'cash',
        'status': 'pending', 'montantTotal': montantTotal, 'montantAPayer': montantTotal - montantWallet,
        'montantWallet': montantWallet, 'dateCreation': FieldValue.serverTimestamp(), 'dateExpiration': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 2))),
      });
      transaction.update(bienRef, {'status': 'en_attente_cash'});
    });
    return factureRef.id;
  }

  // ==========================================
  // SECTION : UTILS & REQUESTS
  // ==========================================

  void listenToIncomingRequests(String userPhone) {
    FirebaseFirestore.instance.collection('payment_requests').where('toPhone', isEqualTo: userPhone).where('status', isEqualTo: 'en_attente').snapshots().listen((snapshot) {
      _incomingRequests = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
      notifyListeners();
    });
  }

  Future<void> createPaymentRequest({required String receiverPhone, required double amount}) async {
    final String senderId = _auth.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(senderId).get();
    await FirebaseFirestore.instance.collection('payment_requests').add({
      'fromId': senderId, 'fromName': userDoc.data()?['displayName'] ?? "Utilisateur",
      'toPhone': receiverPhone, 'amount': amount, 'status': 'en_attente', 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptPaymentRequest(Map<String, dynamic> request) async {
    final senderDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(request['fromId']).get();
    await sendCreditsToUser(receiverPhone: senderDoc.data()?['phoneNumber'], amount: (request['amount'] as num).toDouble());
    await FirebaseFirestore.instance.collection('payment_requests').doc(request['id']).update({'status': 'accepte'});
  }

  Future<void> rejectPaymentRequest(String requestId) async {
    await FirebaseFirestore.instance.collection('payment_requests').doc(requestId).update({'status': 'refuse'});
  }

  Future<HttpsCallableResult<dynamic>> payForServiceViaCloud({
    required String serviceId, 
    required String serviceType, 
    required double servicePrice, 
    required double walletAmountRequested,
    required double partLocataire,
    Map<String, dynamic>? metadata
  }) async {
    _isLoading = true; 
    notifyListeners();
    try {
      final response = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('initiateHybridPayment')
          .call({
            'serviceId': serviceId, 
            'serviceType': serviceType, 
            'totalAmount': servicePrice, 
            'walletAmountRequested': walletAmountRequested,
            'partLocataire': partLocataire,
            'metadata': metadata ?? {}
          });
      
      _isLoading = false; 
      notifyListeners(); 
      return response;
    } catch (e) { 
      _isLoading = false; 
      notifyListeners(); 
      rethrow; 
    }
  }

  Future<void> requestRefund({required String userId, required double amount, required double serviceFee, required String paymentMethod}) async {
    final userDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(userId).get();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance.collection('wallets').doc(userId), {'balance': FieldValue.increment(-amount), 'pendingRefund': FieldValue.increment(amount), 'lastUpdate': FieldValue.serverTimestamp()});
    batch.set(FirebaseFirestore.instance.collection('refund_requests').doc(), {'userId': userId, 'amount': amount, 'status': 'en_attente', 'createdAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  Future<void> refreshAll(String userId) async => listenToWallet(userId);
  Future<String?> getUserNameByPhone(String phone) async {
    final q = await FirebaseFirestore.instance.collection('utilisateurs').where('phoneNumber', isEqualTo: phone).limit(1).get();
    return q.docs.isNotEmpty ? q.docs.first.data()['displayName'] : null;
  }
}