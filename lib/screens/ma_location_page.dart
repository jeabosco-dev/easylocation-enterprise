import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Import des modèles et providers
import '../../providers/contract_provider.dart';
import '../../models/contract_model.dart';
import '../../utils/date_helper.dart';

// Import des pages de navigation
import 'historique_paiements_locataire_page.dart';
import 'maisons_publiees_page.dart';

// Import des nouveaux widgets refactorisés
import '../../widgets/location/location_summary_card.dart';
import '../../widgets/location/migration_form_bottom_sheet.dart';
import '../../widgets/location/payment_dialogs.dart';
import '../../widgets/location/validation_banner.dart';
import '../../widgets/location/tenant_actions_card.dart';

class MaLocationPage extends StatefulWidget {
  const MaLocationPage({super.key});

  @override
  State<MaLocationPage> createState() => _MaLocationPageState();
}

class _MaLocationPageState extends State<MaLocationPage> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String userId = user.uid; 
        print("DEBUG: Chargement du contrat pour l'UID: $userId");
        context.read<ContractProvider>().listenToLocataireContracts(userId);
      }
    });
  }

  // ===========================================================================
  // LOGIQUE DES MODAUX
  // ===========================================================================

  void _ouvrirFormulaireMigrationLocataire(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => const MigrationFormBottomSheet(),
    );
  }

  void _ouvrirModeEdition(BuildContext context, ContractModel contrat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => MigrationFormBottomSheet(contractToEdit: contrat),
    );
  }

  // ===========================================================================
  // BUILD PRINCIPAL
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final contractProv = Provider.of<ContractProvider>(context);
    final ContractModel? contrat = contractProv.locataireActiveContract;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Ma Location",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (contrat != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.blue),
              onPressed: () => _refreshData(context),
            )
        ],
      ),
      body: contractProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : contrat == null
              ? _buildEmptyState(context)
              : RefreshIndicator(
                  onRefresh: () => _refreshData(context),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- EN-TÊTE DYNAMIQUE (FOCUS EXPIRATION) ---
                        _buildExpirationHeader(contrat),
                        
                        const SizedBox(height: 20),

                        if (contrat.status == 'pending' || contrat.status == 'pending_confirmation')
                          ValidationBanner(
                            contrat: contrat,
                            onConfirm: () async {
                              bool success = await context.read<ContractProvider>().accepterContrat(contrat.id);
                              if (success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Contrat confirmé !"), backgroundColor: Colors.green),
                                );
                              }
                            },
                            onContact: () => _contacterBailleur(context, contrat),
                          ),

                        // 2. Résumé de la location (Carte principale)
                        LocationSummaryCard(contrat: contrat),

                        // Bouton Modifier
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _ouvrirModeEdition(context, contrat),
                            icon: const Icon(Icons.edit_note, size: 20),
                            label: const Text("Ajuster les détails du bail"),
                            style: TextButton.styleFrom(foregroundColor: Colors.blue[900]),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 3. ACTIONS DU LOCATAIRE
                        TenantActionsCard(contrat: contrat),

                        const SizedBox(height: 20),

                        // 4. NAVIGATION SECONDAIRE
                        _buildSecondaryActions(context, contrat),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildExpirationHeader(ContractModel contrat) {
    final jours = contrat.joursRestantsLoyer;
    Color statusColor = jours <= 5 ? Colors.red : (jours <= 10 ? Colors.orange : Colors.green);
    
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: statusColor.withOpacity(0.3))
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: statusColor,
            child: const Icon(Icons.timer, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jours < 0 ? "Loyer expiré" : "Expire dans $jours jours",
                  style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 16),
                ),
                Text(
                  "Échéance : ${DateFormat('dd MMMM yyyy').format(contrat.prochainPaiement)}",
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              contrat.status.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _refreshData(BuildContext context) async {
     final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await context.read<ContractProvider>().listenToLocataireContracts(user.uid);
      }
  }

  Widget _buildSecondaryActions(BuildContext context, ContractModel contrat) {
    return Column(
      children: [
        const Text("GESTION ADMINISTRATIVE", 
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.history, 
                label: "REÇUS", 
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HistoriquePaiementsLocatairePage(contrat: contrat)))
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionButton(
                icon: Icons.chat_bubble_outline, 
                label: "BAILLEUR", 
                onTap: () => _contacterBailleur(context, contrat)
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue[900]),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.house_outlined, size: 100, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text("Où habitez-vous ?",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            const Text(
              "Activez votre journal de location pour sécuriser vos paiements et vos droits.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _ouvrirFormulaireMigrationLocataire(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("DÉMARRER MON SUIVI DIGITAL"),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (context) => const MaisonsPublieesPage())),
              child: const Text("TROUVER UNE NOUVELLE MAISON"),
            ),
          ],
        ),
      ),
    );
  }

  void _contacterBailleur(BuildContext context, ContractModel contrat) async {
    // CORRIGÉ : Utilisation de telBailleur au lieu de bailleurTel
    final String? tel = contrat.telBailleur;
    
    if (tel == null || tel.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Numéro non disponible."), backgroundColor: Colors.orange),
      );
      return;
    }
    final String telephone = tel.replaceAll(RegExp(r'[^\d]'), '');
    final String message = "Bonjour, je vous contacte via EasyLocation pour le logement : ${contrat.refMaison}.";
    final String url = "https://wa.me/$telephone?text=${Uri.encodeComponent(message)}";
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}