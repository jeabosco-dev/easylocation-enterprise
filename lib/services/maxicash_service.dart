// lib/services/maxicash_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'maxicash_webview.dart'; 

class MaxicashService {
  static Future<void> encaisserAcompte({
    required BuildContext context, 
    required String telephone,
    required String referenceCommande, 
    required double montant, 
    required String ville, 
    double? montantOverride, 
    VoidCallback? onSuccess,
    VoidCallback? onCancel,
  }) async {
    
    final double montantFinal = montantOverride ?? montant;

    // Nettoyage du numéro
    String formattedPhone = telephone.replaceAll(RegExp(r'[^0-9]'), '');

    debugPrint("--- APPEL MAXICASH SERVICE (ENTERPRISE) ---");
    debugPrint("Facture ID: $referenceCommande");
    debugPrint("Montant Final envoyé: $montantFinal \$");
    debugPrint("Tel envoyé: $formattedPhone");
    debugPrint("Ville pour tracking: $ville");

    if (formattedPhone.isEmpty) {
      _showError(context, "Erreur : Numéro de téléphone invalide.");
      return;
    }

    _showLoading(context);

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('generateMaxicashUrl');

      final response = await callable.call({
        'factureId': referenceCommande, 
        'telephone': formattedPhone, 
        'amountOverride': montantFinal, 
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception("Le serveur de paiement met trop de temps à répondre.");
        },
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); 
      }

      final String? paymentUrl = response.data['url'];

      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw Exception("L'URL de paiement renvoyée est vide.");
      }

      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaxicashWebView(
              initialUrl: paymentUrl,
              ville: ville,
              // Le onSuccess se contente de fermer la WebView
              onSuccess: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                if (onSuccess != null) onSuccess();
              },
              onCancel: onCancel,
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      debugPrint("❌ Erreur Cloud Function: [${e.code}] - ${e.message}");
      _showError(context, "Erreur MaxiCash : ${e.message}");
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      debugPrint("🚨 Erreur Inconnue Service: $e");
      _showError(context, "Impossible d'initialiser le paiement.");
    }
  }

  static void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 15),
                Text("Connexion à MaxiCash...", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showError(BuildContext context, String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg), 
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }
}