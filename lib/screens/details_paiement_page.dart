// lib/pages/details_paiement_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import '../providers/user_profile_provider.dart'; 
import '../providers/booking_timer_provider.dart'; 
import '../models/formulaire_publication_model.dart';
import '../models/property_model.dart'; 
import '../widgets/reference_badge_widget.dart';
import '../services/property_service.dart'; 
import '../services/calculateur_expertise.dart'; 
import '../services/config_service.dart'; // ✅ Import de ConfigService
import '../utils/ui_utils.dart'; 
import 'choix_cadeau_page.dart'; 

class DetailsPaiementPage extends StatefulWidget {
  final FormulairePublicationModel propriete;
  final OffrePack offre; 

  const DetailsPaiementPage({
    super.key,
    required this.propriete,
    required this.offre,
  });

  @override
  State<DetailsPaiementPage> createState() => _DetailsPaiementPageState();
}

class _DetailsPaiementPageState extends State<DetailsPaiementPage> {
  bool useWallet = true; // Par défaut, on propose d'utiliser le Wallet
  bool usePoints = false; // ✅ État pour l'utilisation des points de fidélité

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProfileProvider>(context);
    final userData = userProvider.userData;
    final config = ConfigService(); // ✅ Instance de config

    // --- DONNÉES UTILISATEUR & FIDÉLITÉ ---
    final double soldeWallet = userData?.walletBalance ?? 0.0;
    final int pointsDisponibles = userData?.pointsLoyalty ?? 0;
    
    final String currentClientId = userData?.uid ?? "ID_INCONNU";
    final String currentNomClient = userData != null 
        ? "${userData.prenom} ${userData.nom}".trim()
        : "Client EasyLocation";
    final String currentTelClient = userData?.telephone ?? "Non renseigné";

    // --- CALCULS DES COMMISSIONS ---
    final double tauxLoc = widget.offre.comLocataire < 1 ? widget.offre.comLocataire * 100 : widget.offre.comLocataire;
    final double tauxBai = widget.offre.comBailleur < 1 ? widget.offre.comBailleur * 100 : widget.offre.comBailleur;

    final double loyer = widget.propriete.price ?? 0.0;
    final double partLocataire = loyer * (tauxLoc / 100);
    final double partBailleur = loyer * (tauxBai / 100);
    final double totalFacture = partLocataire + partBailleur;
    
    // ✅ LOGIQUE CASHBACK (POINTS FIDÉLITÉ)
    // 1 point = 1$ (selon ta logique métier actuelle)
    double cashbackAAppliquer = (config.isLoyaltyActive && usePoints) 
        ? pointsDisponibles.toDouble() 
        : 0.0;

    // --- LOGIQUE DU PAIEMENT MIXTE (LE QUINTET : Facture - Points - Wallet) ---
    double montantApresPoints = (totalFacture - cashbackAAppliquer).clamp(0.0, double.infinity);
    double montantPrisWallet = 0.0;
    double resteAPayer = montantApresPoints;

    if (useWallet && soldeWallet > 0) {
      if (soldeWallet >= montantApresPoints) {
        montantPrisWallet = montantApresPoints;
        resteAPayer = 0.0;
      } else {
        montantPrisWallet = soldeWallet;
        resteAPayer = montantApresPoints - soldeWallet;
      }
    }

