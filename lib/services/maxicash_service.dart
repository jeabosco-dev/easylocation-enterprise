// lib/services/maxicash_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'maxicash_webview.dart'; 

class MaxicashService {
  static Future<void> encaisserAcompte({
    required BuildContext context, 
    required String telephone,
    required String referenceCommande, 
    required double montant, // Montant de base (souvent le total)
    required String ville, // ✅ Requis pour le tracking géographique
    double? montantOverride, // ✅ Permet de forcer un montant (ex: Reste à payer après Wallet)
    VoidCallback? onSuccess,
    VoidCallback? onCancel,
  }) async {
    
    // Priorité au montantOverride s'il existe, sinon on prend le montant classique
    final double montantFinal = montantOverride ?? montant;

    // Nettoyage du numéro (garde uniquement les chiffres)
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
      // 1. Appel de la Cloud Function sur la région europe-west1
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('generateMaxicashUrl');

      // ✅ AJOUT SÉCURITÉ : Timeout de 30 secondes pour pallier le Cold Start et la latence API
      final response = await callable.call({
        'factureId': referenceCommande, 
        'telephone': formattedPhone, 
        'amountOverride': montantFinal, 
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception("Le serveur de paiement met trop de temps à répondre. Veuillez réessayer.");
        },
      );

      // 2. Fermeture du loader
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); 
      }

      await Future.delayed(const Duration(milliseconds: 200));

      final String? paymentUrl = response.data['url'];

      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw Exception("L'URL de paiement renvoyée est vide.");
      }

      // 🚨 BLOC DE DEBUG DE L'URL REÇUE CÔTÉ FLUTTER
      debugPrint("========== URL MAXICASH ==========");
      debugPrint(paymentUrl);
      debugPrint("==================================");

      // 3. Navigation vers la WebView
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaxicashWebView(
              initialUrl: paymentUrl,
              ville: ville, // ✅ TRANSMISSION : On envoie la ville à la WebView
              onSuccess: onSuccess,
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
      
      // Si c'est l'exception du timeout qu'on a levée plus haut, on affiche son message explicite
      final String errorMsg = e.toString().contains("temps à répondre") 
          ? "Le serveur de paiement met trop de temps à répondre. Veuillez réessayer."
          : "Impossible d'initialiser le paiement.";
          
      _showError(context, errorMsg);
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