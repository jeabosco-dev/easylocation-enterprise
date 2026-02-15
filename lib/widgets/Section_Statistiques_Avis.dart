import 'package:flutter/material.dart';
import 'package:easylocation_mvp/models/property_model.dart';

class SectionStatistiquesAvis extends StatelessWidget {
  final Property property; 
  const SectionStatistiquesAvis({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final double moyenne = property.averageRating;
    final int totalVotants = property.ratingCount;

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    moyenne.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 40, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.indigo
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6.0, left: 4),
                    child: Text("/ 5", style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < moyenne.floor() 
                        ? Icons.star 
                        : (index < moyenne ? Icons.star_half : Icons.star_border),
                    color: Colors.amber, 
                    size: 20,
                  );
                }),
              ),
            ],
          ),
          // Ajustement pour aligner le texte "Score basé sur la viabilité"
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
                    fontSize: 12, // Taille ajustée pour que ça tienne sur une ligne si possible
                  ),
                ),
                Text(
                  totalVotants > 0 ? "$totalVotants avis" : "Aucun avis", 
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
