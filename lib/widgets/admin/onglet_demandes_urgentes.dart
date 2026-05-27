// lib/widgets/admin/onglet_demandes_urgentes.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/models/formulaire_publication_model.dart';
import 'package:easylocation_mvp/widgets/admin/property_details_panel.dart';
import 'package:easylocation_mvp/services/admin_workflow_service.dart';

class OngletDemandesUrgentes extends StatefulWidget {
  const OngletDemandesUrgentes({super.key});

  @override
  State<OngletDemandesUrgentes> createState() => _OngletDemandesUrgentesState();
}

class _OngletDemandesUrgentesState extends State<OngletDemandesUrgentes> {
  bool _isProcessing = false;
  final AdminWorkflowService _workflowService = AdminWorkflowService();

  // Rafraîchir les compteurs globaux de l'admin
  void _refreshBadges() {
    context.read<AdminCountsProvider>().refresh();
  }

  // --- ACTIONS WORKFLOW ---

  Future<void> _prendreEnChargeUrgence(String propertyId, Map<String, dynamic> data) async {
    final profileProvider = context.read<UserProfileProvider>();
    if (profileProvider.userData == null) return;

    setState(() => _isProcessing = true);
    try {
      await _workflowService.captureProperty(
        propertyId: propertyId,
        adminId: profileProvider.userData!.uid,
        adminName: profileProvider.agentFullName,
        fullData: data, 
      );
      
      // 💡 SÉCURITÉ : On s'assure que le widget est toujours affiché avant de rafraîchir et notifier
      if (!mounted) return;
      _refreshBadges();
      _showSnack("Urgence capturée et verrouillée.", Colors.orange);
    } catch (e) {
      if (!mounted) return;
      _showSnack("Erreur de capture : $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _libererUrgence(String propertyId, String adminId, Map<String, dynamic> data) async {
    final bool confirm = await _showSimpleConfirmDialog(
      "LIBÉRER LE DOSSIER ?", 
      "Le dossier sera de nouveau disponible pour tous les administrateurs."
    );
    if (!confirm) return;

    setState(() => _isProcessing = true);
    try {
      await _workflowService.releaseProperty(
        propertyId: propertyId,
        adminId: adminId,
        adminName: context.read<UserProfileProvider>().agentFullName,
        fullData: data,
      );
      
      // 💡 SÉCURITÉ : Empêche le crash si l'admin a changé de page pendant le traitement
      if (!mounted) return;
      _refreshBadges();
      _showSnack("Dossier remis en jachère.", Colors.blueGrey);
    } catch (e) {
      if (!mounted) return;
      _showSnack("Erreur : $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _certifierUrgence(String id, Map<String, dynamic> data) async {
    final bool confirm = await _showSimpleConfirmDialog(
      "CERTIFIER CETTE URGENCE ?", 
      "Le bien sera immédiatement publié sur la plateforme."
    );

    if (confirm) {
      final profileProvider = context.read<UserProfileProvider>();
      setState(() => _isProcessing = true);

      try {
        await _workflowService.executeSecureAction(
          propertyId: id,
          adminId: profileProvider.userData!.uid,
          adminName: profileProvider.agentFullName,
          fullPropertyData: data,
          actionType: "CERTIFICATION_URGENTE", 
          details: "Validation prioritaire effectuée",
          updateData: {
            FirestoreFields.isVerified: true,
            FirestoreFields.isVisible: true,
            FirestoreFields.status: PropertyStatus.disponible,
            FirestoreFields.verificationDate: FieldValue.serverTimestamp(),
            FirestoreFields.processingStatus: WorkflowStatus.completed,
          },
        );
        
        // 💡 SÉCURITÉ : Barrière anti-unmounted widget
        if (!mounted) return;
        _refreshBadges();
        _showSnack("Urgence certifiée avec succès !", Colors.green);
      } catch (e) {
        if (!mounted) return;
        _showSnack("Erreur : $e", Colors.red);
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _rejeterUrgence(String id, Map<String, dynamic> data) async {
    final bool confirm = await _showSimpleConfirmDialog(
      "REJETER LE DOSSIER ?", 
      "Le bien sera archivé et ne sera pas publié."
    );

    if (confirm) {
      final profileProvider = context.read<UserProfileProvider>();
      setState(() => _isProcessing = true);

      try {
        await _workflowService.executeSecureAction(
          propertyId: id,
          adminId: profileProvider.userData!.uid,
          adminName: profileProvider.agentFullName,
          fullPropertyData: data,
          actionType: "REJET_URGENT",
          details: "Non-conformité sur demande prioritaire",
          updateData: {
            FirestoreFields.status: PropertyStatus.rejected,
            FirestoreFields.isVisible: false,
            FirestoreFields.rejectedAt: FieldValue.serverTimestamp(),
            FirestoreFields.processingStatus: WorkflowStatus.completed,
          },
        );
        
        // 💡 SÉCURITÉ : Barrière anti-unmounted widget
        if (!mounted) return;
        _refreshBadges();
        _showSnack("Dossier rejeté.", Colors.black);
      } catch (e) {
        if (!mounted) return;
        _showSnack("Erreur : $e", Colors.red);
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  // --- INTERFACE ---

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<UserProfileProvider>().userData?.uid;

    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(FirestoreCollections.properties)
              .where(FirestoreFields.isVerified, isEqualTo: false)
              .where(FirestoreFields.hasPriorityRequest, isEqualTo: true) 
              .where(FirestoreFields.status, isNotEqualTo: PropertyStatus.rejected)
              .orderBy(FirestoreFields.status)
              .orderBy(FirestoreFields.createdAt, descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text("Erreur : ${snapshot.error}"));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return _buildEmptyState();

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var doc = docs[index];
                var data = doc.data() as Map<String, dynamic>;
                final model = FormulairePublicationModel.fromFirestore(data, doc.id);

                String? assignedId = data[FirestoreFields.assignedAdminId];
                String? assignedName = data[FirestoreFields.assignedAdminName];
                bool isTaken = assignedId != null && assignedId.isNotEmpty;
                bool isMine = assignedId == myId;

                Color statusColor = isMine 
                    ? Colors.amber 
                    : (isTaken ? Colors.grey : Colors.red.shade700);

                return Card(
                  elevation: isMine ? 4 : 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isMine ? Colors.amber.shade50 : (isTaken ? Colors.grey.shade50 : Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isMine ? Colors.amber.shade700 : Colors.grey.shade300,
                      width: isMine ? 2 : 1,
                    ),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.1),
                      radius: 18,
                      child: Text(
                        "${index + 1}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isMine ? Colors.amber.shade900 : (isTaken ? Colors.grey.shade800 : Colors.red.shade900),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Icon(
                          isMine ? Icons.flash_on : (isTaken ? Icons.lock : Icons.priority_high),
                          color: statusColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "${data[FirestoreFields.typeBien] ?? 'Bien'} ${isTaken ? '($assignedName)' : ''}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text("Réf: ${model.referenceUnique} • ${data['commune'] ?? 'N/A'}", style: const TextStyle(fontSize: 12)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            _buildInfoUrgence(data),
                            const Divider(),
                            if (!isTaken)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _prendreEnChargeUrgence(doc.id, data),
                                  icon: const Icon(Icons.touch_app),
                                  label: const Text("TRAITER CETTE URGENCE"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade700, 
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              )
                            else if (isMine)
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => _libererUrgence(doc.id, myId!, data),
                                    icon: const Icon(Icons.logout, color: Colors.orange),
                                    tooltip: "Libérer le dossier",
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => _rejeterUrgence(doc.id, data),
                                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                    tooltip: "Rejeter le dossier",
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    onPressed: () => _ouvrirDetails(doc.id, data),
                                    icon: const Icon(Icons.visibility),
                                    tooltip: "Voir les détails",
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _certifierUrgence(doc.id, data),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green, 
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                    child: const Text("CERTIFIER"),
                                  ),
                                ],
                              )
                            else
                              Text(
                                "Urgence verrouillée par $assignedName", 
                                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)
                              ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            );
          },
        ),
        if (_isProcessing) 
          Container(
            color: Colors.white54,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  // --- WIDGETS ET UTILS ---

  void _ouvrirDetails(String id, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.95,
        child: PropertyDetailsPanel(
          property: Property.fromMap(data, id),
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<bool> _showSimpleConfirmDialog(String title, String content) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("CONFIRMER"),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildInfoUrgence(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "DEMANDE PRIORITAIRE : Traitement immédiat sollicité par le bailleur.",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.done_all, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text("Aucune urgence en attente. Beau travail !", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return; // Garde optionnelle supplémentaire
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating)
    );
  }
}