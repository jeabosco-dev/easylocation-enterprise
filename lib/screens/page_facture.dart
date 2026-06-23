import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:cloud_functions/cloud_functions.dart'; 

import '../models/facture_model.dart';
import '../models/promotion_model.dart';
import '../services/maxicash_service.dart';
import '../services/facture_service.dart';
import '../services/config_service.dart';
import '../providers/booking_timer_provider.dart';
import '../providers/user_profile_provider.dart';
import '../utils/ui_utils.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

// Widgets
import '../widgets/manuel_payment_sheet.dart'; 
import '../widgets/cash_payment_instruction_sheet.dart'; 
import '../widgets/facture_widgets/facture_header.dart';
import '../widgets/facture_widgets/facture_info_section.dart';
import '../widgets/facture_widgets/facture_price_table.dart';
import '../widgets/facture_widgets/facture_payment_button.dart';
import '../widgets/facture_widgets/facture_footer.dart';
import '../widgets/facture_widgets/payment_method_picker.dart';
import '../widgets/facture_widgets/facture_promo_widget.dart';

import 'paiement_succes_page.dart'; 

class FacturePage extends StatefulWidget {
  final FactureModel facture;
  const FacturePage({super.key, required this.facture});

  @override
  State<FacturePage> createState() => _FacturePageState();
}

class _FacturePageState extends State<FacturePage> {
  String deviseSelectionnee = "USD";
  final FactureService _factureService = FactureService();
  bool _isProcessing = false; 
  
  double _montantRemise = 0.0;
  PromotionModel? _promoAppliquee;
  
  late final String uniqueFactureId = "FACT-${widget.facture.refMaison}-${DateTime.now().millisecondsSinceEpoch}";

  double get netAPayerUSD => ((widget.facture.totalUSD - _montantRemise) - widget.facture.montantWallet).clamp(0, double.infinity);
  double get netAPayerCDF => (netAPayerUSD * widget.facture.tauxApplique).ceilToDouble();

  void _handleTimeout(BuildContext context) {
    if (!mounted) return; 
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Session expirée", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("Le temps imparti pour finaliser votre réservation est écoulé."),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("RETOUR À L'ACCUEIL", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = context.watch<UserProfileProvider>().userData;
    
    return _buildMainScaffold(userProfile);
  }

  Widget _buildMainScaffold(userProfile) {
    final timerProvider = context.watch<BookingTimerProvider>();
    if (timerProvider.isExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTimeout(context));
    }

