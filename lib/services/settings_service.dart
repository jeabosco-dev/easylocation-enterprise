// lib/services/settings_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/foundation.dart';

class SettingsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<double> getTauxDuJour() async {
    try {
      // ✅ On récupère le bon document "app_config" dans la collection "settings"
      DocumentSnapshot doc = await _db.collection('settings').doc('app_config').get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        
        // ✅ On utilise le champ exact : "taux_usd_cdf"
        final dynamic valeurTaux = data['taux_usd_cdf'];

        if (valeurTaux != null) {
          debugPrint("✅ Taux récupéré avec succès (app_config) : $valeurTaux");
          // .toDouble() gère les cas où Firestore renvoie un int ou un double
          return (valeurTaux as num).toDouble();
        } else {
          debugPrint("⚠️ Champ 'taux_usd_cdf' manquant dans le document app_config");
        }
      } else {
        debugPrint("❌ Document 'app_config' introuvable dans la collection 'settings'");
      }
    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur Firestore lors de la récupération du taux : $e");
      // On envoie l'erreur à Sentry pour être alerté
      await Sentry.captureException(e, stackTrace: stackTrace);
    }
    
    // Valeur de secours (fallback) si la base est injoignable
    debugPrint("ℹ️ Utilisation de la valeur de secours : 2500.0");
    return 2500.0; 
  }
}
