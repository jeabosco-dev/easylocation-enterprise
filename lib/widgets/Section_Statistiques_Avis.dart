import 'package:flutter/material.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/widgets/rating_widget.dart'; // Import indispensable

class SectionStatistiquesAvis extends StatelessWidget {
  final Property property; 
  const SectionStatistiquesAvis({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Le grand score en haut
              Text(
                property.averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 40, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.indigo
                ),
              ),
              // Ton nouveau widget standardisé
              RatingWidget(
                averageRating: property.averageRating.toDouble(),
                count: property.ratingCount,
                starSize: 20,
              ),
            ],
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "Score basé sur la fiabilité", 
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: Colors.blueGrey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  property.ratingCount > 0 ? "${property.ratingCount} avis" : "Aucun avis", 
                  style: const TextStyle(color: Colors.grey, fontSize: 13)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}