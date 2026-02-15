import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'maxicash_webview.dart'; // Importation du fichier widget créé ci-dessous

class MaxicashService {
  static Future<void> encaisserAcompte({
    required BuildContext context, 
    required double montant,
    required String devise,
    required String telephone,
    required String referenceCommande,
    VoidCallback? onSuccess,
    VoidCallback? onCancel,
  }) async {
    try {
      // --- PETITE CORRECTION ICI ---
      // On s'assure que le téléphone commence par '+'
      String formattedPhone = telephone.trim();
      if (!formattedPhone.startsWith('+')) {
        formattedPhone = '+$formattedPhone';
      }

      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('generateMaxicashUrl');

      // On envoie les données avec les clés EXACTES attendues par ton index.js
      final response = await callable.call(<String, dynamic>{
        'montant': montant,
        'devise': devise,
        'telephone': formattedPhone, // On envoie le téléphone formaté
        'reference': referenceCommande,
      });

      final String? paymentUrl = response.data['url'];

      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw Exception("L'URL de paiement n'a pas pu être générée.");
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaxicashWebView(
              initialUrl: paymentUrl,
              onSuccess: onSuccess,
              onCancel: onCancel,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ ERREUR MAXICASH SERVICE : $e");
      // Ici tu pourrais afficher une alerte à l'utilisateur
      rethrow;
    }
  }
}
