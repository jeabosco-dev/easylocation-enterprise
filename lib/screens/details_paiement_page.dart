// lib/screens/details_paiement_page.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/wallet_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/booking_timer_provider.dart';
import '../models/formulaire_publication_model.dart';
import '../widgets/reference_badge_widget.dart';
import '../services/property_service.dart';
import '../services/calculateur_expertise.dart';
import '../services/config_service.dart';
import '../utils/ui_utils.dart';
import 'choix_cadeau_page.dart';

class DetailsPaiementPage extends StatefulWidget {
  final FormulairePublicationModel propriete;
  final OffrePack offre;
  final double? partLocataire; 

  const DetailsPaiementPage({
    super.key,
    required this.propriete,
    required this.offre,
    this.partLocataire,
  });

  @override
  State<DetailsPaiementPage> createState() => _DetailsPaiementPageState();
}

class _DetailsPaiementPageState extends State<DetailsPaiementPage> {
  bool useWallet = true;
  bool usePoints = false;

  Future<double> _fetchWalletBalance(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('wallets').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        
        double balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
        double cashback = (data['cashback_balance'] as num?)?.toDouble() ?? 0.0;
        double bonus = (data['bonusBalance'] as num?)?.toDouble() ?? 0.0;
        double commission = (data['commission_balance'] as num?)?.toDouble() ?? 0.0;

        return balance + cashback + bonus + commission;
      }
    } catch (e) {
      debugPrint("Erreur récupération wallet: $e");
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProfileProvider>(context);
    final userData = userProvider.userData;

    if (userData == null) {
      return const Scaffold(body: Center(child: Text("Utilisateur non connecté")));
    }

    return FutureBuilder<double>(
      future: _fetchWalletBalance(userData.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final double soldeWallet = snapshot.data ?? 0.0;
        
        final double loyer = widget.propriete.price ?? 0.0;
        final double tauxLoc = widget.offre.comLocataire < 1 ? widget.offre.comLocataire * 100 : widget.offre.comLocataire;
        final double partLocataireCalculee = widget.partLocataire ?? (loyer * (tauxLoc / 100));

        return _buildPaymentUI(userData, soldeWallet, partLocataireCalculee);
      },
    );
  }

  Widget _buildPaymentUI(var userData, double soldeWallet, double partLocataire) {
    final config = ConfigService();
    final int pointsDisponibles = userData?.pointsLoyalty ?? 0;

    final String currentClientId = userData?.uid ?? "ID_INCONNU";
    final String currentNomClient = userData != null
        ? "${userData.prenom} ${userData.nom}".trim()
        : "Client EasyLocation";
    final String currentTelClient = userData?.telephone ?? "Non renseigné";

    final double loyer = widget.propriete.price ?? 0.0;
    final double tauxBailleur = widget.offre.comBailleur < 1 ? widget.offre.comBailleur * 100 : widget.offre.comBailleur;
    final double partBailleur = loyer * (tauxBailleur / 100);
    
    final double totalFacture = partLocataire + partBailleur;

    final double limiteMax = partLocataire * 0.25;
    final double montantWalletAAppliquer = math.min(soldeWallet, limiteMax);

    double cashbackAAppliquer = (config.isLoyaltyActive && usePoints) ? pointsDisponibles.toDouble() : 0.0;
    double montantApresPoints = (totalFacture - cashbackAAppliquer).clamp(0.0, double.infinity);
    
    double montantPrisWallet = useWallet ? math.min(montantApresPoints, montantWalletAAppliquer) : 0.0;
    double resteAPayer = (montantApresPoints - montantPrisWallet).clamp(0.0, double.infinity);

    final int moisGarantie = widget.propriete.garantieMinimale ?? 3;
    final double garantieTotale = loyer * moisGarantie;
    final double resteAPayerBailleur = garantieTotale - partBailleur;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Finaliser la réservation", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMiniCard([
                _buildRow("Total Commission", "${UIUtils.formatPrice(totalFacture)} \$"),
                if (config.isLoyaltyActive && pointsDisponibles > 0) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: usePoints,
                    activeColor: Colors.orange,
                    title: Text("Utiliser mes $pointsDisponibles pts", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onChanged: (val) => setState(() => usePoints = val),
                  ),
                ],
                if (soldeWallet > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: useWallet ? Colors.green.shade50 : Colors.grey.shade100, 
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        value: useWallet,
                        activeColor: Colors.green,
                        title: const Text("Paiement Wallet (Automatique)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text("Applique ${UIUtils.formatPrice(montantWalletAAppliquer)} \$ (Plafond 25% de votre part)", style: const TextStyle(fontSize: 11)),
                        onChanged: (val) => setState(() => useWallet = val),
                      ),
                    ),
                  ),
                ],
                const Divider(),
                _buildRow("Net à payer", "${UIUtils.formatPrice(resteAPayer)} \$", isPrimary: true, color: resteAPayer == 0 ? Colors.green : widget.offre.color),
              ]),
              const SizedBox(height: 20),
              _buildInfoBailleur(resteAPayerBailleur, garantieTotale, moisGarantie),
              const SizedBox(height: 40),
              _buildBoutonValidation(
                context, 
                resteAPayer, 
                currentClientId, 
                currentNomClient, 
                currentTelClient, 
                montantPrisWallet, 
                cashbackAAppliquer, 
                partLocataire,
                totalFacture 
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoutonValidation(BuildContext context, double reste, String id, String nom, String tel, double walletUsed, double cashback, double partLocataire, double montantCommissionTotale) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: reste == 0 ? Colors.green : widget.offre.color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: () => _procederAuVerrouillage(context, id, nom, tel, walletUsed, reste, cashback, partLocataire, montantCommissionTotale),
        child: Text(reste == 0 ? "CONFIRMER LA RÉSERVATION" : "CONFIRMER ET PAYER", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _procederAuVerrouillage(BuildContext context, String clientId, String nom, String tel, double walletUsed, double reste, double cashback, double partLocataire, double montantCommissionTotale) async {
    final String? propertyId = widget.propriete.id;
    if (propertyId == null) return;
    
    showDialog(context: context, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    try {
      final double montantFinalWallet = useWallet ? walletUsed : 0.0;

      // Utilisation de la méthode corrigée
      await context.read<WalletProvider>().payForServiceViaCloud(
        serviceId: propertyId,
        serviceType: widget.offre.titre,
        servicePrice: montantCommissionTotale, 
        walletAmountRequested: montantFinalWallet,
        partLocataire: partLocataire,
        factureReference: widget.propriete.referenceUnique // Passage direct de la référence
      );

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => ChoixCadeauPage(clientId: clientId, nomClient: nom, telClient: tel, propriete: widget.propriete, offre: widget.offre, montantWallet: montantFinalWallet, montantExterne: reste, cashbackApplique: cashback)));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        UIUtils.showSnackBar(context, "Erreur: $e", isError: true);
      }
    }
  }

  Widget _buildInfoBailleur(double reste, double totale, int mois) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)), child: Text("Le jour de la remise des clés, vous ne verserez que ${UIUtils.formatPrice(reste)} \$ au bailleur.", style: TextStyle(fontSize: 11, color: Colors.green.shade900)));
  Widget _buildMiniCard(List<Widget> children) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Column(children: children));
  Widget _buildRow(String label, String value, {bool isPrimary = false, Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: 14, fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal)), Text(value, style: TextStyle(fontSize: isPrimary ? 16 : 14, fontWeight: FontWeight.bold, color: color))]));
}