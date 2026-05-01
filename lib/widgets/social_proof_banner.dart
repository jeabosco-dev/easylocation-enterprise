import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';

class SocialProofBanner extends StatelessWidget {
  const SocialProofBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // On écoute les changements dans le ConfigService
    return Consumer<ConfigService>(
      builder: (context, config, child) {
        // Si les compteurs sont à zéro, on peut choisir de ne rien afficher 
        // ou d'afficher un message par défaut.
        if (config.totalLogesVille == 0 && config.ajoutsAujourdhuiVille == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              if (config.totalLogesVille > 0)
                Row(
                  children: [
                    const Icon(Icons.verified_user, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Plus de ${config.totalLogesVille} familles logées à ${config.nomVilleActive} via EasyLocation",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              if (config.totalLogesVille > 0 && config.ajoutsAujourdhuiVille > 0)
                const Divider(height: 15, thickness: 0.5),
              if (config.ajoutsAujourdhuiVille > 0)
                Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "🔥 ${config.ajoutsAujourdhuiVille} nouvelles maisons ajoutées aujourd'hui à ${config.nomVilleActive}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}