    // Calcul pour information bailleur
    final int moisGarantie = widget.propriete.garantieMinimale ?? 3; 
    final double garantieTotale = loyer * moisGarantie;
    final double resteAPayerBailleur = garantieTotale - partBailleur;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Finaliser la réservation", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ReferenceBadgeWidget(reference: widget.propriete.referenceUnique),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER : RÉSUMÉ FINANCIER ---
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    "${UIUtils.formatPrice(resteAPayer)} \$",
                    style: TextStyle(
                      fontSize: 48, 
                      fontWeight: FontWeight.w900, 
                      color: resteAPayer == 0 ? Colors.green : widget.offre.color,
                      letterSpacing: -1
                    ),
                  ),
                  Text(
                    resteAPayer == 0 ? "PAYÉ (WALLET/POINTS)" : "RESTE À RÉGLER", 
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1 : CALCUL DÉTAILLÉ ---
                  const Text("DÉTAILS DU RÈGLEMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  _buildMiniCard([
                    _buildRow("Total Commission", "${UIUtils.formatPrice(totalFacture)} \$"),
                    
                    // ✅ SECTION FIDÉLITÉ (POINTS)
                    if (config.isLoyaltyActive && pointsDisponibles > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: SwitchListTile(
                          value: usePoints,
                          activeColor: Colors.orange,
                          title: Text("Utiliser mes $pointsDisponibles points", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text("Économisez ${pointsDisponibles} \$ sur vos frais", style: const TextStyle(fontSize: 11)),
                          onChanged: (val) => setState(() => usePoints = val),
                        ),
                      ),
                    ],

                    // --- WALLET ---
                    if (soldeWallet > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: useWallet ? Colors.green.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: useWallet, 
                                  activeColor: Colors.green,
                                  onChanged: (val) => setState(() => useWallet = val ?? true)
                                ),
                                Text("Utiliser mon Wallet", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: useWallet ? Colors.green.shade800 : Colors.grey)),
                              ],
                            ),
                            Text("- ${UIUtils.formatPrice(montantPrisWallet)} \$", style: TextStyle(fontWeight: FontWeight.bold, color: useWallet ? Colors.green : Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                    
                    const Divider(),
                    _buildRow(
                      resteAPayer == 0 ? "Statut" : "Net à payer", 
                      resteAPayer == 0 ? "SOLDE COUVERT" : "${UIUtils.formatPrice(resteAPayer)} \$", 
                      isPrimary: true, 
                      color: resteAPayer == 0 ? Colors.green : widget.offre.color
                    ),
                  ]),

                  const SizedBox(height: 20),
                  
                  // --- SECTION 2 : NOTE BAILLEUR ---
                  _buildInfoBailleur(resteAPayerBailleur, garantieTotale, moisGarantie),

                  const SizedBox(height: 30),
                  
                  // --- SECTION 3 : MODES DE PAIEMENT ---
                  if (resteAPayer > 0) ...[
                    const Text("CHOISIR UN MOYEN DE PAIEMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                    const SizedBox(height: 10),
                    _buildPaymentSelector(),
                  ] else ...[
                    _buildWalletFullSuccessMessage(soldeWallet - montantPrisWallet),
                  ],

                  const SizedBox(height: 40),

                  // --- BOUTON FINAL ---
                  _buildBoutonValidation(context, resteAPayer, currentClientId, currentNomClient, currentTelClient, montantPrisWallet, cashbackAAppliquer),
                  
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      "Paiement 100% protégé. Satisfait ou remboursé.", 
                      style: TextStyle(color: Colors.grey, fontSize: 11)
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIAIRES ---

  Widget _buildInfoBailleur(double reste, double totale, int mois) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 10),
              const Text("AVANCE RECONNUE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Le jour de la remise des clés, vous ne verserez que ${UIUtils.formatPrice(reste)} \$ au bailleur (après déduction de l'avance) pour les $mois mois de garantie.",
            style: TextStyle(fontSize: 11, color: Colors.green.shade900, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletFullSuccessMessage(double nouveauSolde) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.stars, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(child: Text("Félicitations ! Votre solde couvre la totalité. Nouveau solde estimé : ${UIUtils.formatPrice(nouveauSolde)} \$", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
        ],
      ),
    );
  }

  Widget _buildBoutonValidation(BuildContext context, double reste, String id, String nom, String tel, double walletUsed, double cashback) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: reste == 0 ? Colors.green : widget.offre.color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        onPressed: () => _procederAuVerrouillage(context, id, nom, tel, walletUsed, reste, cashback),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(reste == 0 ? Icons.flash_on : Icons.security, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              reste == 0 ? "CONFIRMER LA RÉSERVATION" : "CONFIRMER ET PAYER", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
            ),
          ],
        ),
      ),
    );
  }

  // --- LOGIQUE MÉTIER ---

  Future<void> _procederAuVerrouillage(BuildContext context, String clientId, String nom, String tel, double walletUsed, double externe, double cashback) async {
    final String? propertyId = widget.propriete.id;
    if (propertyId == null) return;

    showDialog(context: context, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      final int lockTimestamp = await PropertyService().verrouillerTemporairement(propertyId, clientId);
      
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChoixCadeauPage(
              clientId: clientId,
              nomClient: nom,
              telClient: tel,
              propriete: widget.propriete,
              offre: widget.offre,
              montantWallet: walletUsed,
              montantExterne: externe,
              cashbackApplique: cashback, // ✅ On passe le montant des points déduits
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        UIUtils.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  Widget _buildMiniCard(List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
    child: Column(children: children),
  );

  Widget _buildRow(String label, String value, {bool isPrimary = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: isPrimary ? 16 : 14, fontWeight: FontWeight.bold, color: color)),
      ],
    ),
  );

  Widget _buildPaymentSelector() => Column(children: [
    _buildPaymentOption(Icons.credit_card, "MaxiCash / Mobile Money Online", "Traitement instantané", true),
    const SizedBox(height: 10),
    _buildPaymentOption(Icons.payments_outlined, "Paiement Cash au Bureau", "Validation sous 24h", false),
  ]);

  Widget _buildPaymentOption(IconData icon, String title, String subtitle, bool recommended) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(border: Border.all(color: recommended ? Colors.blue : Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon, color: recommended ? Colors.blue : Colors.grey),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ])),
    ]),
  );
}