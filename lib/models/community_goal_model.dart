import 'package:cloud_firestore/cloud_firestore.dart';

enum MissionType { inscriptions, reservations, publications }

class CommunityGoalModel {
  final String id;
  final String titre;
  final String ville; 
  final MissionType type;
  final int goalValue;      // Objectif à atteindre
  final int currentValue;   // État actuel
  final double rewardValue; // Ex: 20 (pour 20%)
  final DateTime dateDebut; // ✅ Nouveau : Date de début du challenge
  final DateTime deadline;  // Date de fin
  final String statut;      // 'en_cours', 'atteint', 'expire'

  CommunityGoalModel({
    required this.id,
    required this.titre,
    required this.ville,
    required this.type,
    required this.goalValue,
    required this.currentValue,
    required this.rewardValue,
    required this.dateDebut, // ✅ Ajouté au constructeur
    required this.deadline,
    required this.statut,
  });

  // Calcul du pourcentage de progression pour la barre de progression
  double get progress => (currentValue / goalValue).clamp(0.0, 1.0);

  // Est-ce que l'objectif est débloqué ?
  bool get isUnlocked => currentValue >= goalValue;

  // Est-ce que le challenge est actuellement actif (entre les deux dates) ?
  bool get isPeriodActive {
    final now = DateTime.now();
    return now.isAfter(dateDebut) && now.isBefore(deadline);
  }

  factory CommunityGoalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Conversion sécurisée de l'enum
    MissionType mType = MissionType.reservations;
    try {
      mType = MissionType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type']
      );
    } catch (_) {
      mType = MissionType.reservations; // Valeur par défaut
    }

    return CommunityGoalModel(
      id: doc.id,
      titre: data['titre'] ?? '',
      ville: data['ville'] ?? 'National',
      type: mType,
      goalValue: data['goal_value'] ?? 0,
      currentValue: data['current_value'] ?? 0,
      rewardValue: (data['reward_value'] as num?)?.toDouble() ?? 0.0,
      // ✅ Récupération des deux timestamps
      dateDebut: (data['date_debut'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deadline: (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 7)),
      statut: data['statut'] ?? 'en_cours',
    );
  }

  // Méthode utilitaire pour convertir en Map (pour les envois Firestore si besoin)
  Map<String, dynamic> toMap() {
    return {
      'titre': titre,
      'ville': ville,
      'type': type.toString().split('.').last,
      'goal_value': goalValue,
      'current_value': currentValue,
      'reward_value': rewardValue,
      'date_debut': Timestamp.fromDate(dateDebut),
      'deadline': Timestamp.fromDate(deadline),
      'statut': statut,
    };
  }
}