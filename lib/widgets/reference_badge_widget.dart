// lib/widgets/reference_badge_widget.dart

import 'package:flutter/material.dart';

class ReferenceBadgeWidget extends StatelessWidget {
  /// Le code de référence pur (ex: V84K9) passé par le modèle
  final String reference;

  const ReferenceBadgeWidget({
    super.key,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ Icône '#' discrète pour le look "ID/Tag"
          Icon(Icons.tag, size: 12, color: Colors.grey[600]),
          
          const SizedBox(width: 4),
          
          // ✅ Ajout du libellé "Réf :" ici (Gestion centralisée de la vue)
          Text(
            "Réf : $reference",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}