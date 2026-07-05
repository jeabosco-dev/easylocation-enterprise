import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../utils/phone_utils.dart';

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

  // =========================
  // GETTERS SIMPLES
  // =========================

  double get mainBalance => _wallet?.mainBalance ?? 0.0;
  double get bonusBalance => _wallet?.bonusBalance ?? 0.0;
  double get cashbackBalance => _wallet?.cashbackBalance ?? 0.0;
  double get commissionBalance => _wallet?.commissionBalance ?? 0.0;
  double get totalAvailable => _wallet?.totalAvailable ?? 0.0;

  // =========================
  // WALLET STREAM
  // =========================

  void listenToWallet(String userId) {
    _isLoading = true;
    notifyListeners();

    FirebaseFirestore.instance
        .collection('wallets')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        _wallet = WalletModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );

        if (_wallet?.phoneNumber != null) {
          listenToIncomingRequests(normalizePhoneNumber(_wallet!.phoneNumber));
        }
      }
      _isLoading = false;
      notifyListeners();
    });

    // REQUÊTE MODIFIÉE : Récupère toutes les transactions où l'utilisateur est impliqué (sender ou receiver)
    FirebaseFirestore.instance
        .collection('transactions')
        .where('participants', arrayContains: userId) 
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      _transactions = snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
          .toList();
      notifyListeners();
    });
  }

  // =========================
  // RECHERCHE UTILISATEUR
  // =========================

  Future<String?> getUserNameByPhone(String phone) async {
    try {
      final normalized = normalizePhoneNumber(phone);
      final q = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .where('telephone', isEqualTo: normalized)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (q.docs.isNotEmpty) {
        final data = q.docs.first.data();
        return "${data['prenom'] ?? ''} ${data['nom'] ?? ''}".trim();
      }
      return null;
    } catch (e) {
      debugPrint("🚨 [DEBUG] Erreur: $e");
      return null;
    }
  }

  // =========================
  // PAIEMENT HYBRIDE
  // =========================

  Future<Map<String, dynamic>> payForServiceViaCloud({
    required String serviceId,
    required String serviceType,
    required double walletAmountRequested,
    required double totalAmountToPay,
    Map<String, dynamic>? metadata,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('initiateHybridPayment');
      final result = await callable.call({
        'serviceId': serviceId,
        'serviceType': serviceType,
        'walletAmountRequested': walletAmountRequested,
        'totalAmountToPay': totalAmountToPay,
        'metadata': metadata ?? {},
      });
      return Map<String, dynamic>.from(result.data);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================
  // TRANSFERTS
  // =========================

  Future<void> sendCreditsToUser({
    required String receiverPhone,
    required double amount,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('transferCredits');
    await callable.call({
      'receiverPhone': normalizePhoneNumber(receiverPhone),
      'amount': amount,
    });
  }

  Future<void> sendCreditsFromPartner({
    required String partnerId,
    required String receiverPhone,
    required double amount,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('sendCreditsFromPartner');
    await callable.call({
      'partnerId': partnerId,
      'receiverPhone': normalizePhoneNumber(receiverPhone),
      'amount': amount,
    });
  }

  // =========================
  // REQUEST SYSTEM (MIS À JOUR)
  // =========================

  void listenToIncomingRequests(String userPhone) {
    FirebaseFirestore.instance
        .collection('payment_requests')
        .where('toPhone', isEqualTo: normalizePhoneNumber(userPhone))
        .where('status', isEqualTo: 'en_attente')
        .snapshots()
        .listen((snapshot) {
      _incomingRequests = snapshot.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      notifyListeners();
    });
  }

  Future<void> createPaymentRequest({
    required String receiverPhone,
    required double amount,
  }) async {
    final userId = _auth.currentUser!.uid;
    final normalizedReceiverPhone = normalizePhoneNumber(receiverPhone);

    final senderDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(userId).get();
    final senderData = senderDoc.data();
    final senderName = "${senderData?['prenom'] ?? ''} ${senderData?['nom'] ?? 'Utilisateur'}".trim();
    final senderPhone = senderData?['telephone'] ?? '';

    final receiverQuery = await FirebaseFirestore.instance
        .collection('utilisateurs')
        .where('telephone', isEqualTo: normalizedReceiverPhone)
        .limit(1)
        .get();
    
    String receiverName = "Destinataire";
    if (receiverQuery.docs.isNotEmpty) {
      final rData = receiverQuery.docs.first.data();
      receiverName = "${rData['prenom'] ?? ''} ${rData['nom'] ?? ''}".trim();
    }

    await FirebaseFirestore.instance.collection('payment_requests').add({
      'fromId': userId,
      'senderName': senderName,
      'senderPhone': senderPhone, 
      'toPhone': normalizedReceiverPhone,
      'receiverName': receiverName,
      'amount': amount,
      'status': 'en_attente',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptPaymentRequest(Map<String, dynamic> request) async {
    await sendCreditsToUser(
      receiverPhone: request['senderPhone'], 
      amount: (request['amount'] as num).toDouble(),
    );

    await FirebaseFirestore.instance
        .collection('payment_requests')
        .doc(request['id'])
        .update({'status': 'accepted'});
    
    notifyListeners();
  }

  Future<void> rejectPaymentRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(requestId)
          .update({'status': 'rejected'});
      
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur lors du rejet: $e");
    }
  }

  // =========================
  // UTILITIES
  // =========================
  Future<void> refreshAll(String userId) async {
    listenToWallet(userId);
  }
}