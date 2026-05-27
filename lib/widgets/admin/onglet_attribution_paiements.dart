// C:\Users\LANGE\easylocation_mvp\lib\widgets\admin\onglet_attribution_paiements.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart';
import 'package:easylocation_mvp/services/admin_workflow_service.dart';

class OngletAttributionPaiements extends StatefulWidget {
  const OngletAttributionPaiements({super.key});

  @override
  State<OngletAttributionPaiements> createState() => _OngletAttributionPaiementsState();
}

class _OngletAttributionPaiementsState extends State<OngletAttributionPaiements> {
  bool _isProcessing = false;
  final AdminWorkflowService _workflowService = AdminWorkflowService();

  void _refreshBadges() {
    context.read<AdminCountsProvider>().refresh();
  }

  Future<void> _capturerDossierPaye(String factureId, Map<String, dynamic> data) async {
    final profileProvider = context.read<UserProfileProvider>();
    if (profileProvider.userData == null) return;

    setState(() => _isProcessing = true);
    try {
      // ✅ CORRECTION APPLIQUÉE : On passe maintenant 'factureId' au service pour déclencher la double écriture sécurisée (Facture + Propriété)
      await _workflowService.executeSecureAction(
        propertyId: data['propertyId'] ?? '',
        factureId: factureId, 
        actionType: "ATTRIBUTION_PAIEMENT",
        adminId: profileProvider.userData!.uid,
        adminName: profileProvider.agentFullName,
        fullPropertyData: data,
        updateData: {
          FirestoreFields.assignedAdminId: profileProvider.userData!.uid,
          FirestoreFields.assignedAdminName: profileProvider.agentFullName,
          FactureFields.dateValidationAdmin: FieldValue.serverTimestamp(),
        },
      );
      
      _refreshBadges();
      _showSnack("Dossier attribué ! Retrouvez-le dans l'onglet 'Remise des Clés'.", Colors.green);
    } catch (e) {
      _showSnack("Erreur lors de l'attribution : $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(FirestoreCollections.factures)
              .where('statut', isEqualTo: 'payee') 
              .where(FirestoreFields.assignedAdminId, isNull: true)
              .orderBy(FactureFields.dateCreation, descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Erreur : ${snapshot.error}"));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return _buildEmptyState();

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              // ✅ MODIFICATION : Récupération native du paramètre index
              itemBuilder: (context, index) {
                var doc = docs[index];
                var data = doc.data() as Map<String, dynamic>;

                final Color mainColor = Colors.green.shade700;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.green.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    // ✅ MODIFICATION : CircleAvatar transformé en badge numérique indexé
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      radius: 18,
                      child: Text(
                        "${index + 1}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    // ✅ MODIFICATION : Icône de contexte basculée dans le titre pour la clarté visuelle
                    title: Row(
                      children: [
                        Icon(Icons.assignment_ind_outlined, color: mainColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "Nouveau paiement : ${data[FactureFields.totalUSD] ?? '0'} USD",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text("Réf: ${doc.id.substring(0, 8)}"),
                        Text("Zone: ${data[FactureFields.commune] ?? 'Inconnue'}",
                          style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _capturerDossierPaye(doc.id, data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("ATTRIBUER"),
                    ),
                  ),
                );
              },
            );
          },
        ),
        if (_isProcessing)
          Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "Aucun paiement en attente d'attribution.", 
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating)
    );
  }
}