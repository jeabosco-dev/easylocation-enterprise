// lib/screens/logistique_demenagement_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import '../providers/user_profile_provider.dart'; 
import '../providers/booking_timer_provider.dart'; 
import '../models/formulaire_publication_model.dart';
import '../services/calculateur_expertise.dart'; // ✅ Import nécessaire pour OffrePack
import 'choix_cadeau_page.dart';

class LogistiqueDemenagementPage extends StatefulWidget {
  final String clientId;
  final String nomClient;
  final String telClient;
  final FormulairePublicationModel propriete;
  final OffrePack offre; // ✅ Changé Map en OffrePack

  const LogistiqueDemenagementPage({
    super.key,
    required this.clientId,
    required this.nomClient,
    required this.telClient,
    required this.propriete,
    required this.offre,
  });

  @override
  State<LogistiqueDemenagementPage> createState() => _LogistiqueDemenagementPageState();
}

class _LogistiqueDemenagementPageState extends State<LogistiqueDemenagementPage> {
  bool veutTransport = false;

  @override
  void initState() {
    super.initState();
    // ✅ Activation automatique si l'offre inclut le transport (Ex: Gold et Diamond)
    if (widget.offre.nom == 'Gold' || widget.offre.nom == 'Diamond') {
      veutTransport = true;
    }
  }

  // --- LOGIQUE D'EXPIRATION ---
  void _handleTimeout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Temps écoulé"),
        content: const Text("Votre session de réservation a expiré. La maison est de nouveau disponible pour les autres utilisateurs."),
        actions: [
          TextButton(
            onPressed: () {
              context.read<BookingTimerProvider>().stopAndReset();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("RETOUR À L'ACCUEIL"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProfileProvider>(context);
    final timerProvider = context.watch<BookingTimerProvider>(); 
    
    if (timerProvider.isExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTimeout(context));
    }

    final userData = userProvider.userData;
    final String currentClientId = userData?.uid ?? widget.clientId;
    final String currentNomClient = userData != null 
        ? "${userData.prenom} ${userData.nom} ${userData.postnom}".trim()
        : widget.nomClient;
    final String currentTelClient = userData?.telephone ?? widget.telClient;

    // ✅ Vérification basée sur l'objet OffrePack
    bool estInclus = widget.offre.nom == 'Gold' || widget.offre.nom == 'Diamond';

    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez finaliser ou attendre la fin du chrono.")),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Logistique & Sérénité", 
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false, 
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildTimerBanner(timerProvider.formattedTime),
      
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: widget.offre.color.withOpacity(0.1), // ✅ Couleur dynamique
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(Icons.local_shipping_rounded, size: 80, color: widget.offre.color),
                      ),
                      const SizedBox(height: 30),
      
                      Text(
                        estInclus 
                          ? "PACK SÉRÉNITÉ LOGISTIQUE INCLUS !" 
                          : "VOULEZ-VOUS NOTRE PACK SÉRÉNITÉ LOGISTIQUE ?",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
      
                      _buildArgument(Icons.verified_user, "Garantie 100% Anti-Casse", "Si un objet se casse, nous le remplaçons."),
                      _buildArgument(Icons.money_off, "Prix cassé : Jusqu'à -50%", "Livraison au point d'accès le plus proche."),
                      _buildArgument(Icons.people_alt, "Équipe de confiance", "Professionnels vérifiés par Easy Location."),
      
                      const SizedBox(height: 30),
      
                      if (estInclus) _buildInclusBadge() else _buildOptionSelector(),
      
                      const SizedBox(height: 40),
      
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.offre.color, // ✅ Utilise la couleur de l'offre
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChoixCadeauPage(
                                  clientId: currentClientId,
                                  nomClient: currentNomClient,
                                  telClient: currentTelClient,
                                  propriete: widget.propriete,
                                  offre: widget.offre,
                                  transportSelectionne: veutTransport,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            "CONTINUER",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerBanner(String time) {
    return Container(
      width: double.infinity,
      color: Colors.red.shade50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined, color: Colors.red.shade700, size: 16),
          const SizedBox(width: 8),
          Text(
            "Temps restant pour finaliser : $time",
            style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildArgument(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green.shade700, size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInclusBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Inclus gratuitement dans votre offre !", 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionSelector() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => veutTransport = true),
          child: _optionCard("Oui, je sécurise mes biens", "+ 10\$", veutTransport),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => veutTransport = false),
          child: _optionCard("Non, je gère seul", "0\$", !veutTransport),
        ),
      ],
    );
  }

  Widget _optionCard(String title, String price, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? widget.offre.color : Colors.grey.shade300, width: 2),
        color: isSelected ? widget.offre.color.withOpacity(0.05) : Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title, 
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14
              )
            ),
          ),
          const SizedBox(width: 8),
          Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
