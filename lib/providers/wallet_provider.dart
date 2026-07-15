// lib/providers/wallet_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../utils/phone_utils.dart';

class WalletProvider with ChangeNotifier {
  WalletModel? _wallet;
  List<TransactionModel> _transactions = [];
  List<Map<String, dynamic>> _incomingRequests = [];

  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _walletSub;
  StreamSubscription? _txSub;
  StreamSubscription? _requestSub;

  WalletModel? get wallet => _wallet;
  List<TransactionModel> get transactions => _transactions;
  List<Map<String, dynamic>> get incomingRequests => _incomingRequests;
  bool get isLoading => _isLoading;

  double get mainBalance => _wallet?.mainBalance ?? 0.0;
  double get bonusBalance => _wallet?.bonusBalance ?? 0.0;
  double get cashbackBalance => _wallet?.cashbackBalance ?? 0.0;
  double get commissionBalance => _wallet?.commissionBalance ?? 0.0;
  double get totalAvailable => _wallet?.totalAvailable ?? 0.0;

  // =========================
  // WALLET STREAMS (ISOLÉS)
  // =========================

  void listenToWallet(String? userId) {
    if (userId == null || userId.isEmpty) {
      debugPrint("🚨 [WALLET] Tentative de stream avec un UID nul ou vide. Abandon.");
      return;
    }

    _isLoading = true;
    notifyListeners();

    _walletSub?.cancel();
    _txSub?.cancel();

    debugPrint("🚀 [WALLET] Démarrage des streams pour : $userId");

    // 2. Stream Wallet
    _walletSub = FirebaseFirestore.instance
        .collection('wallets')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        _wallet = WalletModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        
        // Correction de robustesse
        final phone = _wallet?.phoneNumber;
        if (phone != null && phone.isNotEmpty) {
          listenToIncomingRequests(normalizePhoneNumber(phone));
        }
      }
      _isLoading = false;
      notifyListeners();
    }, onError: (e, stack) => _handleStreamError(e, stack, "wallets", userId));

    // 3. Stream Transactions
    _txSub = FirebaseFirestore.instance
        .collection('transactions')
        .where('participants', arrayContains: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      _transactions = snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
          .toList();
      notifyListeners();
    }, onError: (e, stack) => _handleStreamError(e, stack, "transactions", userId));
  }

  void listenToIncomingRequests(String userPhone) {
    _requestSub?.cancel();
    _requestSub = FirebaseFirestore.instance
        .collection('payment_requests')
        .where('toPhone', isEqualTo: normalizePhoneNumber(userPhone))
        .where('status', isEqualTo: 'en_attente')
        .snapshots()
        .listen((snapshot) {
      _incomingRequests = snapshot.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      notifyListeners();
    }, onError: (e, stack) => _handleStreamError(e, stack, "payment_requests", userPhone));
  }

  Future<void> _handleStreamError(
    dynamic e,
    StackTrace stack,
    String collection,
    String id,
  ) async {
    final user = _auth.currentUser;
    final currentUid = user?.uid;

    debugPrint("""
🚨 ERREUR FIRESTORE DETECTÉE
Collection : $collection
Target ID  : $id
Auth UID   : ${currentUid ?? "NON AUTHENTIFIÉ"}
Error      : $e
=========================
""");

    await Sentry.captureException(
      e,
      stackTrace: stack,
      withScope: (scope) {
        scope.setUser(SentryUser(id: currentUid));
        scope.setTag("stream", collection);
        scope.setTag("collection", collection);
        
        // Diagnostic amélioré
        if (e is FirebaseException) {
          scope.setExtra("firebaseCode", e.code);
          scope.setExtra("collection", collection);
          scope.setExtra("targetId", id);
          scope.setExtra("authenticatedUid", currentUid);
        }
        
        scope.setExtra("is_auth", user != null);
        scope.setExtra("error_type", e.runtimeType.toString());
      },
    );
  }

  @override
  void dispose() {
    _walletSub?.cancel();
    _txSub?.cancel();
    _requestSub?.cancel();
    super.dispose();
  }

  // ... (Reste des méthodes métier inchangées)
  
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
      debugPrint("🚨 [DEBUG] Erreur recherche tel: $e");
      return null;
    }
  }

  Future<void> requestWithdrawal({
    required double amount,
    required double fee,
    required String accountInfo,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('processWithdrawal');
      await callable.call({'amount': amount, 'fee': fee, 'accountInfo': accountInfo});
    } catch (e) {
      debugPrint("🚨 Erreur retrait: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
      debugPrint("Erreur rejet: $e");
    }
  }

  Future<void> refreshAll(String userId) async {
    listenToWallet(userId);
  }
}