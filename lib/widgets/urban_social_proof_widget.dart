// lib/widgets/urban_social_proof_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';

class UrbanSocialProofWidget extends StatelessWidget {
  const UrbanSocialProofWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Écoute les changements dans ConfigService
    final config = context.watch<ConfigService>();

    // Règle d'audit : On ne montre rien si les données sont inférieures à 5
    if (config.totalLocataires < 5) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50]?.withOpacity(0.4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF0D47A1).withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_outlined,
                color: Color(0xFF0D47A1),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                "Rejoignez +${config.totalLocataires} citadins et +${config.totalBailleurs} propriétaires",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Statistiques officielles certifiées par EasyLocation",
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}