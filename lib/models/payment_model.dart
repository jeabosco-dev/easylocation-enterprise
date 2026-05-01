import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final DateTime dateOperation;
  final double montantTotal;
  final int nbMoisPayes;
  final String typePaiement;
  // Nouveaux champs pour la compatibilité avec pdf_service
  final double? soldeRestant;
  final String? periodeConcerns;

  PaymentModel({
    required this.id,
    required this.dateOperation,
    required this.montantTotal,
    required this.nbMoisPayes,
    required this.typePaiement,
    this.soldeRestant,
    this.periodeConcerns,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return PaymentModel(
      id: id,
      dateOperation: (map['dateOperation'] as Timestamp).toDate(),
      montantTotal: (map['montantTotal'] ?? 0).toDouble(),
      nbMoisPayes: map['nbMoisPayes'] ?? 0,
      typePaiement: map['typePaiement'] ?? 'CASH',
      // Récupération des nouveaux champs depuis Firestore s'ils existent
      soldeRestant: (map['soldeRestant'] ?? 0).toDouble(),
      periodeConcerns: map['periodeConcerns'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dateOperation': dateOperation,
      'montantTotal': montantTotal,
      'nbMoisPayes': nbMoisPayes,
      'typePaiement': typePaiement,
      'soldeRestant': soldeRestant,
      'periodeConcerns': periodeConcerns,
    };
  }
}