    String totalAffiche = (deviseSelectionnee == "USD") 
        ? "\$ ${UIUtils.formatPrice(netAPayerUSD, decimalDigits: 2)}" 
        : "FC ${UIUtils.formatPrice(netAPayerCDF)}";

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text("Récapitulatif & Paiement", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            backgroundColor: Colors.white, elevation: 0, centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          body: Column(
            children: [
              _buildTimerBanner(timerProvider),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const FactureHeader(),
                      const SizedBox(height: 25),
                      FactureInfoSection(facture: widget.facture),
                      const Divider(height: 40),
                      
                      if (userProfile != null)
                        FacturePromoWidget(
                          totalBase: widget.facture.totalUSD,
                          facture: widget.facture,
                          utilisateur: userProfile,
                          onPromoApplied: (newTotal, promo) {
                            setState(() {
                              _montantRemise = widget.facture.totalUSD - newTotal;
                              _promoAppliquee = promo;
                            });
                          },
                        ),
                        
                      const SizedBox(height: 20),
                      FacturePriceTable(
                        facture: widget.facture,
                        netAPayerUSD: netAPayerUSD,
                        netAPayerCDF: netAPayerCDF, 
                        totalAffiche: totalAffiche,
                        deviseSelectionnee: deviseSelectionnee,
                      ),
                      const SizedBox(height: 20),
                      FactureFooter(
                        facture: widget.facture,
                        deviseSelectionnee: deviseSelectionnee,
                        onDeviseChanged: (code) => setState(() => deviseSelectionnee = code),
                      ),
                      const SizedBox(height: 30),
                      FacturePaymentButton(
                        timer: timerProvider,
                        isProcessing: _isProcessing,
                        netAPayerUSD: netAPayerUSD,
                        onActionPressed: () => _afficherChoixPaiement(context),
                      ),
                      const SizedBox(height: 20),
                      const Text("EasyLocation Enterprise - N° Impôt : A2301893J", style: TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  void _afficherChoixPaiement(BuildContext context) {
    if (netAPayerUSD <= 0) {
       _procederAuPaiement("Wallet");
       return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => PaymentMethodPicker(
        onMethodSelected: (methode) {
          Navigator.pop(sheetContext);
          _procederAuPaiement(methode);
        },
      ),
    );
  }

  void _procederAuPaiement(String methode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    String? hybridRef;

    try {
      // 1. Récupération des infos tiers
      String? realBailleurId = widget.facture.bailleurId;
      String? realAgentTerrainId = widget.facture.agentTerrainId; 
      if (realBailleurId == null || realAgentTerrainId == null) {
        final doc = await FirebaseFirestore.instance.collection(FirestoreCollections.properties).doc(widget.facture.propertyId).get();
        if (doc.exists) {
          final data = doc.data();
          realBailleurId ??= data?[FactureFields.ownerId] ?? data?[FactureFields.bailleurId];
          realAgentTerrainId ??= data?[FactureFields.agentTerrainId] ?? data?[FactureFields.assignedAdminId];
        }
      }

      // 2. Création de l'objet facture complet (avec promo)
      final factureFinale = widget.facture.copyWith(
        id: uniqueFactureId,
        bailleurId: realBailleurId,
        agentTerrainId: realAgentTerrainId,
        assignedAdminId: realAgentTerrainId,
        methodePaiement: methode.toLowerCase(), 
        paymentStatus: (methode == "Wallet") ? 'success' : 'pending', 
        etapeDossier: (methode == "Wallet") ? 'paye' : 'nouveau',
        montantExterne: netAPayerUSD,
        totalNetUSD: netAPayerUSD,
        montantRemise: _montantRemise,
        promoCode: _promoAppliquee?.code,
        promoId: _promoAppliquee?.id,
        dateExpiration: DateTime.now().add(const Duration(hours: 3)),
      );

      // 3. Persistance de la facture AVANT le paiement
      await _factureService.creerFacture(factureFinale);
      
      // 4. Initialisation du paiement hybride si besoin
      if (methode == "Maxicash" && widget.facture.montantWallet > 0) {
        try {
          final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('initiateHybridPayment');
          final result = await callable.call({
            'serviceId': widget.facture.propertyId,
            'totalAmount': netAPayerUSD,
            'totalBrut': widget.facture.totalUSD,
            'montantRemise': _montantRemise,
            'walletAmountRequested': widget.facture.montantWallet,
            'partLocataire': netAPayerUSD,
            'serviceType': widget.facture.typeService ?? 'standard',
            'metadata': {'factureReference': uniqueFactureId}
          });
          hybridRef = result.data['paymentReference'];
        } catch (e) {
          // Rollback : suppression de la facture si le paiement échoue
          await _factureService.supprimerFacture(uniqueFactureId);
          throw Exception("Echec initialisation paiement : $e");
        }
      }

      // 5. Finalisation logique métier
      if (_promoAppliquee != null) {
        await context.read<ConfigService>().incrementPromoUsage(_promoAppliquee!.code);
      }

      final timer = context.read<BookingTimerProvider>();
      if (timer.isActive) timer.updateInvoiceId(uniqueFactureId);
      context.read<UserProfileProvider>().setLastFacture(factureFinale);

      // 6. Routage selon méthode
      if (methode == "Wallet") {
          context.read<BookingTimerProvider>().stopTimer();
          await _finaliserStatutPropriete(PropertyStatus.reserved);
          if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const PaiementSuccesPage()), (route) => route.isFirst);
      } else if (methode == "Maxicash") {
        await MaxicashService.encaisserAcompte(
          context: context,
          telephone: factureFinale.telClient,
          referenceCommande: uniqueFactureId,
          montant: netAPayerUSD,
          ville: factureFinale.ville ?? "Inconnue",
          hybridReference: hybridRef,
          onSuccess: () {
            if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const PaiementSuccesPage()), (route) => route.isFirst);
          },
          onCancel: () => setState(() => _isProcessing = false),
        );
      } else if (methode == "Manuel") {
        setState(() => _isProcessing = false);
        showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) => ManuelPaymentSheet(facture: factureFinale, montantFinal: (deviseSelectionnee == "USD") ? netAPayerUSD : netAPayerCDF, devise: deviseSelectionnee, docId: uniqueFactureId));
      } else {
        setState(() => _isProcessing = false);
        context.read<BookingTimerProvider>().stopTimer();
        showModalBottomSheet(
          context: context, 
          isScrollControlled: true, 
          builder: (context) => CashPaymentInstructionSheet(refBien: factureFinale.refMaison, montantAPayer: netAPayerUSD, dateExpiration: factureFinale.dateExpiration ?? DateTime.now().add(const Duration(hours: 3)))
        ).then((_) { if (mounted) Navigator.of(context).popUntil((route) => route.isFirst); });
      }
    } catch (e) {
      debugPrint("❌ ERREUR PAIEMENT : $e");
      if (mounted) {
        setState(() => _isProcessing = false);
        UIUtils.showSnackBar(context, "Erreur lors du processus. Veuillez réessayer.", isError: true);
      }
    }
  }

  Widget _buildTimerBanner(BookingTimerProvider timer) {
    return Container(
      width: double.infinity, 
      color: timer.isUrgent ? Colors.red.shade700 : Colors.orange.shade800, 
      padding: const EdgeInsets.symmetric(vertical: 6), 
      child: Center(child: Text("TEMPS RESTANT : ${timer.formattedTime}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)))
    );
  }

  Future<void> _finaliserStatutPropriete(String nouveauStatut) async {
    try {
      await FirebaseFirestore.instance.collection(FirestoreCollections.properties).doc(widget.facture.propertyId).update({FactureFields.status: nouveauStatut, FactureFields.updatedAt: FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint("❌ UPDATE PROPRIETE ECHEC : $e");
    }
  }
}