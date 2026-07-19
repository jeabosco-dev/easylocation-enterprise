// lib/widgets/admin/moderation_actions_widget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/property_model.dart';

class ModerationActionsWidget extends StatelessWidget {
  final Property property;

  const ModerationActionsWidget({super.key, required this.property});

  /// Méthode générique pour mettre à jour le statut de modération
  Future<void> _updateModerationStatus(BuildContext context, String newStatus, String reason) async {
    try {
      final String adminId = FirebaseAuth.instance.currentUser?.uid ?? 'inconnu';

      await FirebaseFirestore.instance
          .collection('proprietes')
          .doc(property.id)
          .update({
        'moderationStatus': newStatus,
        'moderationReason': reason,
        'moderationDate': FieldValue.serverTimestamp(),
        'moderatedBy': adminId,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Statut mis à jour : $newStatus"),
            backgroundColor: newStatus == 'visible' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur modération: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de la mise à jour"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Vérification du statut actuel
    bool isMasquee = property.moderationStatus == 'masquee';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8, top: 5),
          child: Text(
            "ACTIONS DE MODÉRATION",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.blueGrey,
                letterSpacing: 1.1),
          ),
        ),
        const SizedBox(height: 10),
        
        // Bouton dynamique selon le statut
        if (isMasquee)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green),
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.visibility),
            label: const Text("Remettre en ligne"),
            onPressed: () => _updateModerationStatus(context, 'visible', 'Remise en ligne par admin'),
          )
        else
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.visibility_off),
            label: const Text("Masquer la propriété"),
            onPressed: () => _updateModerationStatus(context, 'masquee', 'Masqué par admin'),
          ),
      ],
    );
  }
}