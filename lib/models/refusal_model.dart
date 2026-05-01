import 'package:cloud_firestore/cloud_firestore.dart';

class RefusalModel {
  final String id;
  final String propertyId;
  final String locataireId;
  final String agentId;
  final String reason; // ex: 'Humidité', 'Prix', 'Taille'
  final String comment;
  final DateTime timestamp;

  RefusalModel({
    required this.id,
    required this.propertyId,
    required this.locataireId,
    required this.agentId,
    required this.reason,
    required this.comment,
    required this.timestamp,
  });

  /// --- CONVERSION VERS FIRESTORE ---
  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'locataireId': locataireId,
      'agentId': agentId,
      'reason': reason,
      'comment': comment,
      // Utilisation du temps serveur pour une précision maximale
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  /// --- RÉCUPÉRATION DEPUIS FIRESTORE ---
  factory RefusalModel.fromMap(Map<String, dynamic> map, String docId) {
    return RefusalModel(
      id: docId,
      propertyId: map['propertyId'] ?? '',
      locataireId: map['locataireId'] ?? '',
      agentId: map['agentId'] ?? '',
      reason: map['reason'] ?? '',
      comment: map['comment'] ?? '',
      // Sécurité anti-crash : vérifie si le timestamp existe et est valide
      timestamp: map['timestamp'] is Timestamp 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}