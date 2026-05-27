// lib/providers/wallet_provider.dart

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
        .listen((doc) async {
      if (doc.exists) {
        _wallet = WalletModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        
        if (_wallet?.phoneNumber != null) {
          listenToIncomingRequests(_wallet!.phoneNumber);
        }
        _isLoading = false;
        notifyListeners();
      } else {
        // ✅ CRÉATION AUTOMATIQUE : Si le wallet n'existe pas
        await _createInitialWallet(userId);
      }
    });

    FirebaseFirestore.instance
        .collection('transactions')
        .where('walletId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      _transactions = snapshot.docs.map((doc) {
        return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      notifyListeners();
    });
  }

  /// Méthode privée pour initialiser un nouveau portefeuille
  Future<void> _createInitialWallet(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(userId).get();
      final userData = userDoc.data();
      
      await FirebaseFirestore.instance.collection('wallets').doc(userId).set({
        'userId': userId,
        'balance': 0.0,
        'bonusBalance': 0.0,
        'pendingRefund': 0.0,
        'accountType': userData?['role'] ?? 'locataire',
        'phoneNumber': userData?['phoneNumber'] ?? '',
        'lastUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Erreur lors de la création du wallet : $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // SECTION : PARTENARIAT & COMMISSIONS
  // ==========================================

  Future<void> sendCreditsFromPartner({
    required String partnerId, 
    required String receiverPhone, 
    required double amount
  }) async {
    final db = FirebaseFirestore.instance;

    final partnerDoc = await db.collection('partenaires').doc(partnerId).get();
    final String partnerName = partnerDoc.data()?['nom'] ?? "Un Partenaire";

    final receiverQuery = await db.collection('utilisateurs')
        .where('phoneNumber', isEqualTo: receiverPhone)
        .limit(1)
        .get();

    if (receiverQuery.docs.isEmpty) throw Exception("Destinataire introuvable.");
    
    final String receiverId = receiverQuery.docs.first.id;
    final receiverWalletRef = db.collection('wallets').doc(receiverId);
    final partnerRef = db.collection('partenaires').doc(partnerId);

    return db.runTransaction((transaction) async {
      final partnerSnap = await transaction.get(partnerRef);
      final receiverSnap = await transaction.get(receiverWalletRef);

      if (!partnerSnap.exists) throw Exception("Compte partenaire inexistant.");
      if (!receiverSnap.exists) throw Exception("Portefeuille destinataire non configuré.");

      double currentCommission = (partnerSnap.data()?['solde_commission'] ?? 0.0).toDouble();

      if (currentCommission < amount) throw Exception("Solde de commission insuffisant.");

      transaction.update(partnerRef, {
        'solde_commission': FieldValue.increment(-amount),
      });

      transaction.update(receiverWalletRef, {
        'bonusBalance': FieldValue.increment(amount),
        'lastUpdate': FieldValue.serverTimestamp(),
      });

      final txReceiver = db.collection('transactions').doc();
      transaction.set(txReceiver, {
        'walletId': receiverId,
        'userId': receiverId,
        'title': "Crédit reçu de $partnerName",
        'amount': amount,
        'isPositive': true,
        'date': FieldValue.serverTimestamp(),
        'type': 'partner_transfer', 
      });

      final auditRef = db.collection('audit_commissions').doc();
      transaction.set(auditRef, {
        'partnerId': partnerId,
        'type': 'CONVERSION_CREDIT',
        'amount': amount,
        'receiverPhone': receiverPhone,
        'receiverId': receiverId,
        'date': FieldValue.serverTimestamp(),
      });
    });
  }

  // ==========================================
  // SECTION : TRANSFERT & SOCIAL (LOGIQUE P2P)
  // ==========================================

  Future<String?> getUserNameByPhone(String phone) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('utilisateurs')
        .where('phoneNumber', isEqualTo: phone)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data()['displayName'] ?? "Utilisateur EasyLocation";
    }
    return null;
  }

  Future<void> sendCreditsToUser({required String receiverPhone, required double amount}) async {
    final String senderId = _auth.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    final senderDoc = await db.collection('utilisateurs').doc(senderId).get();
    final String senderName = senderDoc.data()?['displayName'] ?? "Un utilisateur";

    final senderWalletRef = db.collection('wallets').doc(senderId);
    
    final receiverQuery = await db.collection('utilisateurs')
        .where('phoneNumber', isEqualTo: receiverPhone)
        .limit(1)
        .get();

    if (receiverQuery.docs.isEmpty) throw Exception("Destinataire introuvable.");
    
    final String receiverId = receiverQuery.docs.first.id;
    final String receiverName = receiverQuery.docs.first.data()['displayName'] ?? "Destinataire";
    final receiverWalletRef = db.collection('wallets').doc(receiverId);

    return db.runTransaction((transaction) async {
      final senderSnap = await transaction.get(senderWalletRef);
      final receiverSnap = await transaction.get(receiverWalletRef);

      if (!senderSnap.exists || !receiverSnap.exists) throw Exception("Portefeuille introuvable.");

      double senderBal = (senderSnap.data()?['balance'] ?? 0.0).toDouble();
      
      // ✅ Utilisation sécurisée du bonus de l'UI (déjà nettoyé par fromMap si expiré)
      double senderBonus = _wallet != null ? _wallet!.bonusBalance : (senderSnap.data()?['bonusBalance'] ?? 0.0).toDouble();

      // Double vérification de sécurité sur le snap brut au cas où le provider n'est pas synchro
      DateTime? expiry = senderSnap.data()?['bonusExpiryDate'] is Timestamp
          ? (senderSnap.data()?['bonusExpiryDate'] as Timestamp).toDate()
          : null;
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        senderBonus = 0.0;
      }

      if ((senderBal + senderBonus) < amount) throw Exception("Solde total insuffisant.");

      double deductFromBonus = 0;
      double deductFromBalance = 0;

      if (senderBonus >= amount) {
        deductFromBonus = amount;
      } else {
        deductFromBonus = senderBonus;
        deductFromBalance = amount - deductFromBonus;
      }

      transaction.update(senderWalletRef, {
        'balance': FieldValue.increment(-deductFromBalance),
        'bonusBalance': FieldValue.increment(-deductFromBonus),
        'lastUpdate': FieldValue.serverTimestamp(),
      });

      transaction.update(receiverWalletRef, {
        'bonusBalance': FieldValue.increment(amount),
        'lastUpdate': FieldValue.serverTimestamp(),
      });

      final txSender = db.collection('transactions').doc();
      final txReceiver = db.collection('transactions').doc();

      transaction.set(txSender, {
        'walletId': senderId,
        'userId': senderId,
        'title': "Envoi à $receiverName",
        'amount': amount,
        'isPositive': false,
        'date': FieldValue.serverTimestamp(),
        'type': 'p2p_transfer',
      });

      transaction.set(txReceiver, {
        'walletId': receiverId,
        'userId': receiverId,
        'title': "Crédit reçu de $senderName",
        'amount': amount,
        'isPositive': true,
        'date': FieldValue.serverTimestamp(),
        'type': 'p2p_transfer', 
      });
    });
  }

  // ==========================================
  // SECTION : DEMANDES DE PAIEMENT
  // ==========================================

  Future<void> createPaymentRequest({required String receiverPhone, required double amount}) async {
    final String senderId = _auth.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(senderId).get();
    final String myName = userDoc.data()?['displayName'] ?? "Un utilisateur";

    await FirebaseFirestore.instance.collection('payment_requests').add({
      'fromId': senderId,
      'fromName': myName, 
      'toPhone': receiverPhone,
      'amount': amount,
      'status': 'en_attente',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void listenToIncomingRequests(String userPhone) {
    FirebaseFirestore.instance
        .collection('payment_requests')
        .where('toPhone', isEqualTo: userPhone)
        .where('status', isEqualTo: 'en_attente')
        .snapshots()
        .listen((snapshot) {
      _incomingRequests = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      notifyListeners();
    });
  }

  Future<void> acceptPaymentRequest(Map<String, dynamic> request) async {
    final senderDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(request['fromId']).get();
    final String? senderPhone = senderDoc.data()?['phoneNumber'];

    if (senderPhone == null) throw Exception("Impossible de trouver le numéro du demandeur.");

    await sendCreditsToUser(
      receiverPhone: senderPhone,
      amount: (request['amount'] as num).toDouble(),
    );

    await FirebaseFirestore.instance
        .collection('payment_requests')
        .doc(request['id'])
        .update({'status': 'accepte'});
  }

  Future<void> rejectPaymentRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection('payment_requests')
        .doc(requestId)
        .update({'status': 'refuse'});
  }

  // =================================================================
  // SECTION : SERVICES CLOUD HARMONISÉS (Anciennement payForService local)
  // =================================================================

  /// ✅ ÉVOLUTION MAJEURE : Utilise désormais la Cloud Function 'initiateHybridPayment'
  /// Cela permet d'inclure les points de fidélité et crédits bailleurs gérés par le backend.
  Future<HttpsCallableResult<dynamic>> payForServiceViaCloud({
    required String serviceId,
    required String serviceType,
    required double servicePrice,
    Map<String, dynamic>? metadata,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('initiateHybridPayment');
      
      final response = await callable.call(<String, dynamic>{
        'serviceId': serviceId,
        'serviceType': serviceType,
        'totalAmount': servicePrice,
        'metadata': metadata ?? {},
      });

      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Erreur payForServiceViaCloud: $e");
      rethrow;
    }
  }

  Future<void> requestRefund({required String userId, required double amount, required double serviceFee, required String paymentMethod}) async {
    final userDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(userId).get();
    final String userName = userDoc.data()?['displayName'] ?? 'Utilisateur';

    if (_wallet == null || _wallet!.balance < amount) throw Exception("Solde insuffisant.");

    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance.collection('wallets').doc(userId), {
      'balance': FieldValue.increment(-amount),
      'pendingRefund': FieldValue.increment(amount),
      'lastUpdate': FieldValue.serverTimestamp(),
    });
    batch.set(FirebaseFirestore.instance.collection('refund_requests').doc(), {
      'userId': userId, 'userName': userName, 'amount': amount, 'serviceFee': serviceFee,
      'netAmount': amount - serviceFee, 'paymentMethod': paymentMethod, 'status': 'en_attente',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(FirebaseFirestore.instance.collection('transactions').doc(), {
      'walletId': userId, 'userId': userId, 'title': 'Demande de retrait', 'amount': amount,
      'isPositive': false, 'date': FieldValue.serverTimestamp(), 'type': 'refund_request',
    });
    await batch.commit();
  }

  Future<void> refreshAll(String userId) async { listenToWallet(userId); }

  // ==========================================
  // SECTION : COMMANDE & PAIEMENT MIXTE CASH
  // ==========================================

  Future<String> initierPaiementCashMixte({
    required String bienId,
    required String refBien,
    required double montantTotal,
    required double montantWallet,
  }) async {
    final String userId = _auth.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    final walletRef = db.collection('wallets').doc(userId);
    final factureRef = db.collection('factures').doc();
    final bienRef = db.collection('properties').doc(bienId);

    final DateTime dateExpiration = DateTime.now().add(const Duration(hours: 2));

    await db.runTransaction((transaction) async {
      final walletSnap = await transaction.get(walletRef);
      final bienSnap = await transaction.get(bienRef);

      if (!walletSnap.exists) throw Exception("Portefeuille introuvable.");
      if (!bienSnap.exists) throw Exception("Le bien immobilier est introuvable.");

      double deductFromBonus = 0;
      double deductFromBalance = 0;

      if (montantWallet > 0) {
        double currentBalance = (walletSnap.data()?['balance'] ?? 0.0).toDouble();
        
        // ✅ SÉCURITÉ METIER ACCRUE : Analyse du snapshot Firestore direct pour bloquer la fraude au bonus
        double currentBonus = (walletSnap.data()?['bonusBalance'] ?? 0.0).toDouble();
        DateTime? expiry = walletSnap.data()?['bonusExpiryDate'] is Timestamp
            ? (walletSnap.data()?['bonusExpiryDate'] as Timestamp).toDate()
            : null;
            
        if (expiry != null && DateTime.now().isAfter(expiry)) {
          currentBonus = 0.0; // Le verrou de transaction Firestore invalide l'opération côté serveur
        }

        if ((currentBalance + currentBonus) < montantWallet) {
          throw Exception("Solde insuffisant pour couvrir la part numérique du paiement.");
        }

        if (currentBonus >= montantWallet) {
          deductFromBonus = montantWallet;
        } else {
          deductFromBonus = currentBonus;
          deductFromBalance = montantWallet - deductFromBonus;
        }

        transaction.update(walletRef, {
          'balance': FieldValue.increment(-deductFromBalance),
          'bonusBalance': FieldValue.increment(-deductFromBonus),
          'lastUpdate': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(factureRef, {
        'clientUid': userId,
        'propertyId': bienId,
        'refBien': refBien,
        'methodePaiement': 'cash',
        'status': 'pending',
        'montantTotal': montantTotal,
        'montantAPayer': montantTotal - montantWallet, 
        'montantWallet': montantWallet,               
        'dateCreation': FieldValue.serverTimestamp(),
        'dateExpiration': Timestamp.fromDate(dateExpiration),
        'rallongeCount': 0,
      });

      transaction.update(bienRef, {
        'status': 'en_attente_cash',
      });

      if (montantWallet > 0) {
        final txRef = db.collection('transactions').doc();
        transaction.set(txRef, {
          'walletId': userId,
          'userId': userId,
          'title': "Acompte Wallet (Réf: $refBien)",
          'amount': montantWallet,
          'isPositive': false,
          'date': FieldValue.serverTimestamp(),
          'type': 'cash_mixed_advance',
          'details': {
            'factureId': factureRef.id,
            'paidFromBonus': deductFromBonus,
            'paidFromBalance': deductFromBalance
          }
        });
      }
    });

    return factureRef.id;
  }
}