// lib/screens/choix_cadeau_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import '../providers/user_profile_provider.dart'; 
import '../providers/booking_timer_provider.dart'; 
import '../models/formulaire_publication_model.dart';
import '../models/facture_model.dart';
import '../widgets/reference_badge_widget.dart'; 
import '../services/config_service.dart'; 
import '../services/calculateur_expertise.dart'; // Contient la classe OffrePack
import '../utils/ui_utils.dart'; 
import 'page_facture.dart'; 

class ChoixCadeauPage extends StatefulWidget {
  final String clientId;
  final String nomClient;
  final String telClient;
  final FormulairePublicationModel propriete;
  final OffrePack offre; 
  // ✅ FLUX FINANCIERS MIS À JOUR
  final double montantWallet; 
  final double montantExterne;
  final double cashbackApplique; // ✅ Ajout du cashback (points)

  const ChoixCadeauPage({
    super.key,
    required this.clientId,
    required this.nomClient,
    required this.telClient,
    required this.propriete,
    required this.offre,
    required this.montantWallet,
    required this.montantExterne,
    this.cashbackApplique = 0.0, // ✅ Initialisé par défaut à 0
  });

  @override
  State<ChoixCadeauPage> createState() => _ChoixCadeauPageState();
}

class _ChoixCadeauPageState extends State<ChoixCadeauPage> with SingleTickerProviderStateMixin {
  String? cadeauSelectionne; 
  String tailleSelectionnee = 'L';
  String styleTshirt = 'Manches courtes';
  bool _dialogShown = false;

  late AnimationController _animationController;

