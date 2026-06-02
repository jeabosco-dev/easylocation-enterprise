// lib/services/goal_tracking_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; 
import '../models/community_goal_model.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

class GoalTrackingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ✅ MÉTHODE UNIVERSELLE : Incrémente un challenge en cours avec sécurité temporelle et anti-concurrence
  Future<void> trackAction({
    required String ville,
    required MissionType type,
  }) async {
    try {
      final now = Timestamp.now();
      
      // 1. Récupération des objectifs potentiels
      QuerySnapshot snapshot = await _db.collection('community_goals')
          .where('statut', isEqualTo: 'en_cours')
          .where('type', isEqualTo: type.toString().split('.').last)
          .where('deadline', isGreaterThan: now)
          .get();

      if (snapshot.docs.isEmpty) return;

      final String cleanVille = ville.trim().toLowerCase();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Sécurité sur la date de début du challenge
        if (data.containsKey('date_debut')) {
          Timestamp dateDebut = data['date_debut'];
          if (now.seconds < dateDebut.seconds) continue; 
        }

        String goalVille = (data['ville'] ?? 'National').toString().trim().toLowerCase();

        // ✅ Votre excellente logique de comparaison insensible à la casse et aux espaces
        if (goalVille == "national" || goalVille == cleanVille) {
          
          // ✅ Transaction Firestore isolée par document pour éviter les blocages de boucle
          await _db.runTransaction((transaction) async {
            DocumentSnapshot freshSnap = await transaction.get(doc.reference);
            
            if (!freshSnap.exists) return;

            // Lecture des données fraîches de la base de données
            int current = freshSnap['current_value'] ?? 0;
            int goal = freshSnap['goal_value'] ?? 0;
            int nextValue = current + 1;

            // Préparation des champs à mettre à jour
            Map<String, dynamic> updates = {
              'current_value': nextValue,
              'last_update': FieldValue.serverTimestamp(),
            };

            // ✅ Si le palier est atteint, on change le statut dans la même écriture
            if (nextValue >= goal) {
              updates['statut'] = 'atteint';
            }

            transaction.update(doc.reference, updates);
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur GoalTracking: $e"); 
    }
  }
}