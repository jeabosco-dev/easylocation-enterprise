// lib/screens/choix_cadeau_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import '../providers/user_profile_provider.dart'; 
import '../providers/booking_timer_provider.dart'; 
import '../models/formulaire_publication_model.dart';
import '../models/facture_model.dart';
import '../services/settings_service.dart'; 
import '../services/calculateur_expertise.dart'; // ✅ Import nécessaire pour OffrePack
import 'page_facture.dart'; 

class ChoixCadeauPage extends StatefulWidget {
  final String clientId;
  final String nomClient;
  final String telClient;
  final FormulairePublicationModel propriete;
  final OffrePack offre; // ✅ Changé de Map à OffrePack
  final bool transportSelectionne;

  const ChoixCadeauPage({
    super.key,
    required this.clientId,
    required this.nomClient,
    required this.telClient,
    required this.propriete,
    required this.offre,
    required this.transportSelectionne,
  });

  @override
  State<ChoixCadeauPage> createState() => _ChoixCadeauPageState();
}

class _ChoixCadeauPageState extends State<ChoixCadeauPage> {
  String? cadeauSelectionne; 
  String tailleSelectionnee = 'L';
  String styleTshirt = 'Manches courtes';

  final List<Map<String, dynamic>> cadeaux = [
    {'nom': 'T-shirt Premium EasyLocation', 'icon': Icons.checkroom, 'id': 'T-shirt'},
    {'nom': 'Chapeau EasyLocation', 'icon': Icons.style, 'id': 'Chapeau'}, 
    {'nom': 'Calendrier Annuel EasyLocation', 'icon': Icons.calendar_month, 'id': 'Calendrier'},
  ];

  void _handleTimeout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Session expirée"),
        content: const Text("Désolé, le temps imparti pour votre réservation est écoulé. La maison a été libérée."),
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

    if (!userProvider.canReceiveGift) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 60, color: Colors.orange),
                const SizedBox(height: 20),
                const Text("Offre déjà utilisée", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Vous avez déjà reçu votre cadeau de bienvenue lors d'une précédente réservation.", textAlign: TextAlign.center),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("RETOUR"),
                )
              ],
            ),
          ),
        ),
      );
    }

    if (timerProvider.isExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTimeout(context));
    }

    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Action impossible. Finalisez votre choix de cadeau.")),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Cadeau de Bienvenue", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false, 
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildTimerBanner(timerProvider.formattedTime),
      
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 30),
                      
                      Wrap(
                        children: [
                          const Text("Choisissez votre cadeau ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("(C'est GRATUIT) :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade700)),
                        ],
                      ),
                      const SizedBox(height: 15),
      
                      ...cadeaux.map((cadeau) => _buildCadeauTile(cadeau)).toList(),
      
                      _buildNoneOption(),

                      const SizedBox(height: 25),
      
                      if (cadeauSelectionne == 'T-shirt') _buildTshirtOptions(),
      
                      const SizedBox(height: 40),
      
                      _buildValidationButton(userProvider, timerProvider),
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

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.stars, color: widget.offre.color, size: 50), // ✅ Couleur dynamique
          const SizedBox(height: 10),
          const Text(
            "FÉLICITATIONS !",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 5),
          Text(
            "Vous êtes désormais un locataire certifié.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationButton(UserProfileProvider userProv, BookingTimerProvider timerProv) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          // ✅ Utilise la couleur de l'offre si un cadeau est choisi
          backgroundColor: cadeauSelectionne != null ? widget.offre.color : Colors.grey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: (cadeauSelectionne == null || timerProv.isExpired || userProv.isLoading) 
          ? null 
          : () async {
              showDialog(
                context: context, 
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator())
              );
      
              try {
                await userProv.completeWelcomeGift(cadeauSelectionne!);
                double tauxFirestore = await SettingsService().getTauxDuJour();
                timerProv.stopAndReset();

                final userData = userProv.userData;
                final String finalClientId = userData?.uid ?? widget.clientId;
                final String finalNomClient = userData != null 
                    ? "${userData.prenom} ${userData.nom}".trim() 
                    : widget.nomClient;
                final String finalTelClient = userData?.telephone ?? widget.telClient;
      
                // ✅ Facture synchronisée avec OffrePack
                final maFacture = FactureModel(
                  propertyId: widget.propriete.id ?? "", 
                  clientId: finalClientId,
                  nomClient: finalNomClient,
                  telClient: finalTelClient,
                  nomBailleur: widget.propriete.nomProprietaire ?? "Propriétaire",
                  telBailleur: widget.propriete.telephoneProprietaire ?? "",
                  refMaison: widget.propriete.numeroMaison ?? "REF-BIEN", 
                  loyer: widget.propriete.price ?? 0.0,
                  nbMoisGarantie: widget.propriete.garantieMinimale ?? 3, 
                  nomOffre: widget.offre.nom, // ✅ Propriété de OffrePack
                  comLocatairePercent: widget.offre.comLocataire / 100, // ✅ Propriété de OffrePack
                  transportChoisi: widget.transportSelectionne,
                  tauxApplique: tauxFirestore, 
                  cadeauId: cadeauSelectionne == 'none' ? 'Aucun' : cadeauSelectionne,
                  cadeauTaille: cadeauSelectionne == 'T-shirt' ? tailleSelectionnee : null,
                  cadeauStyle: cadeauSelectionne == 'T-shirt' ? styleTshirt : null,
                );
      
                if (mounted) {
                  Navigator.pop(context); 
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => FacturePage(facture: maFacture)),
                    (route) => route.isFirst,
                  );
                }
              } catch (e) {
                if (mounted) Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
                );
              }
            },
        child: userProv.isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              "VALIDER ET VOIR MA FACTURE",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
      ),
    );
  }

  Widget _buildNoneOption() {
    bool isSelected = cadeauSelectionne == 'none';
    return GestureDetector(
      onTap: () => setState(() => cadeauSelectionne = 'none'),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? widget.offre.color : Colors.transparent),
          borderRadius: BorderRadius.circular(8)
        ),
        child: Row(
          children: [
            Icon(Icons.not_interested, size: 16, color: isSelected ? widget.offre.color : Colors.grey),
            const SizedBox(width: 10),
            Text("Je ne souhaite pas de cadeau pour l'instant", 
              style: TextStyle(fontSize: 13, color: isSelected ? widget.offre.color : Colors.grey.shade600)),
          ],
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
          const Icon(Icons.timer_outlined, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Text(
            "Temps restant : $time",
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCadeauTile(Map<String, dynamic> cadeau) {
    bool isSelected = cadeauSelectionne == cadeau['id'];
    return GestureDetector(
      onTap: () => setState(() => cadeauSelectionne = cadeau['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? widget.offre.color.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? widget.offre.color : Colors.grey.shade200, width: 2),
        ),
        child: Row(
          children: [
            Icon(cadeau['icon'], color: isSelected ? widget.offre.color : Colors.grey),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cadeau['nom'], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 15)),
                  const Text("Offert par EasyLocation", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: widget.offre.color),
          ],
        ),
      ),
    );
  }

  Widget _buildTshirtOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.orange.shade100)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Personnalisez votre T-shirt :", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildDropdownRow("Taille", tailleSelectionnee, ['S', 'M', 'L', 'XL', 'XXL'], (val) => setState(() => tailleSelectionnee = val!)),
          _buildDropdownRow("Style", styleTshirt, ['Manches courtes', 'Manches longues'], (val) => setState(() => styleTshirt = val!)),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label, String value, List<String> items, Function(String?) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          items: items.map((String val) => DropdownMenuItem<String>(value: val, child: Text(val))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
