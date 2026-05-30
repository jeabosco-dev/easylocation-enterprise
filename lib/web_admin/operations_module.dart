// lib/web_admin/operations_module.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:easylocation_mvp/services/export_service.dart';

// --- IMPORTS DES WIDGETS DÉPORTÉS ---
import 'package:easylocation_mvp/widgets/admin/onglet_demandes_urgentes.dart';
import 'package:easylocation_mvp/widgets/admin/onglet_validation_paiements_momo.dart'; // Nouveau
import 'package:easylocation_mvp/widgets/admin/onglet_validation_paiements_cash.dart'; // Nouveau
import 'package:easylocation_mvp/widgets/admin/onglet_certification.dart';
import 'package:easylocation_mvp/widgets/admin/onglet_biens_certifies.dart'; 
import 'package:easylocation_mvp/widgets/admin/onglet_attribution_paiements.dart';
import 'package:easylocation_mvp/widgets/admin/onglet_remise_cles.dart';
import 'package:easylocation_mvp/widgets/admin/onglet_biens_loues.dart';
import 'package:easylocation_mvp/widgets/admin/onglet_archives_rejets.dart';

class OperationsModule extends StatefulWidget {
  const OperationsModule({super.key});

  @override
  State<OperationsModule> createState() => _OperationsModuleState();
}

