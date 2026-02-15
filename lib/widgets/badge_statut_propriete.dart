// lib/widgets/badge_statut_propriete.dart

import 'package:flutter/material.dart';

// ✅ On cache PropertyStatus du modèle pour éviter le conflit avec constants.dart
import 'package:easylocation_mvp/models/property_model.dart' hide PropertyStatus;

// ✅ Importation des constantes pour une source de vérité unique
import 'package:easylocation_mvp/constants/constants.dart'; 

class BadgeStatutPropriete extends StatelessWidget {
  final String statut;

  const BadgeStatutPropriete({super.key, required this.statut});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    // ✅ Normalisation pour éviter les erreurs d'espaces
    final String statutNormalise = statut.trim();

    // --- LOGIQUE DE COULEURS ET LABELS BASÉE SUR LES CONSTANTES ---
    if (statutNormalise == PropertyStatus.disponible) {
      color = Colors.green.shade600;
      label = PropertyStatus.getLabel(PropertyStatus.disponible);
      icon = Icons.check_circle_outline;
    } 
    else if (statutNormalise == PropertyStatus.booking) {
      color = Colors.orange.shade800;
      label = PropertyStatus.getLabel(PropertyStatus.booking); 
      icon = Icons.timer_outlined;
    } 
    else if (statutNormalise == PropertyStatus.reserved) {
      color = Colors.red.shade700;
      label = PropertyStatus.getLabel(PropertyStatus.reserved);
      icon = Icons.lock_clock;
    } 
    else if (statutNormalise == PropertyStatus.rented) {
      color = const Color(0xFF424242); // Gris foncé pour les biens déjà loués
      label = PropertyStatus.getLabel(PropertyStatus.rented);
      icon = Icons.home_work_rounded;
    } 
    else {
      // Cas de sécurité (ex: si une valeur bizarre arrive de Firestore)
      color = Colors.grey.shade600;
      label = "STATUT INCONNU";
      icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
