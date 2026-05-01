// lib/widgets/community_progress_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/community_goal_model.dart';

class CommunityProgressCard extends StatelessWidget {
  final CommunityGoalModel goal;

  const CommunityProgressCard({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    // 1. Calcul des états temporels
    final now = DateTime.now();
    final isExpired = now.isAfter(goal.deadline);
    
    // ✅ SÉCURITÉ : Si le challenge est expiré ET qu'il n'est pas débloqué (échec), on ne l'affiche plus.
    // On laisse l'affichage uniquement si c'est en cours OU si c'est réussi (pour célébrer).
    if (isExpired && !goal.isUnlocked) {
      return const SizedBox.shrink();
    }

    // Calcul des jours restants pour l'affichage
    final daysLeft = goal.deadline.difference(now).inDays;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec Badge Ville et Temps restant
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "OBJECTIF ${goal.ville.toUpperCase()}",
                    style: TextStyle(color: Colors.orange[900], fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  goal.isUnlocked 
                      ? "Succès ! 🎉" 
                      : (isExpired ? "Terminé" : "$daysLeft jours restants"),
                  style: TextStyle(
                    color: goal.isUnlocked ? Colors.green : (isExpired ? Colors.red : Colors.grey[600]), 
                    fontSize: 12,
                    fontWeight: goal.isUnlocked ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),

          // Message Dynamique
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _buildMessage(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.4),
            ),
          ),

          const SizedBox(height: 16),

          // Barre de Progression
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: goal.progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      goal.isUnlocked ? Colors.green : Colors.orange[700]!,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${goal.currentValue} réalisés", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text("But : ${goal.goalValue}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),

          // Footer avec Action
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  goal.isUnlocked ? Icons.lock_open : Icons.lock_outline,
                  color: goal.isUnlocked ? Colors.green : Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    goal.isUnlocked 
                      ? "Félicitations ! La remise est activée." 
                      : "Encore un effort pour débloquer les -${goal.rewardValue.toInt()}% !",
                    style: TextStyle(
                      color: goal.isUnlocked ? Colors.green[700] : Colors.grey[700],
                      fontSize: 12,
                      fontStyle: FontStyle.italic
                    ),
                  ),
                ),
                // On affiche le bouton INVITER uniquement si ce n'est pas encore fini
                if (!goal.isUnlocked && !isExpired)
                  TextButton(
                    onPressed: () {
                      // Logique de partage via share_plus
                    },
                    child: const Text("INVITER", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildMessage() {
    String action = "";
    switch (goal.type) {
      case MissionType.inscriptions: action = "inscriptions"; break;
      case MissionType.reservations: action = "réservations"; break;
      case MissionType.publications: action = "nouveaux biens immobiliers"; break;
    }
    return "Si nous atteignons ${goal.goalValue} $action, tout le monde profite de -${goal.rewardValue.toInt()}% sur les frais !";
  }
}