  final List<Map<String, dynamic>> cadeaux = [
    {'nom': 'Calendrier Annuel EasyLocation', 'icon': Icons.calendar_month, 'id': 'Calendrier'},
    {'nom': 'Chapeau EasyLocation', 'icon': Icons.style, 'id': 'Chapeau'}, 
    {'nom': 'Je ne souhaite pas de cadeau', 'icon': Icons.not_interested, 'id': 'none'},
    {'nom': 'T-shirt Premium EasyLocation', 'icon': Icons.checkroom, 'id': 'T-shirt'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTimeout(BuildContext context) {
    if (!mounted || _dialogShown) return;
    _dialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Session expirée", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("Désolé, le temps imparti pour votre réservation est écoulé. La maison a été libérée."),
        actions: [
          TextButton(
            onPressed: () {
              context.read<BookingTimerProvider>().stopAndReset(); 
            Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("RETOUR À L'ACCUEIL", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProfileProvider>(context);
    final timerProvider = context.watch<BookingTimerProvider>(); 
    final bool dejaBeneficie = !userProvider.canReceiveGift;

    if (timerProvider.isExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTimeout(context));
    }

    return PopScope(
      canPop: true, 
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Cadeau de Bienvenue", 
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(), 
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: ReferenceBadgeWidget(reference: widget.propriete.referenceUnique),
              ),
            )
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildTimerBanner(timerProvider),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(dejaBeneficie),
                      const SizedBox(height: 30),
                      _buildLoyerResume(),
                      const SizedBox(height: 20),
                      if (dejaBeneficie) _buildAlreadyClaimedBanner(),
                      const Text("Choisissez votre option :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(dejaBeneficie ? "(Indisponible)" : "(C'est GRATUIT)", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: dejaBeneficie ? Colors.grey : Colors.green.shade700)),
                      const SizedBox(height: 15),
                      ...cadeaux.map((cadeau) => _buildCadeauTile(cadeau, dejaBeneficie)).toList(),
                      const SizedBox(height: 15),
                      if (cadeauSelectionne == 'T-shirt' && !dejaBeneficie) _buildTshirtOptions(),
                      const SizedBox(height: 40),
                      _buildValidationButton(userProvider, timerProvider, dejaBeneficie),
                      const SizedBox(height: 20),
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

  Widget _buildTimerBanner(BookingTimerProvider timer) {
    final bool urgent = timer.isUrgent;
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          color: urgent ? Colors.red.withOpacity(_animationController.value * 0.7 + 0.3) : Colors.orange.shade100,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, color: urgent ? Colors.white : Colors.orange.shade900, size: 20),
              const SizedBox(width: 8),
              Text(
                urgent ? "DÉPÊCHEZ-VOUS : ${timer.formattedTime}" : "Temps restant : ${timer.formattedTime}",
                style: TextStyle(
                  color: urgent ? Colors.white : Colors.orange.shade900,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoyerResume() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Loyer de la propriété :", style: TextStyle(color: Colors.black54)),
          Text(
            "${UIUtils.formatPrice(widget.propriete.price ?? 0)} \$", 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)
          ),
        ],
      ),
    );
  }

  Widget _buildValidationButton(UserProfileProvider userProv, BookingTimerProvider timerProv, bool dejaBeneficie) {
    final configService = Provider.of<ConfigService>(context, listen: false);
    bool canProceed = dejaBeneficie || (cadeauSelectionne != null);

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: canProceed ? widget.offre.color : Colors.grey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: canProceed ? 2 : 0,
        ),
        onPressed: timerProv.isExpired 
          ? null 
          : () async {
              if (!canProceed) {
                UIUtils.showSnackBar(context, "Veuillez choisir un cadeau ou l'option 'Aucun'.", isError: true);
                return;
              }

              if (!dejaBeneficie && cadeauSelectionne != 'none') {
                try {
                  await userProv.markGiftAsClaimed(giftId: cadeauSelectionne ?? "Reçu"); 
                } catch (e) {
                  UIUtils.showSnackBar(context, "Erreur lors de la validation du cadeau.", isError: true);
                  return;
                }
              }

              final userData = userProv.userData;
              final String finalClientId = userData?.uid ?? widget.clientId;
              final String finalNomClient = userData != null ? "${userData.prenom} ${userData.nom}".trim() : widget.nomClient;
              final String finalStringTelClient = userData?.telephone ?? widget.telClient;
      
              // ✅ CRÉATION DE LA FACTURE AVEC LES DONNÉES DE LOCALISATION COMPLÈTES
              final maFacture = FactureModel(
                propertyId: widget.propriete.id ?? "", 
                clientId: finalClientId,
                nomClient: finalNomClient,
                telClient: finalStringTelClient,
                nomBailleur: widget.propriete.nomProprietaire ?? "Propriétaire",
                telBailleur: widget.propriete.telephoneProprietaire ?? "",
                refMaison: widget.propriete.referenceUnique, 
                loyer: widget.propriete.price ?? 0.0,
                nbMoisGarantie: widget.propriete.garantieMinimale ?? 3, 
                nomOffre: widget.offre.titre, // <--- CORRIGÉ ICI (titre au lieu de nom)
                comLocatairePercent: widget.offre.comLocataire, 
                comBailleurPercent: widget.offre.comBailleur, 
                tauxApplique: configService.tauxUsdCdf, 
                montantWallet: widget.montantWallet,
                montantExterne: widget.montantExterne,
                montantCashback: widget.cashbackApplique, 
                
                // ✅ CHAMPS DE LOCALISATION CORRIGÉS
                province: widget.propriete.province, 
                ville: widget.propriete.ville, // Correction effectuée ici (ville au lieu de city)
                commune: widget.propriete.commune, 

                cadeauId: (cadeauSelectionne == 'none' || dejaBeneficie) ? 'Aucun' : cadeauSelectionne,
                cadeauTaille: (cadeauSelectionne == 'T-shirt' && !dejaBeneficie) ? tailleSelectionnee : null,
                cadeauStyle: (cadeauSelectionne == 'T-shirt' && !dejaBeneficie) ? styleTshirt : null,
              );
      
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FacturePage(facture: maFacture)),
                );
              }
            },
        child: Text(
          dejaBeneficie ? "CONTINUER VERS MA FACTURE" : "VALIDER ET VOIR MA FACTURE", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
        ),
      ),
    );
  }

  Widget _buildHeader(bool dejaBeneficie) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.stars, color: widget.offre.color, size: 50), 
          const SizedBox(height: 10),
          const Text("FÉLICITATIONS !", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 5),
          Text(
            dejaBeneficie 
              ? "Heureux de vous revoir parmi nous !"
              : "Vous êtes désormais un locataire certifié.", 
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 16)
          ),
        ],
      ),
    );
  }

  Widget _buildCadeauTile(Map<String, dynamic> cadeau, bool disabled) {
    bool isNone = cadeau['id'] == 'none';
    bool isSelected = cadeauSelectionne == cadeau['id'];
    
    return GestureDetector(
      onTap: disabled ? null : () => setState(() => cadeauSelectionne = cadeau['id']),
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isNone ? Colors.grey.shade100 : widget.offre.color.withOpacity(0.08)) 
                : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected 
                  ? (isNone ? Colors.grey : widget.offre.color) 
                  : Colors.grey.shade200, 
              width: 2
            ),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)] : [],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isSelected 
                    ? (isNone ? Colors.grey.shade300 : widget.offre.color.withOpacity(0.2)) 
                    : Colors.grey.shade100,
                child: Icon(cadeau['icon'], color: isSelected ? (isNone ? Colors.black54 : widget.offre.color) : Colors.grey),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cadeau['nom'], 
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, 
                        fontSize: 15,
                        color: isSelected && isNone ? Colors.grey.shade800 : Colors.black87
                      )
                    ),
                    if (!isNone)
                      const Text("Offert par EasyLocation", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? (isNone ? Colors.grey : widget.offre.color) : Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlreadyClaimedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(child: Text("Vous avez déjà profité de votre cadeau de bienvenue lors d'une réservation précédente.", style: TextStyle(fontSize: 13, color: Colors.blue.shade800))),
        ],
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