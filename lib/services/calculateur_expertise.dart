import 'package:flutter/material.dart';
import '../models/property_model.dart';

class OffrePack {
  final String nom;
  final double comLocataire;
  final double comBailleur;
  final double totalApp;
  final Color color;

  const OffrePack({
    required this.nom,
    required this.comLocataire,
    required this.comBailleur,
    required this.totalApp,
    required this.color,
  });
}

class CalculateurExpertise {
  // --- SEUILS DE QUALITÉ (Ratio Score/ScoreMax) ---
  static const double seuilDiamond = 0.60;
  static const double seuilGold = 0.38;
  static const double seuilSilver = 0.19;

  // --- BARÈME DES POINTS ---
  static const Map<String, int> _points = {
    'garantie_low': 4, 'garantie_mid': 2, 'garantie_high': 1,
    'chambre_4plus': 4, 'chambre_3': 3, 'chambre_2': 2, 'chambre_1': 1,
    'sol_carrele': 3, 'sol_cimente': 2,
    'durable': 3, 'semi_durable': 1,
    'toilette_parentale': 2, 'depot': 2, 'cuisine': 1,
    'elec_cash_power': 3, 'elec_commun': 2,
    'garage': 2, 'enclos': 2, 'cour': 1, 'animaux': 1,
    'eau_presente': 1, 'compteur_eau_solo': 1,
    'bailleur_absent': 3,
    'menage_1': 3, 'menage_2_3': 2, 'menage_plus_3': 1,
  };

  // --- CALCUL DU SCORE MAXIMUM THÉORIQUE ---
  static int calculerScoreMax() {
    const meilleuresCles = [
      'garantie_low', 'chambre_4plus', 'sol_carrele', 'durable',
      'toilette_parentale', 'depot', 'cuisine', 'elec_cash_power',
      'garage', 'enclos', 'cour', 'animaux', 'eau_presente',
      'compteur_eau_solo', 'bailleur_absent', 'menage_1'
    ];
    int total = meilleuresCles.fold(0, (sum, key) => sum + (_points[key] ?? 0));
    return total + 2; // +2 pour le bonus éventuel du 2ème étage
  }

  // --- CALCUL DU SCORE RÉEL SELON LA PROPRIÉTÉ ---
  static int calculerScore(Property p) {
    int score = 0;

    // 1. GARANTIE
    final g = p.garantieMinimale ?? 6;
    score += (g < 3) ? _points['garantie_low']! : (g <= 6 ? _points['garantie_mid']! : _points['garantie_high']!);

    // 2. CAPACITÉ
    final ch = p.nombreChambres ?? 0;
    if (ch >= 4) score += _points['chambre_4plus']!;
    else if (ch == 3) score += _points['chambre_3']!;
    else if (ch == 2) score += _points['chambre_2']!;
    else if (ch == 1) score += _points['chambre_1']!;

    // 3. STRUCTURE
    final sol = (p.selectedTypeSol ?? '').toLowerCase();
    if (sol.contains('carre') || sol.contains('granit') || sol.contains('marbre')) score += _points['sol_carrele']!;
    else if (sol.contains('cim')) score += _points['sol_cimente']!;

    final tm = (p.typeMaison ?? '').toLowerCase();
    if (tm.contains('durab') && !tm.contains('semi')) score += _points['durable']!;
    else if (tm.contains('semi')) score += _points['semi_durable']!;

    // 4. OPTIONS & CONFORT
    if (p.hasToiletteParentale == true) score += _points['toilette_parentale']!;
    if (p.hasCuisine == true) score += _points['cuisine']!;
    if (p.hasDepot == true) score += _points['depot']!;

    // 5. ÉLECTRICITÉ
    final e = (p.electricite ?? '').toLowerCase();
    if (e.isNotEmpty && !e.contains('non') && !e.contains('pas') && !e.contains('aucune')) {
      score += (e.contains('cash') || e.contains('solo') || e.contains('power')) ? _points['elec_cash_power']! : _points['elec_commun']!;
    }

    // 6. EXTÉRIEUR
    if (p.hasGarage == true) score += _points['garage']!;
    if (p.maisonEnclos == true) score += _points['enclos']!;
    if (p.hasCourRecreation == true) score += _points['cour']!;
    if (p.possibiliteAnimaux == true) score += _points['animaux']!;
    if (p.hasEau == true) score += _points['eau_presente']!;
    if (p.compteurEau == true) score += _points['compteur_eau_solo']!;

    // 7. COMMUNAUTÉ
    if (p.bailleurHabiteAvec == false) score += _points['bailleur_absent']!;
    final nMenages = (p.nombreMenages ?? 0) + 1; 
    if (nMenages == 1) score += _points['menage_1']!;
    else if (nMenages <= 3) score += _points['menage_2_3']!;
    else score += _points['menage_plus_3']!;

    // 8. ÉTAGE
    if (p.maisonEnEtage == true) {
      final int n = p.niveauEtage ?? 0;
      if (n == 2) score += 2; 
      else if (n == 1 || (n >= 3 && n != 99)) score += 1;
    }

    return score;
  }

  // --- OBTENTION DE L'OFFRE DYNAMIQUE (FIRESTORE) ---
  static OffrePack obtenirOffre(int score, int scoreMax, {required Map<String, dynamic> config}) {
    final double ratio = (scoreMax > 0) ? (score / scoreMax) : 0.0;
    
    // Fonction helper pour créer l'offre à partir des clés de ton Firestore
    OffrePack creerPack(String palier, Color couleur) {
      // On récupère le bloc Map (ex: bronze) dans ta config
      final p = config[palier] ?? {"bailleur": 15.0, "locataire": 10.0};
      
      // Conversion sécurisée en double
      double b = (p['bailleur'] as num).toDouble();
      double l = (p['locataire'] as num).toDouble();
      
      return OffrePack(
        nom: palier[0].toUpperCase() + palier.substring(1), // Diamond, Gold, etc.
        comLocataire: l,
        comBailleur: b,
        totalApp: b + l,
        color: couleur,
      );
    }

    // Détermination du pack selon le score obtenu
    if (ratio >= seuilDiamond) {
      return creerPack('diamond', Colors.purple);
    } else if (ratio >= seuilGold) {
      return creerPack('gold', Colors.amber.shade700);
    } else if (ratio >= seuilSilver) {
      return creerPack('silver', Colors.blueGrey);
    } else {
      return creerPack('bronze', Colors.orange.shade800);
    }
  }
}