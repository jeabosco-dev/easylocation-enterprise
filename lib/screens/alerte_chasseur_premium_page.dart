// lib/screens/alerte_chasseur_premium_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:easylocation_mvp/models/filtre_propriete_model.dart';
import 'package:easylocation_mvp/widgets/filtre_avance_bottom_sheet.dart';
import 'package:easylocation_mvp/models/service_model.dart'; 
import 'package:easylocation_mvp/services/config_service.dart';
import 'package:easylocation_mvp/services/maxicash_service.dart';
import 'package:easylocation_mvp/widgets/manuel_payment_sheet.dart'; 
import 'package:easylocation_mvp/widgets/cash_payment_instruction_sheet.dart';
import 'package:easylocation_mvp/constants/all_constants.dart'; // Import des constantes
import 'paiement_succes_page.dart';

class AlerteChasseurPremiumPage extends StatefulWidget {
  final String userId;

  const AlerteChasseurPremiumPage({super.key, required this.userId});

  @override
  State<AlerteChasseurPremiumPage> createState() => _AlerteChasseurPremiumPageState();
}

class _AlerteChasseurPremiumPageState extends State<AlerteChasseurPremiumPage> {
  FiltreProprieteModel _filtresRecherche = FiltreProprieteModel(); 
  String? _selectedPlanId; 
  bool _isProcessing = false;

  Future<void> _activerServiceVipDansProfil() async {
    try {
      await FirebaseFirestore.instance.collection(FirestoreCollections.utilisateurs).doc(widget.userId).update({
        'hasVipActive': true,
        'preferences': {
          'province': _filtresRecherche.province,
          'ville': _filtresRecherche.ville,
          'commune': _filtresRecherche.commune ?? 'Toutes',
          'budgetMax': _filtresRecherche.maxPrice ?? 0,
          'typeBien': _filtresRecherche.typeBien ?? 'Tous',
          'nbChambres': _filtresRecherche.nbChambres, 
          'hasEau': _filtresRecherche.hasEau,
          'hasElectricity': _filtresRecherche.hasElectricity,
          'lastVipUpdate': FieldValue.serverTimestamp(),
        }
      });
      debugPrint("✅ Profil VIP mis à jour avec succès");
    } catch (e) {
      debugPrint("❌ Erreur mise à jour profil VIP : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigService>(context);
    final forfaitsVip = config.alerteServices; 

    if (_selectedPlanId == null && forfaitsVip.isNotEmpty) {
      _selectedPlanId = forfaitsVip.first.typeService;
    }

    return Stack(
      children: [
        Scaffold(
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
        ),
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  void _procederAuPaiement(ServiceModel offre) {
    final commande = ServiceModel(
      id: "ALERT-${DateTime.now().millisecondsSinceEpoch}",
      locataireId: widget.userId,
      typeService: 'ALERTE_IMMO',
      statut: 'PROPOSE',
      prix: offre.prix,
      provenance: 'APP_MOBILE',
      nomAffichage: "Alerte VIP : ${offre.nomAffichage}",
      description: offre.description ?? "Service d'alerte VIP",
      timestamp: DateTime.now(),
    );

    _afficherChoixPaiement(commande);
  }

  void _afficherChoixPaiement(ServiceModel commande) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ),
            const Text("Mode de règlement du service", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 24),
            _buildPaymentOption(
              icon: Icons.credit_card,
              color: Colors.blue,
              title: "MaxiCash (Paiement en ligne)",
              subtitle: "Cartes bancaires, Visa, Mobile Money - Instantané",
              onTap: () { Navigator.pop(sheetContext); _lancerMaxiCash(commande); },
            ),
            const SizedBox(height: 12),
            _buildPaymentOption(
              icon: Icons.phone_android,
              color: Colors.green,
              title: "Mobile Money Direct",
              subtitle: "Transfert Manuel - Vérification (5-30 min)",
              onTap: () { Navigator.pop(sheetContext); _lancerPaiementManuel(commande); },
            ),
            const SizedBox(height: 12),
            _buildPaymentOption(
              icon: Icons.payments_outlined,
              color: Colors.orange,
              title: "Paiement Cash",
              subtitle: "Validation physique à notre bureau",
              onTap: () { Navigator.pop(sheetContext); _lancerPaiementCash(commande); },
            ),
          ],
        ),
      ),
    );
  }

  void _lancerMaxiCash(ServiceModel commande) async {
    setState(() => _isProcessing = true);
    
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.services)
          .doc(commande.id)
          .set(commande.toMap());

      await MaxicashService.encaisserAcompte(
        context: context,
        telephone: "", 
        referenceCommande: commande.id,
        montant: commande.prix,
        ville: _filtresRecherche.ville ?? "Bukavu", 
        onSuccess: () async {
          await _activerServiceVipDansProfil();
          
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context, 
              MaterialPageRoute(builder: (context) => const PaiementSuccesPage()), 
              (route) => route.isFirst
            );
          }
        },
        onCancel: () => setState(() => _isProcessing = false),
      );
    } catch (e) {
      debugPrint("❌ Erreur tunnel paiement : $e");
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur technique : ${e.toString()}"))
        );
      }
    }
  }

  void _lancerPaiementManuel(ServiceModel commande) async {
    await FirebaseFirestore.instance.collection(FirestoreCollections.services).doc(commande.id).set(commande.toMap());
    
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ManuelPaymentSheet(
        propertyId: "PREMIUM_SERVICE_ID", 
        facture: commande.toFacture(nomClient: "Chasseur VIP"), 
        montantFinal: commande.prix,
        devise: "USD",
        docId: commande.id,
      ),
    );
  }

  void _lancerPaiementCash(ServiceModel commande) async {
    await FirebaseFirestore.instance.collection(FirestoreCollections.services).doc(commande.id).set(commande.toMap());

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CashPaymentInstructionSheet(
        // ✅ Utilisation de l'objet facture complet
        facture: commande.toFacture(nomClient: "Chasseur VIP"),
      ),
    );
  }

  // ... reste des widgets (_buildPaymentOption, _modifierFiltres, _buildHeroSection, etc.)
  
  Widget _buildPaymentOption({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ])),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
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