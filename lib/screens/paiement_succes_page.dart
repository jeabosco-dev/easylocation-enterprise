// lib/screens/paiement_succes_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/facture_model.dart';
import '../services/pdf_service.dart';
import '../services/config_service.dart';
import '../providers/user_profile_provider.dart';
import '../utils/ui_utils.dart';

class PaiementSuccesPage extends StatefulWidget {
  const PaiementSuccesPage({super.key});

  @override
  State<PaiementSuccesPage> createState() => _PaiementSuccesPageState();
}

class _PaiementSuccesPageState extends State<PaiementSuccesPage> {
  bool _isExporting = false; // Pour éviter les doubles clics pendant l'export

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProfileProvider>();
    final config = context.watch<ConfigService>(); 
    
    final FactureModel? facture = userProvider.lastFactureGenere;

    if (facture == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String dateFormatee =
        DateFormat('dd/MM/yyyy à HH:mm').format(facture.dateCreation ?? DateTime.now());

    final bool estUnService = facture.propertyId == 'SERVICE';
    final String titreRecap = estUnService ? "Service commandé" : "Référence Bien";
    final String messageSucces = estUnService 
        ? "Votre commande de service a été enregistrée. Notre équipe vous contactera pour confirmer l'heure d'intervention."
        : "Votre réservation a été enregistrée avec succès. Notre équipe valide votre paiement et vous contactera pour la remise des clés.";

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _quitterEtNettoyer(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 100,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Paiement Confirmé !",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  messageSucces, 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, height: 1.4, fontSize: 14),
                ),
                const SizedBox(height: 35),

                // --- RÉCAPITULATIF ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow("N° Facture", facture.id ?? "N/A"),
                      const Divider(height: 20),
                      _buildSummaryRow("Date", dateFormatee),
                      const Divider(height: 20),
                      _buildSummaryRow(titreRecap, estUnService ? facture.nomOffre : facture.refMaison),
                      
                      if (facture.montantCashback > 0) ...[
                        const Divider(height: 20),
                        _buildSummaryRow(
                          "Réduction Points", 
                          "- \$ ${UIUtils.formatPrice(facture.montantCashback)}",
                          customColor: Colors.green.shade700
                        ),
                      ],

                      const Divider(height: 20),
                      _buildSummaryRow(
                        "Montant Payé",
                        "\$ ${UIUtils.formatPrice(facture.totalUSD, decimalDigits: 2)}",
                        isBold: true,
                      ),

                      if (facture.cadeauId != null && facture.cadeauId != "Aucun") ...[
                        const Divider(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.card_giftcard, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Cadeau offert : ${facture.cadeauId} ${facture.cadeauStyle != null ? '(${facture.cadeauStyle})' : ''}",
                                style: const TextStyle(
                                  color: Colors.orange, 
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 12
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ✅ SAUVEGARDE : Utilisation de async/await et retrait du paramètre context
                _buildActionButton(
                  context,
                  label: _isExporting ? "TRAITEMENT..." : "SAUVEGARDER MON REÇU",
                  icon: Icons.download_for_offline_rounded,
                  color: const Color(0xFF0D47A1),
                  onPressed: _isExporting ? () {} : () async {
                    setState(() => _isExporting = true);
                    await PdfService.sauvegarderFacture(
                      facture, 
                      config.companyInfo, 
                      estPaye: true
                    );
                    if (mounted) setState(() => _isExporting = false);
                  },
                ),

                const SizedBox(height: 12),

                // ✅ PARTAGE : Utilisation de async/await
                _buildActionButton(
                  context,
                  label: "PARTAGER LE REÇU",
                  icon: Icons.share_rounded,
                  color: Colors.green.shade700,
                  onPressed: () async {
                    await PdfService.genererEtPartagerFacture(
                      context,
                      facture,
                      config.companyInfo,
                      estPaye: true,
                    );
                  },
                ),

                const SizedBox(height: 40),

                TextButton(
                  onPressed: () => _quitterEtNettoyer(context),
                  child: Text(
                    "RETOUR À L'ACCUEIL",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? customColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
              color: customColor ?? (isBold ? const Color(0xFF0D47A1) : Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  void _quitterEtNettoyer(BuildContext context) {
    context.read<UserProfileProvider>().setLastFacture(null);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildActionButton(BuildContext context,
      {required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: onPressed,
      ),
    );
  }
}