// lib/widgets/badge_statut_propriete.dart

import 'package:flutter/material.dart';
// ✅ On cache PropertyStatus du modèle pour éviter le conflit avec les constantes globales
import 'package:easylocation_mvp/models/property_model.dart' hide PropertyStatus;
import 'package:easylocation_mvp/constants/all_constants.dart';

class BadgeStatutPropriete extends StatelessWidget {
  final String status;

  const BadgeStatutPropriete({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    // ✅ Normalisation
    final String s = status.trim().toLowerCase();

    // --- LOGIQUE DE COULEURS ET LABELS ---
    if (s == PropertyStatus.disponible) {
      color = Colors.green.shade600;
      label = "LIBRE";
      icon = Icons.check_circle_outline;
    } 
    else if (s == PropertyStatus.booking) {
      color = Colors.orange.shade800;
      label = "EN COURS..."; 
      icon = Icons.timer_outlined;
    } 
    // ✅ AJOUT SÉCURISÉ : Gestion du statut En Attente de Paiement / Validation
    else if (s == PropertyStatus.enAttentePaiement) {
      color = Colors.amber.shade800; 
      label = "TRAITEMENT PAIEMENT"; 
      icon = Icons.hourglass_empty_rounded; 
    }
    else if (s == PropertyStatus.reserved) {
      color = Colors.red.shade700; // Rouge : Attention, réservé pour visite !
      label = "RÉSERVÉ";
      icon = Icons.lock_clock;
    } 
    else if (s == PropertyStatus.rented || s == 'louée' || s == 'louee') {
      // ✅ Couleur Gris Foncé / Noir pour "LOUÉ"
      color = const Color(0xFF212121); 
      label = "LOUÉ !";
      icon = Icons.task_alt; // Icône de succès terminé
    }
    else if (s == 'archive' || s == 'archivé') {
      color = Colors.blueGrey.shade400;
      label = "ARCHIVÉ";
      icon = Icons.archive_outlined;
    }
    else {
      color = Colors.grey.shade600;
      label = "INCONNU";
      icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.95),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}