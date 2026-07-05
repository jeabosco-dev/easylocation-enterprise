// lib/models/transaction_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Définit les types de mouvements d'argent possibles
enum TransactionType {
  depot,
  paiementCommission,
  remboursement,
  retrait,
  ajustement,
  refund_request,    // ✅ Pour correspondre au Provider
  service_payment    // ✅ Pour les achats de services/pub
}

/// Définit l'état de la transaction
enum TransactionStatus {
  success,
  pending,
  failed,
  en_attente // ✅ Pour la synchro Admin
}

class TransactionModel {
  final String id;
  final String walletId; 
  final String userId; 

  final String? senderId;
  final String? senderName;
  final String? receiverId;
  final String? receiverName;

  final TransactionType type;
  final double amount;
  final String? titleFromData; 
  final String referenceFacture; 
  final String? referenceContrat; // ✅ Ajouté pour l'uniformisation (Lien avec collection 'contrats')
  final TransactionStatus status;
  final DateTime date;
  final String? description; 

  TransactionModel({
    required this.id,
    required this.walletId,
    required this.userId,
    
    this.senderId,
    this.senderName,
    this.receiverId,
    this.receiverName,

    required this.type,
    required this.amount,
    this.titleFromData,
    required this.referenceFacture,
    this.referenceContrat, // Optionnel selon le type de transaction
    required this.status,
    required this.date,
    this.description,
  });

  // --- RÉCUPÉRATION DEPUIS FIRESTORE ---
  factory TransactionModel.fromMap(Map<String, dynamic> map, String docId) {
    return TransactionModel(
      id: docId,
      walletId: map['walletId'] ?? '',
      userId: map['userId'] ?? map['walletId'] ?? '', 
      
      senderId: map['senderId'],
      senderName: map['senderName'],
      receiverId: map['receiverId'],
      receiverName: map['receiverName'],
      
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.ajustement,
      ),
      amount: (map['amount'] ?? 0).toDouble(),
      titleFromData: map['title'], 
      referenceFacture: map['referenceFacture'] ?? '',
      // ✅ Lecture du contrat avec fallback pour éviter les crashs si absent
      referenceContrat: map['referenceContrat'] ?? map['contractId'], 
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TransactionStatus.pending,
      ),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: map['description'],
    );
  }

  // --- EXPORT VERS FIRESTORE ---
  Map<String, dynamic> toMap() {
    return {
      'walletId': walletId,
      'userId': userId,
      
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      
      'type': type.name,
      'amount': amount,
      'title': titleFromData,
      'referenceFacture': referenceFacture,
      'referenceContrat': referenceContrat, // ✅ Nom uniformisé en français
      'status': status.name,
      'date': Timestamp.fromDate(date),
      'description': description,
    };
  }

  // --- UI HELPERS ---

  /// Retourne un titre lisible
  String get title {
    if (titleFromData != null && titleFromData!.isNotEmpty) {
      return titleFromData!;
    }

    switch (type) {
      case TransactionType.depot:
        return "Dépôt effectué";
      case TransactionType.paiementCommission:
        return "Paiement Commission";
      case TransactionType.remboursement:
        return "Remboursement Visite";
      case TransactionType.retrait:
      case TransactionType.refund_request:
        return "Retrait de fonds";
      case TransactionType.service_payment:
        return "Achat Service/Pub";
      case TransactionType.ajustement:
        return "Ajustement de solde";
    }
  }

  /// Indique si c'est une entrée d'argent (Couleur Verte dans l'UI)
  bool get isPositive {
    return type == TransactionType.depot || 
           type == TransactionType.remboursement;
  }
}