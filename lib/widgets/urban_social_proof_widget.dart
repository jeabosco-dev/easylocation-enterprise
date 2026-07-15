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
              // Ajout de Expanded pour permettre au long texte de passer à la ligne sans erreur d'affichage
              Expanded(
                child: Text(
                  "Rejoignez plus de ${config.totalLocataires} locataires et ${config.totalBailleurs} bailleurs qui nous font confiance et utilisent EasyLocation au quotidien",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF0D47A1),
                  ),
                  textAlign: TextAlign.center, // Centrage pour un design plus propre sur plusieurs lignes
                ),
              ),
            ],
          ),
          const SizedBox(height: 6), // Léger ajustement de l'espacement
          const Text(
            "Statistiques officielles certifiées par EasyLocation",
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}