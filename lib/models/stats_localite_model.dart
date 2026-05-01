import 'package:cloud_firestore/cloud_firestore.dart';

class StatsLocaliteModel {
  final String id; // L'ID sera le nom du quartier ou de la commune
  final int avgHours; // Temps moyen de location en heures
  final int totalRented; // Nombre total de biens loués dans cette zone
  final DateTime lastUpdate;

  StatsLocaliteModel({
    required this.id,
    required this.avgHours,
    required this.totalRented,
    required this.lastUpdate,
  });

  factory StatsLocaliteModel.fromMap(Map<String, dynamic> map, String id) {
    // Sécurisation de la conversion du Timestamp
    DateTime dateValue = DateTime.now();
    if (map['last_update'] != null && map['last_update'] is Timestamp) {
      dateValue = (map['last_update'] as Timestamp).toDate();
    }

    return StatsLocaliteModel(
      id: id,
      avgHours: map['avg_hours'] ?? 0,
      totalRented: map['total_rented'] ?? 0,
      lastUpdate: dateValue,
    );
  }

  // Optionnel : Pour faciliter le débogage
  @override
  String toString() => 'StatsLocalite(id: $id, avg: ${avgHours}h)';
}