import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'maxicash_webview.dart'; 

class MaxicashService {
  static Future<void> encaisserAcompte({
    required BuildContext context, 
    required String telephone,
    required String referenceCommande, 
    VoidCallback? onSuccess,
    VoidCallback? onCancel,
  }) async {
    
    String formattedPhone = telephone.replaceAll(RegExp(r'[^0-9]'), '');

    debugPrint("--- APPEL MAXICASH SERVICE ---");
    debugPrint("Facture ID: $referenceCommande");

    if (formattedPhone.isEmpty) {
      _showError(context, "Erreur : Numéro de téléphone invalide.");
      return;
    }

    _showLoading(context);

    try {
      // 1. Appel de la Cloud Function
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('generateMaxicashUrl');

      final response = await callable.call({
        'factureId': referenceCommande, 
        'telephone': formattedPhone,
      });

      // 2. Fermeture propre du loader AVANT de lancer la suite
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); 
      }

      // 3. Micro-pause (200ms) pour stabiliser le moteur graphique
      await Future.delayed(const Duration(milliseconds: 200));

      final String? paymentUrl = response.data['url'];

      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw Exception("L'URL de paiement renvoyée est vide.");
      }

      // 4. Navigation vers la WebView
      if (context.mounted) {
        await Navigator.push(
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
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      debugPrint("❌ Erreur Cloud Function: [${e.code}] - ${e.message}");
      _showError(context, "Erreur validation : ${e.message}");
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
                SizedBox(height: 5),
                Text("Veuillez patienter", style: TextStyle(fontSize: 12, color: Colors.grey)),
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