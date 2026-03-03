import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import '../providers/user_profile_provider.dart'; 
import '../providers/booking_timer_provider.dart'; 
import '../models/formulaire_publication_model.dart';
import '../widgets/reference_badge_widget.dart';
import '../services/property_service.dart'; 
import '../services/calculateur_expertise.dart'; 
import 'choix_cadeau_page.dart'; 

class DetailsPaiementPage extends StatelessWidget {
  final FormulairePublicationModel propriete;
  final OffrePack offre; 

  const DetailsPaiementPage({
    super.key,
    required this.propriete,
    required this.offre,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProfileProvider>(context);
    final userData = userProvider.userData;

    // Données client pour la suite
    final String currentClientId = userData?.uid ?? "ID_INCONNU";
    final String currentNomClient = userData != null 
        ? "${userData.prenom} ${userData.nom} ${userData.postnom}".trim()
        : "Client EasyLocation";
    final String currentTelClient = userData?.telephone ?? "Non renseigné";

    // ✅ SÉCURITÉ : Conversion automatique si les taux arrivent en format décimal (ex: 0.1 au lieu de 10)
    final double tauxLoc = offre.comLocataire < 1 ? offre.comLocataire * 100 : offre.comLocataire;
    final double tauxBai = offre.comBailleur < 1 ? offre.comBailleur * 100 : offre.comBailleur;

    // ✅ CALCULS DYNAMIQUES BASÉS SUR LES TAUX SÉCURISÉS
    final double loyer = propriete.price ?? 0.0;
    final double partLocataire = loyer * (tauxLoc / 100);
    final double partBailleur = loyer * (tauxBai / 100);
    
    // Le total immédiat à payer est la somme des deux commissions
    final double totalImmediat = partLocataire + partBailleur;
    
    final int moisGarantie = propriete.garantieMinimale ?? 3; 
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
              child: ReferenceBadgeWidget(reference: propriete.numeroMaison ?? 'N/A'),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER : MONTANT TOTAL ---
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    "${totalImmediat.toStringAsFixed(1)}\$",
                    style: TextStyle(
                      fontSize: 48, 
                      fontWeight: FontWeight.w900, 
                      color: offre.color,
                      letterSpacing: -1
                    ),
                  ),
                  const Text(
                    "TOTAL À RÉGLER MAINTENANT", 
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1 : DÉTAILS DU PAIEMENT ---
                  const Text("DÉTAILS DU RÈGLEMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  _buildMiniCard([
                    // ✅ Affichage du taux corrigé (tauxLoc au lieu de offre.comLocataire)
                    _buildRow("Vos Frais de Service (${tauxLoc.toStringAsFixed(1)}%)", "${partLocataire.toStringAsFixed(1)}\$"),
                    _buildRow("Avance Frais Bailleur (${tauxBai.toStringAsFixed(1)}%)", "${partBailleur.toStringAsFixed(1)}\$"),
                    const Divider(),
                    _buildRow("Total à payer sur l'App", "${totalImmediat.toStringAsFixed(1)}\$", isPrimary: true, color: offre.color),
                  ]),

                  const SizedBox(height: 20),
                  
                  // --- SECTION 2 : NOTE BAILLEUR ---
                  Container(
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
                          "Le propriétaire est déjà informé de cette avance. Le jour de la remise des clés, vous ne lui verserez que le solde de ${resteAPayerBailleur.toStringAsFixed(1)}\$ au lieu de ${garantieTotale.toStringAsFixed(0)}\$ pour les $moisGarantie mois de garantie.",
                          style: TextStyle(fontSize: 11, color: Colors.green.shade900, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  
                  // --- SECTION 3 : MODE DE PAIEMENT (INFOS) ---
                  const Text("MOYENS DE PAIEMENT DISPONIBLES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  _buildPaymentSelector(),

                  const SizedBox(height: 40),

                  // --- BOUTON FINAL ---
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: offre.color,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: () => _procederAuVerrouillage(context, currentClientId, currentNomClient, currentTelClient),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.security, color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text(
                            "CONFIRMER ET PAYER", 
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                          ),
                        ],
                      ),
                    ),
                  ),
                  
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

  // --- LOGIQUE MÉTIER ---

  Future<void> _procederAuVerrouillage(BuildContext context, String clientId, String nom, String tel) async {
    final String? propertyId = propriete.id;
    if (propertyId == null || propertyId.isEmpty) return;

    final timerProvider = context.read<BookingTimerProvider>();

    if (timerProvider.isActive && timerProvider.currentPropertyId == propertyId) {
      _naviguerVersCadeau(context, clientId, nom, tel);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.blue)),
    );

    try {
      final int lockTimestamp = await PropertyService().verrouillerTemporairement(propertyId, clientId);

      if (context.mounted) {
        timerProvider.startTimer(propertyId, lockTimestamp);
        Navigator.pop(context); // Fermer le loader
        _naviguerVersCadeau(context, clientId, nom, tel);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception:", "")), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _naviguerVersCadeau(BuildContext context, String clientId, String nom, String tel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChoixCadeauPage(
          clientId: clientId,
          nomClient: nom,
          telClient: tel,
          propriete: propriete,
          offre: offre, 
          transportSelectionne: false,
        ),
      ),
    );
  }

  // --- WIDGETS DE CONSTRUCTION ---

  Widget _buildMiniCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow(String label, String value, {bool isPrimary = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: isPrimary ? Colors.black : Colors.black54, fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: isPrimary ? 16 : 14, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
        ],
      ),
    );
  }

  Widget _buildPaymentSelector() {
    return Column(
      children: [
        _buildPaymentInfoItem(
          icon: Icons.credit_card,
          title: "MaxiCash (Paiement en ligne)",
          subtitle: "Cartes locales, Visa, Mastercard & Mobile Money",
          isRecommended: true,
        ),
        const SizedBox(height: 10),
        _buildPaymentInfoItem(
          icon: Icons.phone_android,
          title: "Mobile Money Direct",
          subtitle: "M-Pesa, Orange Money, Airtel Money",
        ),
        const SizedBox(height: 10),
        _buildPaymentInfoItem(
          icon: Icons.payments_outlined,
          title: "Paiement Cash",
          subtitle: "Directement au bureau de EasyLocation",
        ),
      ],
    );
  }

  Widget _buildPaymentInfoItem({
    required IconData icon, 
    required String title, 
    required String subtitle, 
    bool isRecommended = false
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isRecommended ? Colors.blue.shade200 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isRecommended ? Colors.blue.shade50 : Colors.grey.shade50,
            child: Icon(icon, color: isRecommended ? Colors.blue : Colors.grey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    if (isRecommended) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                        child: const Text("CONSEILLÉ", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      )
                    ]
                  ],
                ),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}