class _OperationsModuleState extends State<OperationsModule> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    // Changement de taille : passage à 9 onglets suite au split MoMo / Cash
    _tabController = TabController(length: 9, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? myId = context.read<UserProfileProvider>().userData?.uid;
      context.read<AdminCountsProvider>().refresh(adminId: myId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- FONCTION D'EXPORTATION DYNAMIQUE PAR ONGLET ---
  Future<void> _exportCurrentTab() async {
    final String? myId = context.read<UserProfileProvider>().userData?.uid;
    setState(() => _isExporting = true);

    try {
      QuerySnapshot snapshot;
      String fileName = "";
      String sheetName = "";
      List<String> headers = ["RÉF", "TYPE", "PROPRIÉTAIRE", "PRIX", "STATUT", "DATE"];
      List<String> keys = ["id", "typeBien", "nomProprietaire", "price", "status", "updatedAt"];

      final collProperties = FirebaseFirestore.instance.collection(FirestoreCollections.properties);
      final collFactures = FirebaseFirestore.instance.collection(FirestoreCollections.factures);

      // Détermination de la requête selon le nouvel index des onglets
      switch (_tabController.index) {
        case 0: // 1) DEMANDES URGENTES
          snapshot = await collProperties
              .where('hasPriorityRequest', isEqualTo: true)
              .where(FirestoreFields.isVerified, isEqualTo: false)
              .where(FirestoreFields.status, isNotEqualTo: PropertyStatus.rejected)
              .get();
          fileName = "Demandes_Urgentes";
          sheetName = "Urgents";
          break;

        case 1: // 2) CERTIFICATIONS
          snapshot = await collProperties
              .where(FirestoreFields.isVerified, isEqualTo: false)
              .where(FirestoreFields.status, isNotEqualTo: PropertyStatus.rejected)
              .get();
          fileName = "Certifications_A_Valider";
          sheetName = "Certifications";
          break;

        case 2: // 3) BIENS EN LIGNE
          snapshot = await collProperties
              .where(FirestoreFields.isVerified, isEqualTo: true)
              .where(FirestoreFields.status, isEqualTo: PropertyStatus.disponible)
              .get();
          fileName = "Biens_En_Ligne";
          sheetName = "Disponibles";
          break;

        case 3: // 4) PAIEMENTS MOBILE MONEY (Filtre strict no-cash)
          headers = ["RÉF MAISON", "STATUT PAIEMENT", "MÉTHODE", "AGENT TERRAIN ID", "TOTAL USD"];
          keys = [FactureFields.refMaison, FactureFields.paymentStatus, "methodePaiement", FactureFields.agentTerrainId, FactureFields.totalUSD];
          
          if (myId != null) {
            snapshot = await collFactures
                .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPending)
                .where('methodePaiement', isNotEqualTo: 'cash')
                .where(FactureFields.agentTerrainId, isEqualTo: myId) // ✅ Clé unifiée appliquée au filtre
                .get();
          } else {
            snapshot = await collFactures
                .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPending)
                .where('methodePaiement', isNotEqualTo: 'cash')
                .get();
          }
          fileName = "Paiements_MoMo_En_Attente";
          sheetName = "MoMo";
          break;

        case 4: // 5) PAIEMENTS CASH (Filtre strict cash)
          headers = ["RÉF MAISON", "STATUT PAIEMENT", "MÉTHODE", "AGENT TERRAIN ID", "TOTAL USD"];
          keys = [FactureFields.refMaison, FactureFields.paymentStatus, "methodePaiement", FactureFields.agentTerrainId, FactureFields.totalUSD];
          
          if (myId != null) {
            snapshot = await collFactures
                .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPending)
                .where('methodePaiement', isEqualTo: 'cash')
                .where(FactureFields.agentTerrainId, isEqualTo: myId) // ✅ Clé unifiée appliquée au filtre
                .get();
          } else {
            snapshot = await collFactures
                .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPending)
                .where('methodePaiement', isEqualTo: 'cash')
                .get();
          }
          fileName = "Paiements_Cash_En_Attente";
          sheetName = "Cash";
          break;

        case 5: // 6) ATTRIBUTION ✅ SÉCURISÉ & ALIGNÉ SUR LE TRAITEMENT WORKFLOW
          headers = ["RÉF MAISON", "STATUT PAIEMENT", "ÉTAPE", "TOTAL USD"];
          keys = [FactureFields.refMaison, FactureFields.paymentStatus, FactureFields.etapeDossier, FactureFields.totalUSD];
          snapshot = await collFactures
              .where(FactureFields.etapeDossier, isEqualTo: 'paye')
              .where(FirestoreFields.assignedAdminId, isNull: true)
              .get();
          fileName = "Attributions_Paiements";
          sheetName = "Attributions";
          break;

        case 6: // 7) REMISE DES CLÉS
          if (myId != null) {
            headers = ["RÉF MAISON", "STATUT PAIEMENT", "ÉTAPE", "TOTAL USD"];
            keys = [FactureFields.refMaison, FactureFields.paymentStatus, FactureFields.etapeDossier, FactureFields.totalUSD];
            snapshot = await collFactures
                .where(FactureFields.paymentStatus, whereIn: const [FactureFields.statusPaid, 'success'])
                .where('assignedAdminId', isEqualTo: myId)
                .where(FactureFields.etapeDossier, isNotEqualTo: FactureFields.etapeCloture)
                .get();
          } else {
            snapshot = await collProperties.where(FirestoreFields.status, isEqualTo: PropertyStatus.remiseCles).get();
          }
          fileName = "Remise_Cles_Ongoing";
          sheetName = "Clés";
          break;

        case 7: // 8) BIENS LOUÉS
          snapshot = await collProperties
              .where(FirestoreFields.isVerified, isEqualTo: true)
              .where(FirestoreFields.status, whereIn: const ['rented', 'occupied'])
              .get();
          fileName = "Biens_Loues_Occupes";
          sheetName = "Loués";
          break;

        case 8: // 9) ARCHIVES
          snapshot = await collProperties
              .where(FirestoreFields.status, isEqualTo: PropertyStatus.rejected)
              .get();
          fileName = "Archives_Rejets";
          sheetName = "Archives";
          break;

        default:
          return;
      }

      if (snapshot.docs.isEmpty) {
        if (mounted) _showSnack("Aucune donnée à exporter pour cet onglet.", Colors.orange);
        return;
      }

      await ExportService.exportPropertiesToExcel(
        docs: snapshot.docs,
        fileName: "Export_${fileName}_${DateTime.now().day}_${DateTime.now().month}.xlsx",
        sheetName: sheetName,
        headers: headers,
        keys: keys,
      );

      if (mounted) _showSnack("Export de l'onglet [$sheetName] réussi !", Colors.green);
    } catch (e) {
      if (mounted) _showSnack("Erreur Export : $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>();

    if (profile.isLoading) return const Center(child: CircularProgressIndicator());
    
    if (profile.userData == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Session admin requise"),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: () => profile.loadUser(), child: const Text("RÉESSAYER")),
          ],
        ),
      );
    }

    return Consumer<AdminCountsProvider>(
      builder: (context, countsProvider, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            title: const Text("CENTRE DE COMMANDE", 
              style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                onPressed: countsProvider.isLoading 
                    ? null 
                    : () {
                        final String? myId = context.read<UserProfileProvider>().userData?.uid;
                        countsProvider.refresh(adminId: myId);
                      },
                icon: Icon(Icons.refresh, color: countsProvider.isLoading ? Colors.grey : Colors.blue),
                tooltip: "Actualiser les compteurs",
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportCurrentTab, 
                  icon: _isExporting 
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_for_offline_outlined, size: 20),
                  label: AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, child) {
                      return const Text("EXPORTER CET ONGLET");
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF1E293B),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              indicatorWeight: 3,
              tabs: [
                _buildTab(label: "DEMANDES URGENTES", icon: Icons.bolt, color: Colors.orange, count: countsProvider.counts['urgents']),
                _buildTab(label: "CERTIFICATIONS", icon: Icons.pending_actions, color: Colors.blue, count: countsProvider.counts['certifications']),
                _buildTab(label: "BIENS EN LIGNE", icon: Icons.verified, color: Colors.green, count: countsProvider.counts['enLigne']),
                
                // Compteurs isolés pour MoMo et Cash suite au split
                _buildTab(label: "PAIEMENTS MOMO", icon: Icons.phone_android, color: Colors.teal, count: countsProvider.counts['paiementsMoMo']),
                _buildTab(label: "PAIEMENTS CASH", icon: Icons.payments_outlined, color: Colors.orange.shade700, count: countsProvider.counts['paiementsCash']),
                
                _buildTab(label: "ATTRIBUTION", icon: Icons.assignment_ind_outlined, color: Colors.indigo, count: countsProvider.counts['attribution']),
                _buildTab(label: "REMISE DES CLÉS", icon: Icons.vpn_key_outlined, color: Colors.purple, count: countsProvider.counts['cles']),
                _buildTab(label: "BIENS LOUÉS", icon: Icons.real_estate_agent_outlined, color: Colors.pink, count: countsProvider.counts['loues']),
                _buildTab(label: "ARCHIVES", icon: Icons.archive_outlined, color: Colors.grey, count: countsProvider.counts['archives']),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: const [
              OngletDemandesUrgentes(), 
              OngletCertification(),      
              OngletBiensCertifies(),     
              OngletValidationPaiementsMomo(), // Composant injecté
              OngletValidationPaiementsCash(), // Composant injecté
              OngletAttributionPaiements(),
              OngletRemiseCles(),         
              OngletBiensLoues(),
              OngletArchivesRejets(),     
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab({required String label, required IconData icon, required Color color, int? count}) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
          if (count != null && count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(), 
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
              ),
            ),
          ],
        ],
      ),
    );
  }
}