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
import 'package:easylocation_mvp/widgets/admin/onglet_validation_paiements.dart'; 
import 'package:easylocation_mvp/widgets/admin/onglet_certification.dart';
import 'package:easylocation_mvp/widgets/admin/onglet_biens_certifies.dart'; 
import 'package:easylocation_mvp/widgets/admin/onglet_attribution_paiements.dart'; // Nouveau widget
import 'package:easylocation_mvp/widgets/admin/onglet_remise_cles.dart';
import 'package:easylocation_mvp/widgets/admin/onglet_archives_rejets.dart';

class OperationsModule extends StatefulWidget {
  const OperationsModule({super.key});

  @override
  State<OperationsModule> createState() => _OperationsModuleState();
}

class _OperationsModuleState extends State<OperationsModule> {
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    // On lance le premier chargement au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminCountsProvider>().refresh();
    });
  }

  // --- FONCTION D'EXPORTATION ---
  Future<void> _exportRapportAudit() async {
    setState(() => _isExporting = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.properties)
          .where(FirestoreFields.status, isEqualTo: PropertyStatus.disponible)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) _showSnack("Aucun bien disponible trouvé.", Colors.orange);
        return;
      }

      await ExportService.exportPropertiesToExcel(
        docs: snapshot.docs,
        fileName: "Rapport_SGA_Audit_${DateTime.now().day}_${DateTime.now().month}.xlsx",
        sheetName: "Certification SGA",
        headers: ["RÉF", "TYPE", "PROPRIÉTAIRE", "PRIX", "DATE"],
        keys: ["id", "typeBien", "nomProprietaire", "price", "updatedAt"],
      );

      if (mounted) _showSnack("Export réussi", Colors.green);
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

    // On utilise Consumer pour écouter uniquement les changements de badges
    return Consumer<AdminCountsProvider>(
      builder: (context, countsProvider, child) {
        return DefaultTabController(
          length: 7, // Passage à 7 onglets
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              title: const Text("CENTRE DE COMMANDE", 
                style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  onPressed: countsProvider.isLoading ? null : () => countsProvider.refresh(),
                  icon: Icon(
                    Icons.refresh, 
                    color: countsProvider.isLoading ? Colors.grey : Colors.blue
                  ),
                  tooltip: "Actualiser les compteurs",
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportRapportAudit, 
                    icon: _isExporting 
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.assessment_outlined, size: 20),
                    label: const Text("RAPPORT D'AUDIT"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                labelColor: const Color(0xFF1E293B),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                indicatorWeight: 3,
                tabs: [
                  _buildTab(label: "DEMANDES URGENTES", icon: Icons.bolt, color: Colors.orange, count: countsProvider.counts['urgents']),
                  _buildTab(label: "CERTIFICATIONS", icon: Icons.pending_actions, color: Colors.blue, count: countsProvider.counts['certifications']),
                  _buildTab(label: "BIENS EN LIGNE", icon: Icons.verified, color: Colors.green, count: countsProvider.counts['enLigne']),
                  _buildTab(label: "PAIEMENTS", icon: Icons.payments_outlined, color: Colors.teal, count: countsProvider.counts['paiements']),
                  
                  // Nouvel Onglet d'Attribution
                  _buildTab(label: "ATTRIBUTION", icon: Icons.assignment_ind_outlined, color: Colors.indigo, count: countsProvider.counts['attribution']),
                  
                  _buildTab(label: "REMISE DES CLÉS", icon: Icons.vpn_key_outlined, color: Colors.purple, count: countsProvider.counts['cles']),
                  _buildTab(label: "ARCHIVES", icon: Icons.archive_outlined, color: Colors.grey, count: countsProvider.counts['archives']),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                OngletDemandesUrgentes(), 
                OngletCertification(),      
                OngletBiensCertifies(),     
                OngletValidationPaiements(),
                
                // Nouveau Widget d'Attribution
                OngletAttributionPaiements(),
                
                OngletRemiseCles(),         
                OngletArchivesRejets(),     
              ],
            ),
          ),
        );
      },
    );
  }

  // --- HELPER POUR CONSTRUIRE UN ONGLET AVEC CHIFFRE ---
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