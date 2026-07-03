// lib/screens/details_paiement_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/user_profile_provider.dart';
import '../providers/booking_timer_provider.dart';
import '../models/formulaire_publication_model.dart';
import '../models/facture_model.dart';
import '../services/calculateur_expertise.dart';
import '../services/config_service.dart';
import '../services/property_service.dart';
import '../utils/ui_utils.dart';
import '../utils/financial_utils.dart';
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

  Future<int> _fetchWalletBalance(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('wallets').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        double total = (data['balance'] as num? ?? 0.0).toDouble() +
                       (data['cashback_balance'] as num? ?? 0.0).toDouble() +
                       (data['bonusBalance'] as num? ?? 0.0).toDouble() +
                       (data['commission_balance'] as num? ?? 0.0).toDouble();
        return FinancialHelper.toCents(total);
      }
    } catch (e) {
      debugPrint("Erreur récupération wallet: $e");
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProfileProvider>(context);
    final userData = userProvider.userData;

    if (userData == null) {
      return const Scaffold(body: Center(child: Text("Utilisateur non connecté")));
    }

    return FutureBuilder<int>(
      future: _fetchWalletBalance(userData.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return _buildPaymentUI(userData, snapshot.data ?? 0);
      },
    );
  }

  Widget _buildPaymentUI(var userData, int soldeWalletCents) {
    final configService = Provider.of<ConfigService>(context, listen: false);
    
    final calcul = CalculateurExpertise.calculerFacture(
      prixLoyer: widget.propriete.price ?? 0.0,
      comLocataire: widget.offre.comLocataire,
      comBailleur: widget.offre.comBailleur,
      soldeWallet: soldeWalletCents,
      pointsLoyalty: userData.pointsLoyalty ?? 0,
      moisGarantie: widget.propriete.garantieMinimale ?? 3,
      useWallet: useWallet,
      usePoints: usePoints,
      isLoyaltyActive: configService.isLoyaltyActive,
      config: configService, 
    );

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
                _buildRow("Total Commission", "${UIUtils.formatCents(calcul.totalCommission)} \$"),
                if (configService.isLoyaltyActive && (userData.pointsLoyalty ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: usePoints,
                    activeColor: Colors.orange,
                    title: Text("Utiliser mes ${userData.pointsLoyalty} pts", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onChanged: (val) => setState(() => usePoints = val),
                  ),
                ],
                if (soldeWalletCents > 0) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: useWallet,
                    activeColor: Colors.green,
                    title: const Text("Paiement Wallet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text("Applique ${UIUtils.formatCents(calcul.montantWalletApplique)} \$", style: const TextStyle(fontSize: 11)),
                    onChanged: (val) => setState(() => useWallet = val),
                  ),
                ],
                const Divider(),
                _buildRow("Net à payer", "${UIUtils.formatCents(calcul.resteAPayer)} \$", isPrimary: true, color: calcul.resteAPayer == 0 ? Colors.green : widget.offre.color),
              ]),
              const SizedBox(height: 20),
              _buildInfoBailleur(calcul.resteAPayerBailleur),
              const SizedBox(height: 40),
              _buildBoutonValidation(context, calcul),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoutonValidation(BuildContext context, CalculPaiement calcul) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: calcul.resteAPayer == 0 ? Colors.green : widget.offre.color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: () => _procederAuVerrouillage(context, calcul),
        child: Text(calcul.resteAPayer == 0 ? "CONFIRMER LA RÉSERVATION" : "CONFIRMER ET PAYER", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _procederAuVerrouillage(BuildContext context, CalculPaiement calcul) async {
    final propertyId = widget.propriete.id;
    if (propertyId == null) return;
    
    final userProvider = context.read<UserProfileProvider>();
    final timerProvider = context.read<BookingTimerProvider>();
    final userData = userProvider.userData!;
    
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    try {
      final int lockTimestamp = await PropertyService().verrouillerTemporairement(propertyId, userData.uid);
      timerProvider.startTimer(propertyId, lockTimestamp, null);

      final nouvelleFacture = FactureModel(
        propertyId: propertyId,
        clientId: userData.uid,
        nomClient: "${userData.prenom} ${userData.nom}",
        telClient: userData.telephone ?? "",
        refMaison: widget.propriete.referenceUnique ?? '',
        loyer: widget.propriete.price ?? 0.0,
        
        // Localisation
        province: widget.propriete.province,
        ville: widget.propriete.ville,
        commune: widget.propriete.commune,
        
        // Mapping spécifique pour la logique de promotion
        categorieBien: widget.propriete.typeBien,
        typeService: "LOCATION", 
        
        nomOffre: widget.offre.titre,
        comLocatairePercent: widget.offre.comLocataire,
        comBailleurPercent: widget.offre.comBailleur,
        
        // Transmission de la part locataire
        partLocataire: widget.partLocataire,
        
        montantWallet: FinancialHelper.fromCents(calcul.montantWalletApplique),
        montantExterne: FinancialHelper.fromCents(calcul.resteAPayer),
        montantCashback: usePoints ? (userData.pointsLoyalty ?? 0).toDouble() : 0.0,
        totalNetUSD: FinancialHelper.fromCents(calcul.totalCommission),
      );

      // 2. Navigation
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => ChoixCadeauPage(
          facture: nouvelleFacture,
          propriete: widget.propriete,
          offre: widget.offre,
        )));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        UIUtils.showSnackBar(context, "Erreur: $e", isError: true);
      }
    }
  }

  Widget _buildInfoBailleur(int resteBailleurCents) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)), child: Text("Le jour de la remise des clés, vous ne verserez que ${UIUtils.formatCents(resteBailleurCents)} \$ au bailleur.", style: TextStyle(fontSize: 11, color: Colors.green.shade900)));
  Widget _buildMiniCard(List<Widget> children) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Column(children: children));
  Widget _buildRow(String label, String value, {bool isPrimary = false, Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: 14, fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal)), Text(value, style: TextStyle(fontSize: isPrimary ? 16 : 14, fontWeight: FontWeight.bold, color: color))]));
}