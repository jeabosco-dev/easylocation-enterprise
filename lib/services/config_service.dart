import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ConfigService extends ChangeNotifier {
  double tauxUsdCdf = 2500.0;
  Map<String, dynamic> tauxExpertise = {
    "bronze": {"bailleur": 15.0, "locataire": 10.0},
    "silver": {"bailleur": 15.0, "locataire": 13.0},
    "gold": {"bailleur": 15.0, "locataire": 17.0},
    "diamond": {"bailleur": 15.0, "locataire": 20.0},
  };

  double get commissionRate => (tauxExpertise["bronze"]?["bailleur"] ?? 15.0) / 100;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> init() async {
    try {
      // 1. AJOUT DU TIMEOUT ET SOURCE SERVEUR
      // On force la lecture sur le serveur pour éviter de rester bloqué sur un cache corrompu
      DocumentSnapshot doc = await _db
          .collection('settings')
          .doc('app_config')
          .get(const GetOptions(source: Source.serverAndCache)) // Essaye serveur, puis cache
          .timeout(const Duration(seconds: 7)); // Si après 7s rien ne vient, on passe au catch

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        if (data['taux_usd_cdf'] != null) {
          tauxUsdCdf = (data['taux_usd_cdf'] as num).toDouble();
        }
        if (data['taux_expertise'] != null) {
          tauxExpertise = Map<String, dynamic>.from(data['taux_expertise']);
        }
        
        notifyListeners(); 
        debugPrint("✅ Config Firebase chargée : $tauxUsdCdf CDF");
      } else {
        debugPrint("⚠️ Document app_config introuvable, utilisation des valeurs par défaut.");
      }
    } catch (e) {
      // 2. GESTION SILENCIEUSE DE L'ERREUR
      // Si Firestore est "unavailable", on ne bloque pas l'utilisateur.
      // On garde les valeurs par défaut définies en haut de la classe.
      debugPrint("❌ Erreur ConfigService (Indisponible ou Timeout) : $e");
      debugPrint("ℹ️ Utilisation des taux par défaut : $tauxUsdCdf");
    }
  }
}