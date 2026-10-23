import 'package:flutter/material.dart';
import '../models/property/property.dart';
import '../models/property/property_getters.dart';
import '../services/config_service.dart';

/// Classe conteneur pour transporter les résultats financiers en entiers (cents)
class CalculPaiement {
  final int totalCommission;
  final int partLocataire;
  final int partBailleur;
  final int montantWalletApplique; // Total global du wallet consommé (balance + promos)
  final int montantBalanceApplique; // Part spécifique prise sur la balance principale
  final int montantPromosApplique; // Part spécifique prise sur les sous-soldes promos
  final int resteAPayer;
  final int garantieTotale;
  final int resteAPayerBailleur;

  CalculPaiement({
    required this.totalCommission,
    required this.partLocataire,
    required this.partBailleur,
    required this.montantWalletApplique,
    required this.montantBalanceApplique,
    required this.montantPromosApplique,
    required this.resteAPayer,
    required this.garantieTotale,
    required this.resteAPayerBailleur,
  });
}

class OffrePack {
  final String titre;
  final double comLocataire;
  final double comBailleur;
  final double totalApp;
  final Color color;

  const OffrePack({
    required this.titre,
    required this.comLocataire,
    required this.comBailleur,
    required this.totalApp,
    required this.color,
  });
}

class CalculateurExpertise {
  // --- SEUILS DE QUALITÉ ---
  static const double seuilDiamond = 0.60;
  static const double seuilGold = 0.38;
  static const double seuilSilver = 0.19;

  // --- LOGIQUE FINANCIÈRE (Calcul centralisé avec différenciation Balance / Promos) ---
  static CalculPaiement calculerFacture({
    required double prixLoyer,
    required double comLocataire,
    required double comBailleur,
    // Paramètres détaillés du Wallet pour respecter la nouvelle logique métier
    required int soldeBalanceCents, // Argent réel (remboursement)
    required int soldeBonusCents,   // Bonus / Cashback / Commissions
    required int pointsLoyalty,
    required int moisGarantie,
    required bool useWallet,
    required bool usePoints,
    required bool isLoyaltyActive,
    required ConfigService config,
  }) {
    // 1. Conversion des montants en "cents"
    int loyerCents = (prixLoyer * 100).round();
    int partLocCents = (loyerCents * (comLocataire / 100)).round();
    int partBailCents = (loyerCents * (comBailleur / 100)).round();
    int totalFactureCents = partLocCents + partBailCents;

    // 2. Application des réductions (points fidélité)
    int pointsAAppliquer = (isLoyaltyActive && usePoints) ? pointsLoyalty : 0;
    int montantApresPoints = (totalFactureCents - (pointsAAppliquer * 100)).clamp(0, totalFactureCents);

    int balanceAppliqueCents = 0;
    int promosAppliqueCents = 0;
    int resteAPayer = montantApresPoints;

    if (useWallet) {
      // ÉTAPE A : Consommation prioritaire et non plafonnée de la Balance principale (Remboursements)
      // La balance peut couvrir jusqu'à 100% de la facture (loyer + frais de service)
      if (soldeBalanceCents > 0 && resteAPayer > 0) {
        balanceAppliqueCents = soldeBalanceCents >= resteAPayer ? resteAPayer : soldeBalanceCents;
        resteAPayer -= balanceAppliqueCents;
      }

      // ÉTAPE B : Si il reste encore un montant à payer, on applique les sous-soldes promos (dans la limite du pourcentage configuré)
      if (resteAPayer > 0 && soldeBonusCents > 0) {
        int limiteWalletPromos = (partLocCents * config.walletLimitPercentage).round();
        int promosDisponibles = soldeBonusCents < limiteWalletPromos ? soldeBonusCents : limiteWalletPromos;
        
        promosAppliqueCents = promosDisponibles >= resteAPayer ? resteAPayer : promosDisponibles;
        resteAPayer -= promosAppliqueCents;
      }
    }

    int totalWalletApplique = balanceAppliqueCents + promosAppliqueCents;

    // 3. Calcul garantie bailleur
    int garantieTotale = loyerCents * moisGarantie;

    return CalculPaiement(
      totalCommission: totalFactureCents,
      partLocataire: partLocCents,
      partBailleur: partBailCents,
      montantWalletApplique: totalWalletApplique,
      montantBalanceApplique: balanceAppliqueCents,
      montantPromosApplique: promosAppliqueCents,
      resteAPayer: resteAPayer.clamp(0, totalFactureCents),
      garantieTotale: garantieTotale,
      resteAPayerBailleur: garantieTotale - partBailCents,
    );
  }

