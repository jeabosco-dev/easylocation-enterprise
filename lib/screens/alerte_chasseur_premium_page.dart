// lib/screens/alerte_chasseur_premium_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:easylocation_mvp/models/filtre_propriete_model.dart';
import 'package:easylocation_mvp/widgets/filtre_avance_bottom_sheet.dart';
import 'package:easylocation_mvp/models/service_model.dart'; 
import 'package:easylocation_mvp/models/facture_model.dart';
import 'package:easylocation_mvp/services/config_service.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart'; 
import 'package:easylocation_mvp/screens/page_facture.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

class AlerteChasseurPremiumPage extends StatefulWidget {
  final String userId;

  const AlerteChasseurPremiumPage({super.key, required this.userId});

  @override
  State<AlerteChasseurPremiumPage> createState() => _AlerteChasseurPremiumPageState();
}

class _AlerteChasseurPremiumPageState extends State<AlerteChasseurPremiumPage> {
  FiltreProprieteModel _filtresRecherche = FiltreProprieteModel(); 
  String? _selectedPlanId; 

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigService>(context);
    final forfaitsVip = config.alerteServices; 

    if (_selectedPlanId == null && forfaitsVip.isNotEmpty) {
      _selectedPlanId = forfaitsVip.first.typeService;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Chasseur Immo VIP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Mes critères d'alerte", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _modifierFiltres, 
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text("Modifier"),
                  style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildCriteriaSummary(),
            const SizedBox(height: 30),
            const Text("Choisir la durée du service", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            if (forfaitsVip.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              ...forfaitsVip.map((offre) => _buildPriceTile(offre)).toList(),
            const SizedBox(height: 40),
            _buildSubmitButton(forfaitsVip),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                "Paiement sécurisé via MaxiCash ou Mobile Money",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _procederAuPaiement(ServiceModel offre) {
    // 1. Récupération des informations de l'utilisateur connecté
    final userProfile = context.read<UserProfileProvider>().userData;
    final String uniqueId = "FACT-ALERT-${DateTime.now().millisecondsSinceEpoch}";

    // 2. Préparation des critères du chasseur pour le matching back-office
    final Map<String, dynamic> metadataCriteres = {
      'type': _filtresRecherche.typeBien ?? 'Tous',
      'commune': _filtresRecherche.commune ?? 'Toute la ville',
      'budgetMax': _filtresRecherche.maxPrice ?? 0,
      'nbChambres': _filtresRecherche.nbChambres,
      'hasEau': _filtresRecherche.hasEau,
      'hasElectricity': _filtresRecherche.hasElectricity,
    };

    // 3. Construction de la Map unifiée de la facture pour l'Alerte VIP
    final Map<String, dynamic> serviceFactureMap = {
      FactureFields.typeService: offre.typeService,
      FactureFields.clientId: widget.userId,
      FactureFields.nomClient: userProfile?.nomComplet ?? 'Client VIP',
      FactureFields.telClient: userProfile?.telephone ?? '',
      FactureFields.refMaison: "CHASSEUR-VIP",
      FactureFields.loyer: offre.prix,
      FactureFields.nomOffre: "Alerte VIP : ${offre.nomAffichage}",
      FactureFields.province: userProfile?.province ?? _filtresRecherche.province ?? 'Sud-Kivu',
      FactureFields.ville: userProfile?.ville ?? _filtresRecherche.ville ?? 'Bukavu',
      FactureFields.commune: userProfile?.commune ?? _filtresRecherche.commune ?? '',
      'categorieBien': 'ALERTE_IMMO',
      'serviceEligible': offre.typeService,
      'categorieEligible': 'ALERTE_IMMO',
      'propertyId': 'SERVICE',
      'metadata': metadataCriteres,
    };

    // 4. Instanciation du FactureModel
    final FactureModel factureAlerte = FactureModel.fromServiceMap(serviceFactureMap, uniqueId);

    // 5. Redirection vers FacturePage pour le paiement unifié
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacturePage(facture: factureAlerte),
      ),
    );
  }

  void _modifierFiltres() async {
    final result = await showModalBottomSheet<FiltreProprieteModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FiltreAvanceBottomSheet(initialFiltre: _filtresRecherche),
    );
    if (result != null) setState(() => _filtresRecherche = result);
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, size: 40, color: Colors.yellowAccent),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text("Service Prioritaire", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 4),
            Text("Soyez alerté par Push/SMS dès qu'un bien correspond à vos critères.", style: TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
        ],
      ),
    );
  }

  Widget _buildCriteriaSummary() {
    bool hasFilters = _filtresRecherche.isNotEmpty; 
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: hasFilters ? Colors.deepPurple.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasFilters ? Colors.deepPurple.withOpacity(0.2) : Colors.grey.shade200),
      ),
      child: Text(
        hasFilters 
          ? "Recherche de ${_filtresRecherche.typeBien ?? 'biens'} à ${_filtresRecherche.commune ?? 'votre zone'}. Budget Max: ${_filtresRecherche.maxPrice?.toStringAsFixed(0) ?? 'Non défini'}\$"
          : "⚠️ Aucun critère défini. Veuillez cliquer sur 'Modifier' pour configurer votre chasseur.",
        style: TextStyle(
          fontSize: 13, 
          color: hasFilters ? Colors.black87 : Colors.red.shade700,
          fontWeight: hasFilters ? FontWeight.normal : FontWeight.bold
        ),
      ),
    );
  }

  Widget _buildPriceTile(ServiceModel offre) {
    bool isSelected = _selectedPlanId == offre.typeService;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanId = offre.typeService),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.deepPurple : Colors.grey.shade300, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(offre.nomAffichage, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isSelected ? Colors.deepPurple : Colors.black87)),
              Text(offre.description ?? "", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ]),
            Text("${offre.prix} \$", style: TextStyle(color: isSelected ? Colors.deepPurple : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(List<ServiceModel> forfaits) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          disabledBackgroundColor: Colors.grey.shade300
        ),
        onPressed: (forfaits.isEmpty || _filtresRecherche.isEmpty) ? null : () {
          final offreChoisie = forfaits.firstWhere((o) => o.typeService == _selectedPlanId);
          _procederAuPaiement(offreChoisie);
        },
        child: const Text("ACTIVER MON CHASSEUR VIP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}