import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // ✅ Utilisation directe

void main() async {
  try {
    // 1. Charger la clé API du fichier .env
    await dotenv.load(fileName: ".env");
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null) {
      print("❌ Erreur : GEMINI_API_KEY non trouvée dans le fichier .env");
      return;
    }

    // 2. Configurer le modèle Gemini localement pour le script
    final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);

    // 3. Lire le fichier à corriger
    final filePath = 'lib/screens/formulaire_de_mise_en_publication_page.dart';
    final file = File(filePath);
    if (!await file.exists()) {
      print("❌ Erreur : Fichier non trouvé à $filePath");
      return;
    }
    final codeContent = await file.readAsString();

    // 4. Préparer le prompt
    final prompt = [Content.text('''
      Agis comme un expert Flutter. Corrige le code suivant selon ces instructions :
      1. Peu importe l'option choisie pour le type de sol, aucune question ne doit apparaître en conséquence.
      2. Le libellé doit être changé de "photo du sol" à "photo du salon".
      3. La question "photo du salon" doit être indépendante.
      
      CODE À CORRIGER :
      $codeContent
    ''')];

    // 5. Appeler l'API
    print("⏳ Analyse et correction par Gemini en cours...");
    final response = await model.generateContent(prompt);

    // 6. Sauvegarder ou afficher
    if (response.text != null) {
      print("\n--- ✅ CODE CORRIGÉ --- \n");
      print(response.text);
      
      // Optionnel : Écraser le fichier avec la correction
      // await file.writeAsString(response.text!);
      // print("💾 Fichier mis à jour avec succès !");
    }

  } catch (e) {
    print("❌ Erreur technique : $e");
  }
}
