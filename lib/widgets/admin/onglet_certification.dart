// lib/widgets/admin/onglet_certification.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/models/formulaire_publication_model.dart';
import 'package:easylocation_mvp/widgets/admin/property_details_panel.dart'; 
import 'package:easylocation_mvp/services/admin_workflow_service.dart';

class OngletCertification extends StatefulWidget {
  const OngletCertification({super.key});

  @override
  State<OngletCertification> createState() => _OngletCertificationState();
}

class _OngletCertificationState extends State<OngletCertification> {
  bool _isProcessing = false;
  final AdminWorkflowService _workflowService = AdminWorkflowService();

  // --- LOGIQUE COMMUNE ---
  void _refreshBadges() {
    context.read<AdminCountsProvider>().refresh();
  }

  Future<void> _appelerBailleur(String? telephone) async {
    if (telephone == null || telephone.isEmpty) {
      _showSnack("Numéro de téléphone non renseigné.", Colors.red);
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: telephone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        _showSnack("Impossible de lancer l'appel.", Colors.red);
      }
    } catch (e) {
      _showSnack("Erreur lors de l'appel : $e", Colors.red);
    }
  }

  // --- ACTIONS WORKFLOW ---

  Future<void> _prendreEnChargeDossier(String propertyId, Map<String, dynamic> data) async {
    final profileProvider = context.read<UserProfileProvider>();
    setState(() => _isProcessing = true);

    try {
      await _workflowService.captureProperty(
        propertyId: propertyId,
        adminId: profileProvider.userData!.uid,
        adminName: profileProvider.agentFullName,
        fullData: data,
      );
      _refreshBadges();
      _showSnack("Dossier verrouillé à votre nom.", Colors.blue);
    } catch (e) {
      _showSnack("Échec de capture : $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _libererDossier(String propertyId, String adminId, Map<String, dynamic> data) async {
    final bool confirm = await _showSimpleConfirmDialog(
      "LIBÉRER LE DOSSIER ?", 
      "Le dossier redeviendra disponible pour les autres agents."
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
      _refreshBadges();
      _showSnack("Dossier remis en jachère.", Colors.blueGrey);
    } catch (e) {
      _showSnack("Erreur : $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _validerCertification(String id, Map<String, dynamic> data) async {
    final bool confirm = await _showSimpleConfirmDialog(
      "CERTIFIER CE BIEN ?", 
      "Il sera immédiatement visible par tous les utilisateurs."
    );

    if (confirm) {
      _executeSecureAction(
        propertyId: id,
        fullPropertyData: data,
        actionType: "CERTIFICATION",
        updateData: {
          FirestoreFields.isVerified: true,
          FirestoreFields.isVisible: true,
          FirestoreFields.verificationDate: FieldValue.serverTimestamp(),
          FirestoreFields.status: PropertyStatus.disponible, 
          FirestoreFields.processingStatus: WorkflowStatus.completed,
        },
      );
    }
  }

  void _rejeterPropriete(String id, Map<String, dynamic> data) async {
    final bool confirm = await _showSimpleConfirmDialog(
      "REJETER LE DOSSIER ?", 
      "Le bien sera marqué comme rejeté et ne sera pas publié."
    );
    if (confirm) {
      _executeSecureAction(
        propertyId: id,
        fullPropertyData: data,
        actionType: "REJET",
        updateData: {
          FirestoreFields.status: PropertyStatus.rejected,
          FirestoreFields.isVisible: false, 
          FirestoreFields.processingStatus: WorkflowStatus.completed,
        },
      );
    }
  }

  Future<void> _executeSecureAction({
    required String propertyId,
    required Map<String, dynamic> updateData,
    required String actionType,
    required Map<String, dynamic> fullPropertyData,
    String details = "",
  }) async {
    final profileProvider = context.read<UserProfileProvider>();
    setState(() => _isProcessing = true);

    try {
      await _workflowService.executeSecureAction(
        propertyId: propertyId,
        updateData: updateData,
        actionType: actionType,
        adminId: profileProvider.userData!.uid,
        adminName: profileProvider.agentFullName,
        fullPropertyData: fullPropertyData,
        details: details,
      );
      _refreshBadges();
      _showSnack("Action effectuée avec succès.", Colors.green);
    } catch (e) {
      if (mounted) _showSnack("Erreur : $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
              .where(FirestoreFields.status, isNotEqualTo: PropertyStatus.rejected)
              .orderBy(FirestoreFields.status) 
              .orderBy(FirestoreFields.createdAt, descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text("Erreur : ${snapshot.error}"));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            final allDocs = snapshot.data!.docs;
            if (allDocs.isEmpty) return _buildEmptyState();

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allDocs.length,
              itemBuilder: (context, index) {
                var doc = allDocs[index];
                var data = doc.data() as Map<String, dynamic>;
                final model = FormulairePublicationModel.fromFirestore(data, doc.id);

                String? assignedId = data[FirestoreFields.assignedAdminId];
                String? assignedName = data[FirestoreFields.assignedAdminName];
                bool isTaken = assignedId != null && assignedId.isNotEmpty;
                bool isMine = assignedId == myId;

                // Icône et couleur adaptées au statut
                IconData statusIcon = isMine 
                    ? Icons.edit_note 
                    : (isTaken ? Icons.lock : Icons.notification_important_outlined);
                Color statusColor = isMine 
                    ? Colors.blue 
                    : (isTaken ? Colors.grey : Colors.orange);

                return Card(
                  elevation: isMine ? 4 : 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isMine ? Colors.blue.shade50 : (isTaken ? Colors.grey.shade100 : Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isMine ? Colors.blue : Colors.grey.shade300, width: isMine ? 2 : 1),
                  ),
                  child: ExpansionTile(
                    // ✅ MODIFICATION : Le CircleAvatar affiche l'index de ligne dynamique (index + 1)
                    leading: _buildLeadingIcon(isTaken, isMine, index + 1),
                    // ✅ MODIFICATION : Row contenant l'icône contextuelle originale + l'intitulé du bien
                    title: Row(
                      children: [
                        Icon(
                          statusIcon,
                          color: isMine ? Colors.blue.shade700 : (isTaken ? Colors.grey.shade600 : Colors.orange.shade700),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "${data[FirestoreFields.typeBien] ?? 'Bien'} ${isTaken ? '($assignedName)' : ''}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 14,
                              color: isMine ? Colors.blue.shade900 : (isTaken ? Colors.grey.shade600 : Colors.black87),
                            ),
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
                            const Divider(),
                            _buildBailleurRow(data),
                            const SizedBox(height: 12),
                            if (!isTaken)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _prendreEnChargeDossier(doc.id, data),
                                  icon: const Icon(Icons.touch_app),
                                  label: const Text("TRAITER CE DOSSIER"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                                ),
                              )
                            else if (isMine)
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => _libererDossier(doc.id, myId!, data),
                                    icon: const Icon(Icons.logout, color: Colors.orange), 
                                    tooltip: "Libérer le dossier",
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => _rejeterPropriete(doc.id, data),
                                    child: const Text("REJETER", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton.filledTonal(
                                    onPressed: () => _ouvrirDetails(doc.id, data),
                                    icon: const Icon(Icons.visibility),
                                    tooltip: "Vérifier le dossier",
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _validerCertification(doc.id, data),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    child: const Text("CERTIFIER"),
                                  ),
                                ],
                              )
                            else
                              Text(
                                "Dossier verrouillé par $assignedName",
                                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12),
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
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  // --- WIDGETS ET UTILS ---

  // ✅ MODIFICATION : Prise en charge de numeroLigne pour un rendu harmonieux
  Widget _buildLeadingIcon(bool isTaken, bool isMine, int numeroLigne) {
    Color baseColor = isMine ? Colors.blue : (isTaken ? Colors.grey : Colors.orange);
    return CircleAvatar(
      backgroundColor: baseColor.withOpacity(0.1),
      radius: 18,
      child: Text(
        "$numeroLigne",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isMine ? Colors.blue.shade900 : (isTaken ? Colors.grey.shade800 : Colors.orange.shade900),
          fontSize: 13,
        ),
      ),
    );
  }

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

  Widget _buildBailleurRow(Map<String, dynamic> data) {
    return Row(
      children: [
        const Icon(Icons.person_outline, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "${data['prenomProprietaire'] ?? ''} ${data['nomProprietaire'] ?? 'Inconnu'}",
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => _appelerBailleur(data['telephoneProprietaire']),
          icon: const Icon(Icons.phone_in_talk, size: 18),
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.done_all, size: 64, color: Colors.green.shade100),
          const SizedBox(height: 16),
          const Text("Aucune certification en attente.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Future<bool> _showSimpleConfirmDialog(String title, String content) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("CONFIRMER")),
        ],
      ),
    ) ?? false;
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating)
    );
  }
}