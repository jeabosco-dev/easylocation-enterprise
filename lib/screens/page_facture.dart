// lib/screens/page_facture.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/facture_model.dart';
import '../services/maxicash_service.dart';
import '../providers/booking_timer_provider.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/manuel_payment_sheet.dart'; 

class FacturePage extends StatefulWidget {
  final FactureModel facture;

  const FacturePage({super.key, required this.facture});

  @override
  State<FacturePage> createState() => _FacturePageState();
}

class _FacturePageState extends State<FacturePage> {
  String deviseSelectionnee = "USD";

  void _handleTimeout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Session expirée",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
            "Le temps imparti pour finaliser votre réservation est écoulé. La maison est de nouveau disponible pour les autres clients."),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text("RETOUR À L'ACCUEIL",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerProvider = context.watch<BookingTimerProvider>();
    final userProvider = context.watch<UserProfileProvider>();
    final double tauxDuJour = userProvider.tauxChange;

    if (timerProvider.isExpired) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _handleTimeout(context));
    }

    return _buildInterface(context, timerProvider, tauxDuJour);
  }

  // ✅ CHOIX DU MODE DE PAIEMENT
  void _afficherChoixPaiement(BuildContext context, double taux) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Comment souhaitez-vous payer ?", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 20),
            
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.blue, size: 30),
              title: const Text("Carte Bancaire / MaxiCash"),
              subtitle: const Text("Paiement électronique instantané"),
              onTap: () {
                Navigator.pop(context);
                _procederAuPaiementMaxicash(context, taux);
              },
            ),
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.green, size: 30),
              title: const Text("Mobile Money (Transfert Manuel)"),
              subtitle: const Text("M-Pesa, Orange Money, Airtel Money"),
              onTap: () {
                Navigator.pop(context);
                _ouvrirPaiementManuel(context, taux);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ✅ ACTION 1 : MAXICASH
  void _procederAuPaiementMaxicash(BuildContext context, double taux) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.blue)),
    );

    try {
      final factureFinale = _genererFactureFinale(taux, methode: "Maxicash");
      context.read<UserProfileProvider>().setLastFacture(factureFinale);

      double montantFinal = (deviseSelectionnee == "USD")
          ? factureFinale.totalUSD
          : factureFinale.totalUSD * taux;

      if (context.mounted) Navigator.pop(context);

      await MaxicashService.encaisserAcompte(
        context: context,
        montant: montantFinal,
        devise: deviseSelectionnee,
        telephone: factureFinale.telClient,
        referenceCommande: "FACT-${factureFinale.refMaison}-${DateTime.now().millisecondsSinceEpoch}",
        onSuccess: () {
          context.read<BookingTimerProvider>().stopTimer();
        },
        onCancel: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Paiement annulé."), backgroundColor: Colors.orange),
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur technique : $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ ACTION 2 : PAIEMENT MANUEL
  void _ouvrirPaiementManuel(BuildContext context, double taux) {
    final factureFinale = _genererFactureFinale(taux, methode: "Manuel");
    
    double montantFinal = (deviseSelectionnee == "USD")
          ? factureFinale.totalUSD
          : factureFinale.totalUSD * taux;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ManuelPaymentSheet(
        facture: factureFinale,
        montantFinal: montantFinal,
        devise: deviseSelectionnee,
      ),
    );
  }

  // ✅ FONCTION UTILITAIRE CORRIGÉE : STATUTS LOGISTIQUES ET GÉOGRAPHIE DYNAMIQUE
  FactureModel _genererFactureFinale(double taux, {required String methode}) {
    return FactureModel(
      propertyId: widget.facture.propertyId,
      clientId: widget.facture.clientId,
      nomClient: widget.facture.nomClient,
      telClient: widget.facture.telClient,
      nomBailleur: widget.facture.nomBailleur,
      telBailleur: widget.facture.telBailleur,
      refMaison: widget.facture.refMaison,
      loyer: widget.facture.loyer,
      nbMoisGarantie: widget.facture.nbMoisGarantie,
      nomOffre: widget.facture.nomOffre,
      comLocatairePercent: widget.facture.comLocatairePercent,
      transportChoisi: widget.facture.transportChoisi,
      tauxApplique: taux, 
      cadeauId: widget.facture.cadeauId,
      cadeauTaille: widget.facture.cadeauTaille,
      cadeauStyle: widget.facture.cadeauStyle,
      
      // Localisation récupérée dynamiquement de la maison (Prêt pour toute la RDC)
      province: widget.facture.province, 
      ville: widget.facture.ville,
      commune: widget.facture.commune,

      statut: 'pending', 
      methodePaiement: methode, 
      urlPreuve: widget.facture.urlPreuve,

      // --- NOUVEAUX STATUTS LOGISTIQUES ---
      statutCadeau: (widget.facture.cadeauId == null || widget.facture.cadeauId == 'Aucun') 
          ? 'termine' 
          : 'nouveau',
      statutTransport: widget.facture.transportChoisi ? 'nouveau' : 'termine',
    );
  }

  // --- INTERFACE GRAPHIQUE ---
  
  Widget _buildInterface(BuildContext context, BookingTimerProvider timer, double taux) {
    final currencyUSD = NumberFormat.currency(locale: 'en_US', symbol: '\$ ', decimalDigits: 2);
    final f = widget.facture;
    double avanceBailleurUSD = f.loyer * 0.15;
    double resteAPayerBailleurUSD = (f.loyer * f.nbMoisGarantie) - avanceBailleurUSD;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Votre Facture", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          _buildTimerBanner(timer.formattedTime),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEnteteSociete(),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildInfoColumn("LOCATAIRE", f.nomClient, f.telClient)),
                      Expanded(child: _buildInfoColumn("RÉF. BIEN", f.refMaison, "${f.commune ?? ''}, ${f.ville ?? ''}", isRight: true)),
                    ],
                  ),
                  const Divider(height: 40),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow("Frais de Service (Commission)", f.commissionUSD, currencyUSD),
                        _buildPriceRow("Avance sur Garantie (Acompte)", avanceBailleurUSD, currencyUSD),
                        if (f.transportChoisi) _buildPriceRow("Transport & Logistique", 10.0, currencyUSD),
                        const Divider(height: 1),
                        _buildPriceRow("TOTAL À PAYER MAINTENANT", f.totalUSD, currencyUSD, isTotal: true, color: const Color(0xFF0D47A1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text("Choisissez la devise pour le paiement :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildCurrencyOption("USD", "\$ Dollar USD", deviseSelectionnee == "USD")),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCurrencyOption("CDF", "FC Franc CDF", deviseSelectionnee == "CDF")),
                    ],
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: timer.isExpired ? Colors.grey : (deviseSelectionnee == "USD" ? const Color(0xFF0D47A1) : Colors.green.shade700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: timer.isExpired ? null : () => _afficherChoixPaiement(context, taux),
                      child: const Text(
                        "PROCÉDER AU PAIEMENT",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildHormoziSection(
                    title: "💡 SOLDE RESTANT AU BAILLEUR",
                    content: "Le solde restant de ${currencyUSD.format(resteAPayerBailleurUSD)} sera à verser directement au propriétaire lors de la remise des clés.",
                    color: Colors.orange.shade50,
                    icon: Icons.info_outline,
                    iconColor: Colors.orange.shade900,
                  ),
                  const SizedBox(height: 20),
                  _buildPiedDePageLegal(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS DE SOUTIEN ---

  Widget _buildTimerBanner(String time) {
    return Container(
      width: double.infinity,
      color: Colors.red.shade600,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text("TEMPS RESTANT : $time", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCurrencyOption(String code, String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => deviseSelectionnee = code),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? (code == "USD" ? const Color(0xFF0D47A1) : Colors.green.shade700) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
        ),
        child: Center(child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildEnteteSociete() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("EASY LOCATION SARLU", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900)),
            const Text("Service de gestion immobilière", style: TextStyle(fontSize: 11)),
          ],
        ),
        const Icon(Icons.apartment_rounded, size: 40, color: Colors.blue),
      ],
    );
  }

  Widget _buildInfoColumn(String titre, String nom, String info, {bool isRight = false}) {
    return Column(
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(titre, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
        Text(info, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Widget _buildPriceRow(String label, double prix, NumberFormat format, {bool isTotal = false, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: isTotal ? (color ?? Colors.blue.shade900) : Colors.transparent,
        borderRadius: isTotal ? const BorderRadius.vertical(bottom: Radius.circular(14)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isTotal ? Colors.white : Colors.black87, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(format.format(prix), style: TextStyle(fontWeight: FontWeight.bold, color: isTotal ? Colors.white : Colors.black, fontSize: isTotal ? 18 : 14)),
        ],
      ),
    );
  }

  Widget _buildHormoziSection({required String title, required String content, required Color color, required IconData icon, required Color iconColor}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12), border: Border.all(color: iconColor.withOpacity(0.1))),
      child: Row(
        children: [
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: iconColor)),
            Text(content, style: const TextStyle(fontSize: 11, color: Colors.black87)),
          ])),
        ],
      ),
    );
  }

  Widget _buildPiedDePageLegal() {
    return const Center(child: Text("N° Impôt : A2301893J | Document officiel généré par Easy Location SARLU", style: TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center));
  }
}
