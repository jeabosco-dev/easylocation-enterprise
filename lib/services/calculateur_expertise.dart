// lib/services/calculateur_expertise.dart

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
  static const double seuilExclusif = 0.60;
  static const double seuilAvantage = 0.38;
  static const double seuilEquilibre = 0.19;

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

  /// ✅ CALCUL DU MAX DYNAMIQUE (Fixé à 38)
  static int calculerScoreMax() {
    const meilleuresCles = [
      'garantie_low', 'chambre_4plus', 'sol_carrele', 'durable',
      'toilette_parentale', 'depot', 'cuisine', 'elec_cash_power',
      'garage', 'enclos', 'cour', 'animaux', 'eau_presente',
      'compteur_eau_solo', 'bailleur_absent', 'menage_1'
    ];
    int total = meilleuresCles.fold(0, (sum, key) => sum + (_points[key] ?? 0));
    // Total (36) + Prestige Niveau 2 (+2) = 38
    return total + 2; 
  }

  static int calculerScore(Property p) {
    int score = 0;
    debugPrint("--- 🔍 DÉBUT DE L'EXPERTISE DÉTAILLÉE ---");

    // 1. GARANTIE
    final g = p.garantieMinimale ?? 6;
    int pGarantie = (g < 3) ? _points['garantie_low']! : (g <= 6 ? _points['garantie_mid']! : _points['garantie_high']!);
    score += pGarantie;

    // 2. CAPACITÉ
    final ch = p.nombreChambres ?? 0;
    if (ch >= 4) score += _points['chambre_4plus']!;
    else if (ch == 3) score += _points['chambre_3']!;
    else if (ch == 2) score += _points['chambre_2']!;
    else if (ch == 1) score += _points['chambre_1']!;

    // 3. STRUCTURE
    final sol = (p.selectedTypeSol ?? '').toLowerCase();
    if (sol.contains('carre') || sol.contains('granit') || sol.contains('marbre')) {
      score += _points['sol_carrele']!;
    } else if (sol.contains('cim')) {
      score += _points['sol_cimente']!;
    }

    final tm = (p.typeMaison ?? '').toLowerCase();
    if (tm.contains('durab') && !tm.contains('semi')) {
      score += _points['durable']!;
    } else if (tm.contains('semi')) {
      score += _points['semi_durable']!;
    }

    // 4. OPTIONS MAISON
    if (p.hasToiletteParentale == true) score += _points['toilette_parentale']!;
    if (p.hasCuisine == true) score += _points['cuisine']!;
    if (p.hasDepot == true) score += _points['depot']!;

    // 5. ÉLECTRICITÉ
    final e = (p.electricite ?? '').toLowerCase();
    bool aDuCourant = e.isNotEmpty && !e.contains('non') && !e.contains('pas') && !e.contains('aucune');
    if (aDuCourant) {
      if (e.contains('cash') || e.contains('solo') || e.contains('power') || e.contains('prépayé')) {
        score += _points['elec_cash_power']!;
      } else {
        score += _points['elec_commun']!;
      }
    }

    // 6. EXTÉRIEUR ET EAU
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
      if (n == 99) { /* 0 pt */ } 
      else if (n == 2) { score += 2; } 
      else if (n == 1 || (n >= 3 && n != 99)) { score += 1; }
    }

    debugPrint("⚠️ SCORE FINAL: $score / ${calculerScoreMax()}");
    return score;
  }

  static OffrePack obtenirOffre(int score, int scoreMax) {
    final double ratio = (scoreMax > 0) ? (score / scoreMax) : 0.0;
    if (ratio >= seuilExclusif) {
      return const OffrePack(nom: 'Exclusif', comLocataire: 15.0, comBailleur: 15.0, totalApp: 30.0, color: Colors.purple);
    } else if (ratio >= seuilAvantage) {
      return const OffrePack(nom: 'Avantage', comLocataire: 12.5, comBailleur: 15.0, totalApp: 27.5, color: Colors.blue);
    } else if (ratio >= seuilEquilibre) {
      return const OffrePack(nom: 'Équilibre', comLocataire: 10.0, comBailleur: 15.0, totalApp: 25.0, color: Colors.green);
    } else {
      return const OffrePack(nom: 'Accès', comLocataire: 7.5, comBailleur: 15.0, totalApp: 22.5, color: Colors.blueGrey);
    }
  }
}