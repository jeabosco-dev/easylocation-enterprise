// lib/services/goal_tracking_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // ✅ Import indispensable pour debugPrint
import '../models/community_goal_model.dart';
import '../constants/constants.dart';

class GoalTrackingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ✅ MÉTHODE UNIVERSELLE : Incrémente un challenge en cours avec sécurité temporelle
  Future<void> trackAction({
    required String ville,
    required MissionType type,
  }) async {
    try {
      final now = Timestamp.now();
      
      QuerySnapshot snapshot = await _db.collection('community_goals')
          .where('statut', isEqualTo: 'en_cours')
          .where('type', isEqualTo: type.toString().split('.').last)
          .where('deadline', isGreaterThan: now)
          .get();

      if (snapshot.docs.isEmpty) return;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        if (data.containsKey('date_debut')) {
          Timestamp dateDebut = data['date_debut'];
          if (now.seconds < dateDebut.seconds) continue; 
        }

        String goalVille = data['ville'] ?? 'National';

        if (goalVille == "National" || goalVille.trim().toLowerCase() == ville.trim().toLowerCase()) {
          
          await _db.runTransaction((transaction) async {
            DocumentSnapshot freshSnap = await transaction.get(doc.reference);
            int current = freshSnap['current_value'] ?? 0;
            int goal = freshSnap['goal_value'] ?? 0;

            transaction.update(doc.reference, {
              'current_value': FieldValue.increment(1),
              'last_update': FieldValue.serverTimestamp(),
            });

            if (current + 1 >= goal) {
              transaction.update(doc.reference, {'statut': 'atteint'});
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur GoalTracking: $e"); // ✅ Maintenant ça fonctionne !
    }
  }
}