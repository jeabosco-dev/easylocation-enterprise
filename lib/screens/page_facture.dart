import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

import '../models/facture_model.dart';
import '../services/maxicash_service.dart';
import '../services/facture_service.dart';
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
  
  // Génération d'un ID stable dès l'initialisation
  late final String uniqueFactureId = "FACT-${widget.facture.refMaison}-${DateTime.now().millisecondsSinceEpoch}";

  double get netAPayerUSD => (widget.facture.totalUSD - widget.facture.montantWallet).clamp(0, double.infinity);
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
    // Utilisation du StreamBuilder pour observer le statut de paiement en temps réel
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(uniqueFactureId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          // Redirection automatique dès que le statut devient success
          if (data['paymentStatus'] == 'success') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const PaiementSuccesPage()), (route) => route.isFirst);
              }
            });
          }
        }

        return _buildMainScaffold();
      },
    );
  }

  Widget _buildMainScaffold() {
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

    try {
      // Préparation des IDs
      String? realBailleurId = widget.facture.bailleurId;
      String? realAgentTerrainId = widget.facture.agentTerrainId; 

      if (realBailleurId == null || realAgentTerrainId == null) {
        final docPropriete = await FirebaseFirestore.instance.collection(FirestoreCollections.properties).doc(widget.facture.propertyId).get();
        if (docPropriete.exists) {
          final data = docPropriete.data();
          realBailleurId ??= data?[FactureFields.ownerId] ?? data?[FactureFields.bailleurId];
          realAgentTerrainId ??= data?[FactureFields.agentTerrainId] ?? data?[FactureFields.assignedAdminId];
        }
      }

      final timer = context.read<BookingTimerProvider>();
      if (timer.isActive) timer.updateInvoiceId(uniqueFactureId);

      final factureFinale = widget.facture.copyWith(
        id: uniqueFactureId,
        bailleurId: realBailleurId,
        agentTerrainId: realAgentTerrainId,
        assignedAdminId: realAgentTerrainId,
        methodePaiement: methode.toLowerCase(), 
        paymentStatus: (methode == "Wallet") ? 'success' : 'pending', 
        etapeDossier: (methode == "Wallet") ? 'paye' : 'nouveau',
        montantExterne: netAPayerUSD, 
        dateExpiration: DateTime.now().add(const Duration(hours: 3)),
      );
      
      await _factureService.creerFacture(factureFinale);
      context.read<UserProfileProvider>().setLastFacture(factureFinale);

      if (methode == "Wallet") {
          if (widget.facture.montantWallet > 0) {
            await context.read<UserProfileProvider>().deduireArgentWallet(widget.facture.montantWallet);
          }
          context.read<BookingTimerProvider>().stopTimer();
          await _finaliserStatutPropriete(PropertyStatus.reserved);
          if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const PaiementSuccesPage()), (route) => route.isFirst);
      } 
      else if (methode == "Maxicash") {
        await MaxicashService.encaisserAcompte(
          context: context,
          telephone: factureFinale.telClient,
          referenceCommande: uniqueFactureId,
          montant: netAPayerUSD,
          ville: factureFinale.ville ?? "Inconnue", 
          onSuccess: () async {
            if (widget.facture.montantWallet > 0) {
              await context.read<UserProfileProvider>().deduireArgentWallet(widget.facture.montantWallet);
            }
            context.read<BookingTimerProvider>().stopTimer();
            await _finaliserStatutPropriete(PropertyStatus.reserved);
          },
          onCancel: () => setState(() => _isProcessing = false),
        );
      } 
      else if (methode == "Manuel") {
        await _finaliserStatutPropriete(PropertyStatus.booking); 
        setState(() => _isProcessing = false);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => ManuelPaymentSheet(facture: factureFinale, montantFinal: (deviseSelectionnee == "USD") ? netAPayerUSD : netAPayerCDF, devise: deviseSelectionnee, docId: uniqueFactureId),
        );
      } 
      else {
        await _finaliserStatutPropriete(PropertyStatus.booking);
        setState(() => _isProcessing = false);
        context.read<BookingTimerProvider>().stopTimer();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => CashPaymentInstructionSheet(
            refBien: factureFinale.refMaison, 
            montantAPayer: netAPayerUSD, 
            dateExpiration: factureFinale.dateExpiration ?? DateTime.now().add(const Duration(hours: 3))
          ),
        ).then((_) { if (mounted) Navigator.of(context).popUntil((route) => route.isFirst); });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        UIUtils.showSnackBar(context, "Erreur : $e", isError: true);
      }
    }
  }

  Widget _buildTimerBanner(BookingTimerProvider timer) {
    return Container(
      width: double.infinity, 
      color: timer.isUrgent ? Colors.red.shade700 : Colors.orange.shade800, 
      padding: const EdgeInsets.symmetric(vertical: 6), 
      child: Center(
        child: Text(
          "TEMPS RESTANT : ${timer.formattedTime}", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)
        )
      )
    );
  }

  Future<void> _finaliserStatutPropriete(String nouveauStatut) async {
    await FirebaseFirestore.instance.collection(FirestoreCollections.properties).doc(widget.facture.propertyId).update({
      FactureFields.status: nouveauStatut,
      FactureFields.reservedAt: FieldValue.serverTimestamp(),
      FactureFields.lastLocataireId: widget.facture.clientId,
      FactureFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }
}