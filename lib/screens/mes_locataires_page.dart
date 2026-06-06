import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// Importations des composants extraits
import '../widgets/bailleur/tenant_card.dart';
import '../widgets/bailleur/bailleur_dialogs.dart';
import '../widgets/bailleur/migration_bottom_sheet.dart';

// Providers et Modèles
import '../../providers/contract_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../services/config_service.dart';
import '../../services/pdf_service.dart';
import '../../utils/date_helper.dart';
import '../../utils/phone_utils.dart';
import '../../models/contract_model.dart';
import 'historique_paiements_bailleur_page.dart';

class MesLocatairesPage extends StatefulWidget {
  const MesLocatairesPage({super.key});

  @override
  State<MesLocatairesPage> createState() => _MesLocatairesPageState();
}

class _MesLocatairesPageState extends State<MesLocatairesPage> {
  @override
  void initState() {
    super.initState();
    _fetchContracts();
  }

  void _fetchContracts() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProfile = context.read<UserProfileProvider>().userData;
      
      // CORRECTION : On utilise l'UID Firebase brut pour interroger Firestore.
      // Le champ 'bailleurId' dans la base de données correspond à cet UID.
      final String? uid = userProfile?.uid;
      
      if (uid != null) {
        context.read<ContractProvider>().listenToBailleurContracts(uid);
      } else {
        debugPrint("Erreur : Impossible de charger les contrats, UID utilisateur nul.");
      }
    });
  }

  // ===========================================================================
  // ACTIONS DE NAVIGATION ET SERVICES EXTERNES
  // ===========================================================================

  void _relancerWhatsApp(ContractModel contrat) async {
    String telephone = normalizePhoneNumber(contrat.locataireTel ?? "");
    
    if (telephone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Numéro du locataire manquant"), backgroundColor: Colors.orange),
      );
      return;
    }
    final String telWa = telephone.startsWith('+') ? telephone.substring(1) : telephone;
    final String message = "Bonjour ${contrat.locataireNom}, c'est votre bailleur. "
        "Le paiement de votre loyer (${contrat.loyerMensuel}\$) pour ${contrat.refMaison} "
        "est prévu pour le ${DateHelper.formatShortDate(contrat.prochainPaiement)}.";

    final Uri url = Uri.parse("https://wa.me/$telWa?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _genererBailPDF(ContractModel contrat) async {
    final userProfile = context.read<UserProfileProvider>().userData;
    if (userProfile == null) return;
    
    await PdfService.genererEtPartagerContrat(
      context, 
      contrat.toFacture(), 
      userProfile.toServiceMap(), 
      {
        "nom": contrat.locataireNom,
        "tel": contrat.locataireTel ?? "N/A",
        "adresse": contrat.adresseComplete,
      }, 
      context.read<ConfigService>().companyInfo
    );
  }

  void _ouvrirEditionContrat(ContractModel contrat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => MigrationBottomSheet(contractToEdit: contrat),
    );
  }

  void _ouvrirFormulaireMigration() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => const MigrationBottomSheet(),
    );
  }

  // ===========================================================================
  // INTERFACE GRAPHIQUE
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final contractProv = Provider.of<ContractProvider>(context);
    final List<ContractModel> listeTriee = contractProv.bailleurContracts.toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Mes Locataires", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: _fetchContracts, icon: const Icon(Icons.refresh, color: Colors.black))
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvrirFormulaireMigration,
        backgroundColor: Colors.blue[800],
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text("IMPORTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: contractProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _fetchContracts(),
              child: listeTriee.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: listeTriee.length,
                      itemBuilder: (context, index) {
                        final contrat = listeTriee[index];
                        return TenantCard(
                          contrat: contrat,
                          onSettingsPressed: () => BailleurDialogs.showSettingsDialog(context, contrat),
                          onPayPressed: () => BailleurDialogs.showPaymentDialog(context, contrat),
                          onClosePressed: () => BailleurDialogs.showCloseContractDialog(context, contrat),
                          onPdfPressed: () => _genererBailPDF(contrat),
                          onWhatsAppPressed: () => _relancerWhatsApp(contrat),
                          onEditDatePressed: () => _ouvrirEditionContrat(contrat),
                          onHistoryPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => HistoriquePaiementsBailleurPage(contrat: contrat)),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
            const Text("Aucun locataire trouvé.", style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _ouvrirFormulaireMigration,
              child: const Text("Importer un contrat existant"),
            )
          ],
        ),
      ),
    );
  }
}