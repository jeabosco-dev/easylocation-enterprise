// lib/services/calculateur_expertise.dart

import 'package:flutter/material.dart';
import '../models/formulaire_publication_model.dart';

/// ✅ Modèle de données pro pour une Offre Commerciale
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
  // --- CONFIGURATION DES SEUILS ---
  static const double seuilExclusif = 0.60;
  static const double seuilAvantage = 0.38;
  static const double seuilEquilibre = 0.19;

  // --- BASE DE DONNÉES DES POINTS (Total Max: 36) ---
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

  /// ✅ CALCUL DU MAX AUTOMATIQUE
  static int calculerScoreMax() {
    const meilleuresOptions = [
      'garantie_low', 'chambre_4plus', 'sol_carrele', 'durable',
      'toilette_parentale', 'depot', 'cuisine', 'elec_cash_power',
      'garage', 'enclos', 'cour', 'animaux', 'eau_presente',
      'compteur_eau_solo', 'bailleur_absent', 'menage_1'
    ];
    return meilleuresOptions.fold(0, (sum, key) => sum + (_points[key] ?? 0));
  }

  /// ✅ ALGORITHME DE SCORING ROBUSTE (AVEC .CONTAINS())
  static int calculerScore(FormulairePublicationModel f) {
    int score = 0;
    print("--- 🔍 DÉBUT DE L'EXPERTISE ---");

    // 1. GARANTIE
    final g = f.garantieMinimale ?? 12;
    int pGarantie = (g < 3) ? _points['garantie_low']! : (g <= 6 ? _points['garantie_mid']! : _points['garantie_high']!);
    score += pGarantie;
    print("📍 Garantie ($g mois): +$pGarantie pts");

    // 2. CAPACITÉ
    final ch = f.nombreChambres ?? 0;
    int pChambre = 0;
    if (ch >= 4) pChambre = _points['chambre_4plus']!;
    else if (ch == 3) pChambre = _points['chambre_3']!;
    else if (ch == 2) pChambre = _points['chambre_2']!;
    else if (ch == 1) pChambre = _points['chambre_1']!;
    score += pChambre;
    print("📍 Chambres ($ch): +$pChambre pts");

    // 3. STRUCTURE (Version robuste avec .contains)
    final sol = (f.selectedTypeSol ?? '').toLowerCase();
    int pSol = 0;
    if (sol.contains('carr')) {
      pSol = _points['sol_carrele']!;
    } else if (sol.contains('cim')) {
      pSol = _points['sol_cimente']!;
    }
    score += pSol;
    print("📍 Sol ($sol): +$pSol pts");

    final tm = (f.typeMaison ?? '').toLowerCase();
    int pType = 0;
    if (tm.contains('durab') && !tm.contains('semi')) {
      pType = _points['durable']!;
    } else if (tm.contains('semi')) {
      pType = _points['semi_durable']!;
    }
    score += pType;
    print("📍 Structure ($tm): +$pType pts");

    // 4. OPTIONS MAISON (Booléens)
    if (f.hasToiletteParentale == true) { 
      score += _points['toilette_parentale']!; 
      print("📍 Toilette Parentale: +${_points['toilette_parentale']} pts"); 
    }
    
    if (f.hasCuisine == true) { 
      score += _points['cuisine']!; 
      print("📍 Cuisine: +${_points['cuisine']} pts"); 
    }

    if (f.hasDepot == true) { 
      score += _points['depot']!; 
      print("📍 Dépôt: +${_points['depot']} pts"); 
    }

    // 5. ÉLECTRICITÉ (Recherche par mot-clé)
    final e = (f.electricite ?? '').toLowerCase();
    int pElec = 0;
    if (e.contains('cash') || e.contains('propre') || e.contains('solo')) {
      pElec = _points['elec_cash_power']!;
    } else if (e.contains('commun') || e.contains('partag')) {
      pElec = _points['elec_commun']!;
    }
    score += pElec;
    print("📍 Électricité ($e): +$pElec pts");

    // 6. EXTÉRIEUR ET EAU
    if (f.hasGarage == true) { score += _points['garage']!; print("📍 Garage: +${_points['garage']} pts"); }
    if (f.maisonEnclos == true) { score += _points['enclos']!; print("📍 Enclos: +${_points['enclos']} pts"); }
    if (f.hasCourRecreation == true) { score += _points['cour']!; print("📍 Cour: +${_points['cour']} pts"); }
    if (f.possibiliteAnimaux == true) { score += _points['animaux']!; print("📍 Animaux: +${_points['animaux']} pts"); }
    if (f.hasEau == true) { score += _points['eau_presente']!; print("📍 Eau: +${_points['eau_presente']} pts"); }
    if (f.compteurEau == true) { score += _points['compteur_eau_solo']!; print("📍 Compteur Eau: +${_points['compteur_eau_solo']} pts"); }

    // 7. COMMUNAUTÉ
    if (f.bailleurHabiteAvec == false) { score += _points['bailleur_absent']!; print("📍 Bailleur Absent: +${_points['bailleur_absent']} pts"); }
    
    final nMenages = (f.nombreMenages ?? 0) + 1; 
    int pMenage = 0;
    if (nMenages == 1) pMenage = _points['menage_1']!;
    else if (nMenages <= 3) pMenage = _points['menage_2_3']!;
    else pMenage = _points['menage_plus_3']!;
    score += pMenage;
    print("📍 Voisinage ($nMenages ménages): +$pMenage pts");

    print("⚠️ SCORE FINAL: $score / ${calculerScoreMax()}");
    print("----------------------------");

    return score;
  }

  /// ✅ SEGMENTATION COMMERCIALE
  static OffrePack obtenirOffre(int score) {
    final double ratio = score / calculerScoreMax();

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