  // --- MISE À JOUR DE LA MAP DES POINTS & SCORES ---
  static const Map<String, int> _points = {
    'garantie_low': 4, 'garantie_mid': 2, 'garantie_high': 1,
    'chambre_4plus': 4, 'chambre_3': 3, 'chambre_2': 2, 'chambre_1': 1,
    'sol_carrele': 3, 'sol_cimente': 2,
    'durable': 3, 'semi_durable': 1,
    
    // --- SANITAIRES & TOILETTES ---
    'toilette_parentale': 3,         // Intimité suite parentale
    'toilette_interne_commune': 2, // Confort intérieur famille/visiteurs
    'toilette_externe': 1,         // Commodité extérieure
    
    'depot': 2, 'cuisine': 1,
    'elec_cash_power': 3, 'elec_commun': 2,
    'garage': 2, 'enclos': 2, 'cour': 1, 'animaux': 1,
    'eau_presente': 1, 'compteur_eau_solo': 1,
    'bailleur_absent': 3,
    'menage_1': 3, 'menage_2_3': 2, 'menage_plus_3': 1,
  };

  static int calculerScoreMax() {
    const meilleuresCles = [
      'garantie_low', 'chambre_4plus', 'sol_carrele', 'durable',
      'toilette_parentale', 'toilette_interne_commune', 'toilette_externe',
      'depot', 'cuisine', 'elec_cash_power',
      'garage', 'enclos', 'cour', 'animaux', 'eau_presente',
      'compteur_eau_solo', 'bailleur_absent', 'menage_1'
    ];
    int total = meilleuresCles.fold(0, (sum, key) => sum + (_points[key] ?? 0));
    return total + 2;
  }

  static int calculerScore(Property p) {
    int score = 0;
    final g = p.garantieMinimale;
    score += (g < 3) ? _points['garantie_low']! : (g <= 6 ? _points['garantie_mid']! : _points['garantie_high']!);
    
    final ch = p.nombreChambres;
    if (ch >= 4) score += _points['chambre_4plus']!;
    else if (ch == 3) score += _points['chambre_3']!;
    else if (ch == 2) score += _points['chambre_2']!;
    else if (ch == 1) score += _points['chambre_1']!;

    final sol = (p.selectedTypeSol ?? '').toLowerCase();
    if (sol.contains('carre') || sol.contains('granit') || sol.contains('marbre')) score += _points['sol_carrele']!;
    else if (sol.contains('cim')) score += _points['sol_cimente']!;

    final tm = (p.typeMaison ?? '').toLowerCase();
    if (tm.contains('durab') && !tm.contains('semi')) score += _points['durable']!;
    else if (tm.contains('semi')) score += _points['semi_durable']!;

    if (p.hasToiletteParentale == true) score += _points['toilette_parentale']!;
    if (p.hasToiletteInterneCommune == true) score += _points['toilette_interne_commune']!;
    if (p.hasToiletteExterne == true) score += _points['toilette_externe']!;

    if (p.hasCuisine == true) score += _points['cuisine']!;
    if (p.hasDepot == true) score += _points['depot']!;

    if (p.hasElectricity) {
      final typeElec = (p.typeElectricite ?? p.electricite).toLowerCase();
      if (typeElec.contains('cash') || typeElec.contains('solo') || typeElec.contains('power') || typeElec.contains('propre')) {
        score += _points['elec_cash_power']!;
      } else {
        score += _points['elec_commun']!;
      }
    }

    if (p.hasGarage == true) score += _points['garage']!;
    if (p.maisonEnclos == true) score += _points['enclos']!;
    if (p.hasCourRecreation == true) score += _points['cour']!;
    if (p.possibiliteAnimaux == true) score += _points['animaux']!;
    if (p.hasEau == true) score += _points['eau_presente']!;
    if (p.compteurEau == true) score += _points['compteur_eau_solo']!;
    if (p.bailleurHabiteAvec == false) score += _points['bailleur_absent']!;

    final nMenages = (p.nombreMenages ?? 0) + 1;
    if (nMenages == 1) score += _points['menage_1']!;
    else if (nMenages <= 3) score += _points['menage_2_3']!;
    else score += _points['menage_plus_3']!;

    if (p.maisonEnEtage == true) {
      final int n = p.niveauEtage ?? 0;
      if (n == 2) score += 2;
      else if (n == 1 || (n >= 3 && n != 99)) score += 1;
    }

    return score;
  }

  static OffrePack obtenirOffre(int score, int scoreMax, {required Map<String, dynamic> config}) {
    final double ratio = (scoreMax > 0) ? (score / scoreMax) : 0.0;
    OffrePack creerPack(String palier, Color couleur) {
      final p = config[palier] ?? {"bailleur": 15.0, "locataire": 10.0};
      double b = (p['bailleur'] as num).toDouble();
      double l = (p['locataire'] as num).toDouble();
      return OffrePack(
        titre: palier[0].toUpperCase() + palier.substring(1),
        comLocataire: l,
        comBailleur: b,
        totalApp: b + l,
        color: couleur,
      );
    }
    if (ratio >= seuilDiamond) return creerPack('diamond', Colors.purple);
    else if (ratio >= seuilGold) return creerPack('gold', Colors.amber.shade700);
    else if (ratio >= seuilSilver) return creerPack('silver', Colors.blueGrey);
    else return creerPack('bronze', Colors.orange.shade800);
  }
}