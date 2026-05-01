// lib/widgets/admin/onglet_archives_rejets.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:easylocation_mvp/models/formulaire_publication_model.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart'; // ✅ Import du Provider

class OngletArchivesRejets extends StatelessWidget {
  const OngletArchivesRejets({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // SOURCE DE VÉRITÉ : Tout ce qui est masqué pour le public (Archives + Rejets)
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.properties)
          .where('isVisible', isEqualTo: false)
          .orderBy('updatedAt', descending: true) 
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Erreur de chargement : ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final model = FormulairePublicationModel.fromFirestore(data, doc.id);
            
            final String statusActuel = data[FirestoreFields.status] ?? "Inconnu";
            final bool isRejected = statusActuel == 'rejected';

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: isRejected ? Colors.red.shade100 : Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: _buildLeadingIcon(statusActuel),
                title: Text(
                  "${data[FirestoreFields.typeBien]} (${model.referenceUnique})", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    _buildStatusChip(statusActuel),
                    const SizedBox(height: 4),
                    Text(
                      "Dernier agent : ${data[FirestoreFields.assignedAdminName] ?? 'N/A'}", 
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_backup_restore, color: Colors.green),
                      tooltip: "Réhabiliter",
                      onPressed: () => _actionRestauration(context, doc, data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      tooltip: "Supprimer",
                      onPressed: () => _actionSuppressionDefinitive(context, doc),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- LOGIQUE DE RESTAURATION ---
  Future<void> _actionRestauration(BuildContext context, QueryDocumentSnapshot doc, Map<String, dynamic> data) async {
    final bool confirm = await _showConfirmDialog(
      context, 
      "RÉHABILITER L'ANNONCE ?", 
      "Le bien sera remis en 'Jachère'. L'action sera enregistrée dans l'audit.",
      Colors.green
    );

    if (confirm) {
      final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
      try {
        final batch = FirebaseFirestore.instance.batch();
        final logRef = FirebaseFirestore.instance.collection('admin_logs').doc();

        batch.update(doc.reference, {
          'isVisible': true,
          'status': 'disponible',
          'processingStatus': 'jachere',
          'assignedAdminId': null,
          'assignedAdminName': null,
          'updatedAt': FieldValue.serverTimestamp(),
          'restoredBy': profileProvider.userData?.uid,
        });

        batch.set(logRef, {
          'actionType': 'REHABILITATION',
          'adminName': profileProvider.agentFullName,
          'propertyName': data[FirestoreFields.typeBien] ?? "N/A",
          'propertyId': doc.id,
          'timestamp': FieldValue.serverTimestamp(),
          'details': "Réintégration du bien dans le workflow actif.",
        });

        await batch.commit();

        // ✅ MISE À JOUR DES COMPTEURS
        if (context.mounted) {
          context.read<AdminCountsProvider>().refresh();
          _showSnack(context, "Annonce réintégrée avec succès !", Colors.green);
        }
      } catch (e) {
        if (context.mounted) _showSnack(context, "Erreur : $e", Colors.red);
      }
    }
  }

  // --- LOGIQUE DE SUPPRESSION DÉFINITIVE ---
  Future<void> _actionSuppressionDefinitive(BuildContext context, QueryDocumentSnapshot doc) async {
    final bool confirm = await _showConfirmDialog(
      context, 
      "SUPPRESSION DÉFINITIVE ?", 
      "Attention : Cette action effacera toutes les données. C'est irréversible.",
      Colors.red
    );

    if (confirm) {
      try {
        await doc.reference.delete();

        // ✅ MISE À JOUR DES COMPTEURS
        if (context.mounted) {
          context.read<AdminCountsProvider>().refresh();
          _showSnack(context, "Données purgées de la base.", Colors.black);
        }
      } catch (e) {
        if (context.mounted) _showSnack(context, "Erreur : $e", Colors.red);
      }
    }
  }

  // --- HELPERS UI ---

  Widget _buildLeadingIcon(String status) {
    IconData icon = Icons.archive;
    Color color = Colors.grey;
    if (status == 'rejected') {
      icon = Icons.report_problem;
      color = Colors.red;
    }
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildStatusChip(String status) {
    bool isRejected = status == 'rejected';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isRejected ? Colors.red.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isRejected ? "REJETÉ" : "ARCHIVÉ",
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isRejected ? Colors.red.shade900 : Colors.grey.shade700),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          const Text("Archives vides.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(BuildContext context, String title, String content, Color actionColor) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: actionColor),
            child: const Text("CONFIRMER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSnack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }
}