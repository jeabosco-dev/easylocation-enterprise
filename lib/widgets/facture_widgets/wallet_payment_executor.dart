// lib/widgets/facture_widgets/wallet_payment_executor.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../models/facture_model.dart';
import '../../models/promotion_model.dart';
import '../../services/facture_service.dart';
import '../../services/config_service.dart';
import '../../providers/booking_timer_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../utils/ui_utils.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import '../../screens/paiement_succes_page.dart';

class WalletPaymentExecutor {
  static Future<void> execute100PercentWalletPayment({
    required BuildContext context,
    required FactureModel facture,
    required String uniqueFactureId,
    required double montantRemise,
    required PromotionModel? promoAppliquee,
    required VoidCallback onProcessingChanged,
  }) async {
    onProcessingChanged(); // Active le chargement

    try {
      // 1. Résolution des IDs bailleur et agent
      String? realBailleurId = facture.bailleurId;
      String? realAgentTerrainId = facture.agentTerrainId; 
      if (realBailleurId == null || realAgentTerrainId == null) {
        final doc = await FirebaseFirestore.instance.collection(FirestoreCollections.properties).doc(facture.propertyId).get();
        if (doc.exists) {
          final data = doc.data();
          realBailleurId ??= data?[FactureFields.ownerId] ?? data?[FactureFields.bailleurId];
          realAgentTerrainId ??= data?[FactureFields.agentTerrainId] ?? data?[FactureFields.assignedAdminId];
        }
      }

      // 2. Création de la facture finale avec le statut payé
      final factureFinale = facture.copyWith(
        id: uniqueFactureId,
        bailleurId: realBailleurId,
        agentTerrainId: realAgentTerrainId,
        assignedAdminId: realAgentTerrainId,
        nbMoisGarantie: facture.nbMoisGarantie,
        montantGarantieTotal: facture.montantGarantieTotal,
        fromWallet: facture.montantWallet.toDouble(),
        methodePaiement: 'wallet',
        paymentStatus: 'success',
        etapeDossier: 'paye',
        montantExterne: 0.0,
        totalNetUSD: 0.0,
        montantRemise: montantRemise,
        promoCode: promoAppliquee?.code,
        promoId: promoAppliquee?.id,
        dateExpiration: DateTime.now().add(const Duration(hours: 3)),
      );

      await FactureService().creerFacture(factureFinale);

      if (promoAppliquee != null) {
        await context.read<ConfigService>().incrementPromoUsage(promoAppliquee.code);
      }

      // 3. Appel de la Cloud Function dédiée 100% Wallet
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('finalizeWalletPayment');

      final result = await callable.call({
        'factureId': uniqueFactureId,
        'propertyId': facture.propertyId,
      });

      if (result.data['status'] == 'success') {
        final timer = context.read<BookingTimerProvider>();
        if (timer.isActive) timer.stopTimer();
        context.read<UserProfileProvider>().setLastFacture(factureFinale);

        // Mettre à jour le statut de la propriété
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.properties)
            .doc(facture.propertyId)
            .update({
          FactureFields.status: PropertyStatus.reserved,
          FactureFields.updatedAt: FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          onProcessingChanged(); // Désactive le chargement
          UIUtils.showSnackBar(context, "Paiement validé avec succès par votre Wallet !");
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const PaiementSuccesPage()),
            (route) => route.isFirst,
          );
        }
      } else {
        throw "Statut de retour invalide";
      }
    } catch (e) {
      debugPrint("❌ ERREUR PAIEMENT 100% WALLET : $e");
      if (context.mounted) {
        onProcessingChanged(); // Désactive le chargement
        UIUtils.showSnackBar(context, "Erreur lors du paiement wallet : $e", isError: true);
      }
    }
  }
}