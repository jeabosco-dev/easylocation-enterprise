// lib/services/promotion_validation_service.dart

import 'package:flutter/foundation.dart'; // Import nécessaire pour debugPrint
import '../models/promotion_model.dart';
import '../models/facture_model.dart';
import '../models/user_model.dart';

/// Résultat de la validation métier
class ValidationPromoResult {
  final bool estValide;
  final String message;

  ValidationPromoResult({required this.estValide, required this.message});
}

class PromotionValidationService {
  /// Centralise toute la logique métier de validation d'une promotion
  /// La décision est prise uniquement sur la base de la promotion, 
  /// de la facture et de l'utilisateur.
  static ValidationPromoResult verifierPromotion({
    required PromotionModel promotion,
    required FactureModel facture,
    required UserModel utilisateur,
  }) {
    // 1. Vérification générale (dates, statut, limite d'usage)
    if (!promotion.isValid) {
      return ValidationPromoResult(
          estValide: false, message: "Ce code est expiré ou n'est plus actif.");
    }

    // 2. Vérification bénéficiaire
    // Si la promo n'est pas pour "tous", on vérifie si le rôle correspond
    if (promotion.beneficiaire != PromoBeneficiaire.tous &&
        promotion.beneficiaire.name != utilisateur.activeRole) {
      return ValidationPromoResult(
          estValide: false, message: "Cette offre ne vous est pas destinée.");
    }

    // 3. Vérification géographique
    debugPrint("DEBUG PROMO ZONE : Fac-Prov='${facture.province}', Fac-Ville='${facture.ville}', Fac-Commune='${facture.commune}'");

    if (!promotion.estZoneAutorisee(
      facture.province ?? "",
      facture.ville ?? "",
      facture.commune ?? "",
    )) {
      return ValidationPromoResult(
          estValide: false, message: "Offre non disponible dans votre zone.");
    }

    // 4. Vérification Service (Normalisée)
    final serviceFacture = (facture.typeService ?? "").trim().toLowerCase();
    final servicesPromo = promotion.servicesEligibles
        .map((e) => e.trim().toLowerCase())
        .toList();

    if (servicesPromo.isNotEmpty && !servicesPromo.contains(serviceFacture)) {
      return ValidationPromoResult(
        estValide: false,
        message: "Code non applicable à ce service.",
      );
    }

    // 5. Vérification Catégorie (Normalisée)
    final categorieFacture = (facture.categorieBien ?? "").trim().toLowerCase();
    final categoriesPromo = promotion.categoriesEligibles
        .map((e) => e.trim().toLowerCase())
        .toList();

    // DEBUG : Voir ce qui est comparé pour la catégorie
    debugPrint("DEBUG PROMO CAT : FactureCat='$categorieFacture', ListePromo='$categoriesPromo'");

    if (categoriesPromo.isNotEmpty && !categoriesPromo.contains(categorieFacture)) {
      return ValidationPromoResult(
        estValide: false,
        message: "Code non applicable à cette catégorie de bien.",
      );
    }

    // Si tout est passé
    return ValidationPromoResult(
        estValide: true, message: "Code promo appliqué avec succès !");
  }
}