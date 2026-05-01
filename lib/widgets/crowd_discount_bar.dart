import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import 'package:intl/intl.dart';

class CrowdDiscountBar extends StatelessWidget {
  const CrowdDiscountBar({super.key});

  @override
  Widget build(BuildContext context) {
    // On récupère l'ID du challenge actif via le ConfigService
    final config = Provider.of<ConfigService>(context);
    final String? activeId = config.activeCommunityGoalId;

    // Si aucun challenge n'est configuré dans app_config, on n'affiche rien
    if (activeId == null || activeId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community_goals')
          .doc(activeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        
        // --- LOGIQUE DE SÉCURITÉ TEMPORELLE ---
        final DateTime deadline = (data['deadline'] as Timestamp).toDate();
        final bool isExpired = DateTime.now().isAfter(deadline);
        final String statut = data['statut'] ?? 'en_cours';

        // Si le challenge est expiré et n'a pas été atteint, on cache le widget
        if (isExpired && statut == 'en_cours') {
          return const SizedBox.shrink();
        }

        // --- CALCULS DE PROGRESSION ---
        final int goal = data['goal_value'] ?? 1;
        final int current = data['current_value'] ?? 0;
        final double progress = (current / goal).clamp(0.0, 1.0);
        final double reward = (data['reward_value'] as num).toDouble();
        final String titre = data['titre'] ?? "Objectif Communautaire";

        // Couleur dynamique : Vert si atteint, Orange si en cours
        final Color themeColor = statut == 'atteint' ? Colors.green : Colors.orange[800]!;

        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
            border: Border.all(color: themeColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      titre.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: themeColor,
                      ),
                    ),
                  ),
                  Text(
                    statut == 'atteint' ? "OBJECTIF ATTEINT ! 🎉" : "EN COURS",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      color: themeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                statut == 'atteint'
                    ? "Félicitations ! Tout le monde bénéficie de -$reward% sur les frais."
                    : "Si nous atteignons $goal réservations, -$reward% de remise pour TOUS !",
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: themeColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$current / $goal effectués",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Fin le ${DateFormat('dd/MM à HH:mm').format(deadline)}",
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}