// lib/models/refusal_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

class RefusalModel {
  final String id;
  final String propertyId;
  final String locataireId;
  final String agentTerrainId; // ✅ ALIGNÉ : Unique identifiant pour le suivi terrain
  final String reason; // ex: 'Humidité', 'Prix', 'Taille'
  final String comment;
  final DateTime timestamp;

  RefusalModel({
    required this.id,
    required this.propertyId,
    required this.locataireId,
    required this.agentTerrainId,
    required this.reason,
    required this.comment,
    required this.timestamp,
  });

  /// --- CONVERSION VERS FIRESTORE ---
  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'locataireId': locataireId,
      // ✅ Utilisation stricte de la constante unifiée
      FactureFields.agentTerrainId: agentTerrainId, 
      'reason': reason,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  /// --- RÉCUPÉRATION DEPUIS FIRESTORE ---
  factory RefusalModel.fromMap(Map<String, dynamic> map, String docId) {
    return RefusalModel(
      id: docId,
      propertyId: map['propertyId'] ?? '',
      locataireId: map['locataireId'] ?? '',
      // ✅ Lecture directe et stricte via la constante globale
      agentTerrainId: map[FactureFields.agentTerrainId] ?? '',
      reason: map['reason'] ?? '',
      comment: map['comment'] ?? '',
      timestamp: map['timestamp'] is Timestamp 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}