import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart'; // Pour la console de débogage

class GeminiService {
  // L'initialisation de l'API locale avec la clé dotenv est supprimée
  // car nous utilisons maintenant la Cloud Function.
  GeminiService();

  Future<String> correctCode(String codeContent) async {
    try {
      // ✅ MODIFICATION : On précise la région europe-west1 (Belgique)
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('getGeminiResponse');

      // Étape 2 : Créer le "prompt" complet pour l'IA.
      final fullPrompt = 'Je souhaite corriger le code Dart/Flutter que je vous fournis. '
                         'Actuellement, la logique du formulaire gère les options "en carrelé", "en ciment" et "autre". '
                         'Si l\'utilisateur choisit "en carrelé", une question pour une "photo du sol" apparaît. '
                         'Je veux que vous apportiez les corrections suivantes : '
                         '1. Peu importe l\'option choisie pour le type de sol, aucune question ne doit apparaître en conséquence. '
                         '2. Le libellé doit être changé de "photo du sol" à "photo du salon". '
                         '3. La question "photo du salon" doit être complètement indépendante et ne doit pas dépendre de la question sur le type de sol. '
                         'Merci de me retourner le code corrigé.'
                         '\n\n--- CODE À CORRIGER ---\n$codeContent';

      // Étape 3 : Appeler la Cloud Function et envoyer le prompt.
      final HttpsCallableResult result = await callable.call(<String, dynamic>{
        'prompt': fullPrompt,
      });

      // Étape 4 : Retourner la réponse de la fonction.
      return result.data['text'];
    } on FirebaseFunctionsException catch (e) {
      // Gérer les erreurs spécifiques à Firebase Cloud Functions.
      print('Erreur d\'appel de la Cloud Function : ${e.code}, ${e.details}, ${e.message}');
      return 'Erreur : Impossible de contacter le serveur.';
    } catch (e) {
      // Gérer toutes les autres erreurs.
      print('Une erreur inattendue est survenue : $e');
      return 'Erreur : Une erreur inattendue est survenue.';
    }
  }
}
