// lib/services/promo_service.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/promotion_model.dart';
import '../models/property_model.dart'; 
import 'package:easylocation_mvp/constants/all_constants.dart';

class PromoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Vérifie si un code promo est valide ET applicable à une propriété/service
  Future<Map<String, dynamic>> verifierEtValiderCode({
    required Property property, 
    required String codeSaisi,
    String? serviceConcerne, // Nouveau paramètre pour valider le service
  }) async {
    
    if (codeSaisi.isEmpty) {
      return {'valid': false, 'message': "Veuillez saisir un code."};
    }

    try {
      var snapshot = await _db
          .collection(FirestoreCollections.promotions)
          .doc(codeSaisi.trim().toUpperCase())
          .get();

      if (!snapshot.exists) {
        return {'valid': false, 'message': "Code promo inexistant."};
      }

      final promo = PromotionModel.fromFirestore(snapshot);

      // 1. Vérification de la validité générale
      if (!promo.isValid) {
        return {
          'valid': false, 
          'message': "Ce code est expiré ou n'est plus actif."
        };
      }

      // 2. FILTRE GÉOGRAPHIQUE (Utilisation de la nouvelle hiérarchie)
      // Note : Adapte property.province, property.ville, property.commune selon ton modèle
      if (!promo.estZoneAutorisee(
        property.province ?? "", 
        property.ville, 
        property.commune ?? ""
      )) {
        return {
          'valid': false,
          'message': "Désolé, cette offre n'est pas disponible dans cette zone."
        };
      }

      // 3. NOUVEAU : FILTRE SERVICE
      if (serviceConcerne != null && 
          promo.servicesEligibles.isNotEmpty && 
          !promo.servicesEligibles.contains(serviceConcerne)) {
        return {'valid': false, 'message': "Ce code n'est pas applicable à ce service."};
      }

      // 4. NOUVEAU : FILTRE CATÉGORIE
      if (promo.categoriesEligibles.isNotEmpty && 
          !promo.categoriesEligibles.contains(property.categorie)) {
        return {'valid': false, 'message': "Ce code ne s'applique pas à ce type de bien."};
      }

      // Si tout est OK
      return {
        'valid': true,
        'promo': promo,
        'message': "Code promo appliqué avec succès !"
      };
    } catch (e) {
      debugPrint("Erreur verifierEtValiderCode: $e");
      return {'valid': false, 'message': "Une erreur est survenue lors de la vérification."};
    }
  }

  /// MÉTHODE CRUCIALE : Consomme une place de manière atomique
  Future<bool> validerEtConsommerUnePlace(String promoId) async {
    try {
      return await _db.runTransaction((transaction) async {
        DocumentReference promoRef = _db.collection(FirestoreCollections.promotions).doc(promoId);
        DocumentSnapshot snapshot = await transaction.get(promoRef);

        if (!snapshot.exists) return false;

        final promo = PromotionModel.fromFirestore(snapshot);

        if (promo.isValid && (promo.usageLimit == 0 || promo.usageCount < promo.usageLimit)) {
          transaction.update(promoRef, {
            'usage_count': FieldValue.increment(1),
            'last_usage_at': FieldValue.serverTimestamp(),
          });
          return true;
        }
        return false;
      });
    } catch (e) {
      debugPrint("Erreur Transaction Promo: $e");
      return false;
    }
  }

  /// Calcule le détail de la facture en appliquant la remise
  Map<String, double> calculerFacture({
    required double commissionBase,
    required double garantieBailleur,
    PromotionModel? promo,
  }) {
    double remise = 0;
    if (promo != null && promo.isValid) {
      remise = promo.calculerRemise(commissionBase);
    }

    return {
      'remise': remise,
      'netAPayer': commissionBase - remise,
      'totalTransaction': (commissionBase - remise) + garantieBailleur,
    };
  }

  /// Récupère la première promotion automatique active
  Future<PromotionModel?> recupererPromoAutomatiqueActive() async {
    final maintenant = Timestamp.now();
    try {
      var snapshot = await _db
          .collection(FirestoreCollections.promotions)
          .where('statut', isEqualTo: 'actif')
          .where('date_debut', isLessThanOrEqualTo: maintenant)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final promos = snapshot.docs
          .map((doc) => PromotionModel.fromFirestore(doc))
          .where((p) => p.isValid)
          .toList();

      return promos.isNotEmpty ? promos.first : null;
    } catch (e) {
      debugPrint("Erreur recupererPromoAutomatiqueActive: $e");
      return null;
    }
  }
}