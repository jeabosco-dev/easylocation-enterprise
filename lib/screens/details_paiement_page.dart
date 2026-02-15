// lib/screens/details_paiement_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import '../providers/user_profile_provider.dart'; 
import '../providers/booking_timer_provider.dart'; 
import '../models/formulaire_publication_model.dart';
import '../widgets/reference_badge_widget.dart';
import '../services/property_service.dart'; 
// ✅ Import nécessaire pour utiliser l'objet OffrePack
import '../services/calculateur_expertise.dart'; 
import 'logistique_demenagement_page.dart';

class DetailsPaiementPage extends StatelessWidget {
  final FormulairePublicationModel propriete;
  // ✅ Synchronisation : On utilise maintenant l'objet typé
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

    final String currentClientId = userData?.uid ?? "ID_INCONNU";
    final String currentNomClient = userData != null 
        ? "${userData.prenom} ${userData.nom} ${userData.postnom}".trim()
        : "Client EasyLocation";
    final String currentTelClient = userData?.telephone ?? "Non renseigné";

    // ✅ CALCULS SYNCHRONISÉS AVEC LE MOTEUR D'EXPERTISE
    final double loyer = propriete.price ?? 0.0;
    
    // On récupère les pourcentages directement depuis l'objet OffrePack
    final double comLocatairePourcentage = offre.comLocataire / 100;
    final double comBailleurPourcentage = offre.comBailleur / 100; 
    
    final double fraisLocataire = loyer * comLocatairePourcentage;
    final double avanceGarantie = loyer * comBailleurPourcentage;
    final double totalApp = fraisLocataire + avanceGarantie;
    
    final double moisGarantie = (propriete.garantieMinimale ?? 3).toDouble();
    final double garantieTotale = moisGarantie * loyer;
    final double resteGarantieAuBailleur = garantieTotale - avanceGarantie;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Paiement", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
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
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ On passe la couleur de l'offre dynamiquement
            _buildTransparenceCard(offre.comBailleur.toDouble(), offre.color),
            const SizedBox(height: 30),
            const Text(
              "RÉSUMÉ DE LA RÉSERVATION", 
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)
            ),
            const Divider(thickness: 1.5),
            const SizedBox(height: 15),
            _buildPriceRow("Frais de service Easy Location (${offre.comLocataire}%)", "${fraisLocataire.toStringAsFixed(1)}\$"),
            _buildPriceRow("Avance sur Garantie (Réservation)", "${avanceGarantie.toStringAsFixed(1)}\$"),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _buildPriceRow("TOTAL À PAYER MAINTENANT", "${totalApp.toStringAsFixed(1)}\$", isTotal: true, totalColor: offre.color),
            ),
            const SizedBox(height: 25),
            _buildInfoBailleur(resteGarantieAuBailleur),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: offre.color, // ✅ Bouton aux couleurs de l'offre
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                ),
                onPressed: () async {
                  final String? propertyId = propriete.id;

                  if (propertyId == null || propertyId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("ID de propriété manquant."), backgroundColor: Colors.orange),
                    );
                    return; 
                  }

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.blue)),
                  );

                  try {
                    final int lockTimestamp = await PropertyService().verrouillerTemporairement(propertyId);

                    if (context.mounted) {
                      context.read<BookingTimerProvider>().startTimer(propertyId, lockTimestamp);
                      Navigator.pop(context); 

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LogistiqueDemenagementPage(
                            clientId: currentClientId,
                            nomClient: currentNomClient,
                            telClient: currentTelClient,
                            propriete: propriete,
                            offre: offre,
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); 
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString().replaceAll("Exception:", "")),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  "CONFIRMER ET PAYER", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE CONSTRUCTION ---

  Widget _buildTransparenceCard(double pourcentageBailleur, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
          const SizedBox(height: 12),
          Text(
            "Le bailleur prend en charge ${pourcentageBailleur.toInt()}% de nos frais pour vous faciliter l'entrée.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false, Color? totalColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label, 
              style: TextStyle(
                fontSize: isTotal ? 15 : 14, 
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500, 
                color: isTotal ? Colors.black : Colors.black54
              )
            )
          ),
          Text(
            value, 
            style: TextStyle(
              fontSize: isTotal ? 22 : 16, 
              fontWeight: FontWeight.w900, 
              color: isTotal ? (totalColor ?? Colors.blue.shade900) : Colors.black87
            )
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBailleur(double reste) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Il ne vous restera que ${reste.toStringAsFixed(1)}\$ à payer directement au bailleur pour compléter votre garantie.",
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
