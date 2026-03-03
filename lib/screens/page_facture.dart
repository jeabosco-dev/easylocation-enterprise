// lib/screens/page_facture.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/facture_model.dart';
import '../services/maxicash_service.dart';
import '../services/facture_service.dart';
import '../providers/booking_timer_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/config_service.dart'; 
import '../widgets/manuel_payment_sheet.dart'; 

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

  // --- LOGIQUE DE CALCULS ---

  double get soldeRestantMainBailleurUSD {
    double garantieTotale = widget.facture.loyer * widget.facture.nbMoisGarantie;
    return garantieTotale - widget.facture.commissionBailleurUSD;
  }

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
    final timerProvider = context.watch<BookingTimerProvider>();
    final configService = context.watch<ConfigService>();
    final double tauxDuJour = configService.tauxUsdCdf;

    if (timerProvider.isExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTimeout(context));
    }

    return Stack(
      children: [
        _buildInterface(context, timerProvider, tauxDuJour),
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  // --- ACTIONS ---

  void _afficherChoixPaiement(BuildContext context, double taux) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SingleChildScrollView( 
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4, 
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text("Mode de règlement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 24),
              
              _buildPaymentOption(
                icon: Icons.credit_card,
                color: Colors.blue,
                title: "MaxiCash (Paiement en ligne)",
                subtitle: "Cartes bancaires, Visa, Mobile Money - Instantané",
                onTap: () { 
                  Navigator.pop(sheetContext);
                  Future.microtask(() {
                    if (mounted) _procederAuPaiement(context, taux, "Maxicash");
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                icon: Icons.phone_android,
                color: Colors.green,
                title: "Mobile Money Direct",
                subtitle: "Transfert Manuel - Vérification (5-30 min)",
                onTap: () { 
                  Navigator.pop(sheetContext);
                  Future.microtask(() {
                    if (mounted) _procederAuPaiement(context, taux, "Manuel");
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                icon: Icons.payments_outlined,
                color: Colors.orange,
                title: "Paiement Cash",
                subtitle: "Validation physique à notre bureau",
                onTap: () { 
                  Navigator.pop(sheetContext);
                  Future.microtask(() {
                    if (mounted) _procederAuPaiement(context, taux, "Cash");
                  });
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _procederAuPaiement(BuildContext context, double taux, String methode) async {
    // 🔥 FORCE DEBUG : Ces lignes DOIVENT s'afficher dans ton terminal VS Code
    debugPrint("🚀 CLIC SUR CONFIRMER : Début de la procédure");
    debugPrint("📱 TÉLÉPHONE DANS L'OBJET : '${widget.facture.telClient}'");
    debugPrint("👤 NOM DU CLIENT : '${widget.facture.nomClient}'");
    debugPrint("💰 MONTANT : ${widget.facture.totalUSD} USD");

    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    // 1. On prépare la référence unique
    final String uniqueFactureId = "FACT-${widget.facture.refMaison}-${DateTime.now().millisecondsSinceEpoch}";

    final factureFinale = widget.facture.copyWith(
      id: uniqueFactureId,
      methodePaiement: methode,
      statut: 'pending',
    );
    
    double montantUI = (deviseSelectionnee == "USD") 
        ? factureFinale.totalUSD 
        : factureFinale.totalCDF;

    try {
      // 2. Création de la facture dans la DB
      await _factureService.creerFacture(factureFinale);
      
      if (!mounted) return;
      context.read<UserProfileProvider>().setLastFacture(factureFinale);

      if (methode == "Maxicash") {
        // --- SÉCURITÉ LOCALE ---
        if (factureFinale.telClient.isEmpty || factureFinale.totalUSD <= 0) {
          debugPrint("❌ ARRÊT : Données manquantes détectées !");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erreur : Téléphone ou montant manquant dans votre profil."), backgroundColor: Colors.red)
          );
          setState(() => _isProcessing = false);
          return;
        }

        debugPrint("🔗 APPEL MAXICASH SERVICE...");
        await MaxicashService.encaisserAcompte(
          context: context,
          telephone: factureFinale.telClient,
          referenceCommande: uniqueFactureId,
          onSuccess: () {
            if (mounted) {
              context.read<BookingTimerProvider>().stopTimer();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ Paiement validé avec succès !"), backgroundColor: Colors.green)
              );
              
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              });
            }
          },
          onCancel: () {
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("⚠️ Paiement interrompu."), backgroundColor: Colors.orange)
              );
             }
          },
        );
      } else if (methode == "Manuel") {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (context) => ManuelPaymentSheet(
            facture: factureFinale,
            montantFinal: montantUI,
            devise: deviseSelectionnee,
          ),
        );
      } else {
        if (!mounted) return;
        _afficherConfirmationCash(context, factureFinale);
      }
    } catch (e) {
      debugPrint("🚨 ERREUR SYSTEME : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur système: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _afficherConfirmationCash(BuildContext context, FactureModel facture) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Réservation enregistrée"),
        content: const Text("Passez à notre bureau sous 24h pour valider votre paiement en espèces."),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  // --- INTERFACE PRINCIPALE ---

  Widget _buildInterface(BuildContext context, BookingTimerProvider timer, double taux) {
    final currencyUSD = NumberFormat.currency(locale: 'en_US', symbol: '\$ ', decimalDigits: 2);
    final currencyCDF = NumberFormat.currency(locale: 'fr_CD', symbol: 'FC ', decimalDigits: 0);

    String totalAffiche = (deviseSelectionnee == "USD") 
        ? currencyUSD.format(widget.facture.totalUSD) 
        : currencyCDF.format(widget.facture.totalCDF);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Finalisation Réservation", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          _buildTimerBanner(timer.formattedTime),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildEntete(),
                  const SizedBox(height: 25),
                  _buildClientBienInfo(),
                  const Divider(height: 40),
                  _buildTableauPrix(currencyUSD, totalAffiche),
                  const SizedBox(height: 25),
                  _buildDeviseSelector(),
                  const SizedBox(height: 30),
                  _buildNoteBailleur(currencyUSD),
                  const SizedBox(height: 30),
                  _buildBoutonPaiement(timer),
                  const SizedBox(height: 20),
                  const Text("EasyLocation Enterprise - N° Impôt : A2301893J", style: TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntete() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Text("EasyLocation Enterprise", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0D47A1))),
        Text("Gestion immobilière & Services", style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
      const Icon(Icons.verified_user_rounded, size: 40, color: Color(0xFF0D47A1)),
    ],
  );

  Widget _buildClientBienInfo() => Row(children: [
    Expanded(child: _buildInfoColumn("CLIENT", widget.facture.nomClient, widget.facture.telClient)),
    Expanded(child: _buildInfoColumn("REF. MAISON", widget.facture.refMaison, widget.facture.commune ?? 'Ville', isRight: true)),
  ]);

  Widget _buildTableauPrix(NumberFormat format, String totalAffiche) => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(15), 
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
    ),
    child: Column(children: [
      _buildPriceRow("Frais de Service (${widget.facture.comLocatairePercent.toStringAsFixed(1)}%)", widget.facture.commissionLocataireUSD, format),
      _buildPriceRow("Acompte Garantie (${widget.facture.comBailleurPercent.toStringAsFixed(1)}%)", widget.facture.commissionBailleurUSD, format),
      _buildPriceRow(
        "TOTAL À PAYER SUR L'APP", 
        widget.facture.totalUSD, 
        format, 
        isTotal: true, 
        customTotalDisplay: totalAffiche
      ),
    ]),
  );

  Widget _buildNoteBailleur(NumberFormat format) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
    child: Column(children: [
      Row(children: [
        Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 20),
        const SizedBox(width: 10),
        const Text("SOLDE BAILLEUR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
      ]),
      const SizedBox(height: 8),
      Text(
        "Le propriétaire est informé de l'acompte de ${format.format(widget.facture.commissionBailleurUSD)} payé ici. Le solde de ${format.format(soldeRestantMainBailleurUSD)} sera versé directement au bailleur.",
        style: TextStyle(fontSize: 11, color: Colors.blue.shade900, height: 1.4),
      ),
    ]),
  );

  Widget _buildBoutonPaiement(BookingTimerProvider timer) => SizedBox(
    width: double.infinity, height: 60,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: (timer.isExpired || _isProcessing) ? Colors.grey : const Color(0xFF0D47A1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: (timer.isExpired || _isProcessing) ? null : () => _afficherChoixPaiement(context, widget.facture.tauxApplique),
      child: const Text("CONFIRMER ET PAYER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _buildTimerBanner(String time) => Container(width: double.infinity, color: Colors.orange.shade800, padding: const EdgeInsets.symmetric(vertical: 6), child: Center(child: Text("TEMPS RESTANT : $time", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))));
  
  Widget _buildInfoColumn(String titre, String nom, String info, {bool isRight = false}) => Column(crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [Text(titre, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)), Text(nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(info, style: const TextStyle(fontSize: 11))]);

  Widget _buildPriceRow(String label, double prix, NumberFormat format, {bool isTotal = false, String? customTotalDisplay}) => Container(
    padding: const EdgeInsets.all(15), 
    decoration: BoxDecoration(
        color: isTotal ? (deviseSelectionnee == "USD" ? const Color(0xFF0D47A1) : Colors.green.shade800) : Colors.transparent, 
        borderRadius: isTotal ? const BorderRadius.vertical(bottom: Radius.circular(14)) : null
    ), 
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: isTotal ? Colors.white : Colors.black87, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 11.5 : 12.5)),
      Text(customTotalDisplay ?? format.format(prix), style: TextStyle(fontWeight: FontWeight.bold, color: isTotal ? Colors.white : Colors.black, fontSize: isTotal ? 18 : 14))
    ]));

  Widget _buildDeviseSelector() => Row(children: [
    Expanded(child: _buildCurrencyOption("USD", "\$ USD")),
    const SizedBox(width: 10),
    Expanded(child: _buildCurrencyOption("CDF", "FC CDF")),
  ]);

  Widget _buildCurrencyOption(String code, String label) {
    bool isSelected = deviseSelectionnee == code;
    return GestureDetector(
      onTap: () => setState(() => deviseSelectionnee = code),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? (code == "USD" ? const Color(0xFF0D47A1) : Colors.green.shade700) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300)
        ),
        child: Center(child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
      ),
    );
  }
}