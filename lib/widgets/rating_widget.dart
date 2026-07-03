// lib/widgets/rating_widget.dart

import 'package:flutter/material.dart';

class RatingWidget extends StatelessWidget {
  final double averageRating;
  final int count;
  final double starSize;

  const RatingWidget({
    super.key,
    required this.averageRating,
    required this.count,
    this.starSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Affichage des étoiles
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            return Icon(
              index < averageRating.round() ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: starSize,
            );
          }),
        ),
        
        const SizedBox(width: 4),

        // Texte de la note : on retire Expanded/Flexible pour laisser la Row 
        // s'ajuster au contenu (mainAxisSize: min)
        Text(
          "${averageRating.toStringAsFixed(1)} ($count)",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}