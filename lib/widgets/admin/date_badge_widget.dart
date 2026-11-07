// lib/widgets/admin/date_badge_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/utils/date_helper.dart';

class DateBadgeWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const DateBadgeWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Récupération sécurisée du Timestamp (createdAt, updatedAt ou datePaiement)
    String dateFormatee = "Date N/A";
    Timestamp? timestamp = data['createdAt'] ?? data['updatedAt'] ?? data['datePaiement'];
    
    if (timestamp != null) {
      DateTime dt = timestamp.toDate();
      dateFormatee = "${DateHelper.formatShortDate(dt)} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade200, // Petit fond discret pour le détacher
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, size: 13, color: Color(0xFF0D47A1)), // Icône en bleu pro
          const SizedBox(width: 5),
          Text(
            dateFormatee, 
            style: const TextStyle(
              fontSize: 12, // Légèrement plus grand
              color: Colors.black87, // Texte plus foncé pour une lisibilité parfaite
              fontWeight: FontWeight.w600, // Un peu plus gras
            ),
          ),
        ],
      ),
    );
  }
}