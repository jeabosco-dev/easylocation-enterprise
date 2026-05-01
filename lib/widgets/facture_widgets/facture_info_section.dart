import 'package:flutter/material.dart';
import '../../models/facture_model.dart';

class FactureInfoSection extends StatelessWidget {
  final FactureModel facture;

  const FactureInfoSection({
    super.key, 
    required this.facture,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoColumn(
            "CLIENT", 
            facture.nomClient, 
            facture.telClient,
          ),
        ),
        Expanded(
          child: _buildInfoColumn(
            "REF. MAISON", 
            facture.refMaison, 
            facture.nomOffre, 
            isRight: true,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoColumn(String titre, String nom, String info, {bool isRight = false}) {
    return Column(
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          titre,
          style: const TextStyle(
            fontSize: 9, 
            color: Colors.grey, 
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          nom,
          style: const TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 13,
          ),
        ),
        Text(
          info,
          style: const TextStyle(
            fontSize: 11, 
            color: Colors.blue, 
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}