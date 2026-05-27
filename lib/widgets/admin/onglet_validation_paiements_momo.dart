// lib/widgets/admin/onglet_validation_paiements_momo.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:easylocation_mvp/models/facture_model.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart'; 
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';

import 'package:easylocation_mvp/services/goal_tracking_service.dart';
import 'package:easylocation_mvp/models/community_goal_model.dart';

class OngletValidationPaiementsMomo extends StatefulWidget {
  const OngletValidationPaiementsMomo({super.key});

  @override
  State<OngletValidationPaiementsMomo> createState() => _OngletValidationPaiementsMomoState();
}

class _OngletValidationPaiementsMomoState extends State<OngletValidationPaiementsMomo> {
  bool _voirDossiersPublics = false;

  @override
  Widget build(BuildContext context) {
    final String? myId = context.watch<UserProfileProvider>().userData?.uid;

    if (myId == null) {
      return const Center(child: Text("Erreur d'authentification agent."));
    }

    // ✅ Sécurisation de la requête Firestore via le champ FactureFields.methodePaiement
    Query query = FirebaseFirestore.instance
        .collection(FirestoreCollections.factures)
        .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPending)
        .where(FactureFields.methodePaiement, whereIn: const ['manuel', 'manuel (mobile money)', 'maxicash']);

    // Gestion de l'attribution des dossiers (Publics vs Assignés)
    if (_voirDossiersPublics) {
      query = query.where(FactureFields.agentId, isNull: true);
    } else {
      query = query.where(FactureFields.agentId, isEqualTo: myId);
    }

    // Réintégration du tri chronologique stable
    query = query.orderBy(FactureFields.dateCreation, descending: true);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("Mes Dossiers MoMo", style: TextStyle(fontWeight: FontWeight.bold))),
                  selected: !_voirDossiersPublics,
                  selectedColor: const Color(0xFF1E293B),
                  labelStyle: TextStyle(color: !_voirDossiersPublics ? Colors.white : Colors.black87),
                  onSelected: (selected) {
                    if (selected) setState(() => _voirDossiersPublics = false);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("MoMo Disponibles", style: TextStyle(fontWeight: FontWeight.bold))),
                  selected: _voirDossiersPublics,
                  selectedColor: Colors.blue.shade800,
                  labelStyle: TextStyle(color: _voirDossiersPublics ? Colors.white : Colors.black87),
                  onSelected: (selected) {
                    if (selected) setState(() => _voirDossiersPublics = true);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Erreur : ${snapshot.error}"));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

              final docs = snapshot.data!.docs;

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final facture = FactureModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                  return _buildFactureCard(context, facture, myId, index + 1);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFactureCard(BuildContext context, FactureModel facture, String myId, int numeroLigne) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.blue.shade100, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                radius: 18,
                child: Text("$numeroLigne", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 13)),
              ),
              title: Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.blue.shade800, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      facture.nomClient, 
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _badge(facture.methodePaiement?.toUpperCase() ?? "MOMO", Colors.blue.shade700),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text("🏠 Réf Maison : ${facture.refMaison}", style: const TextStyle(fontSize: 13)),
                  Text("💰 Montant : ${facture.totalUSD} USD", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              trailing: IconButton.filledTonal(
                icon: const Icon(Icons.phone),
                onPressed: () => launchUrl(Uri.parse("tel:${facture.telClient}")),
                style: IconButton.styleFrom(foregroundColor: Colors.green),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _informerBailleurWhatsApp(context, facture),
                  icon: const Icon(Icons.send, size: 18, color: Colors.green),
                  label: const Text("WHATSAPP BAILLEUR"),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                ),
                _voirDossiersPublics 
                  ? ElevatedButton.icon(
                      onPressed: () => _captureDossier(context, facture, myId),
                      icon: const Icon(Icons.pan_tool_alt, size: 18),
                      label: const Text("CAPTURER"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _showValidationDialog(context, facture, myId),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text("VALIDER PAIEMENT"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                    ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _captureDossier(BuildContext context, FactureModel facture, String myId) async {
    final DocumentReference factureRef = FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(facture.id);
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(factureRef);
        if (!snapshot.exists) throw Exception("Ce dossier n'existe plus.");
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        String? currentAgentId = data[FactureFields.agentId];

        if (currentAgentId != null && currentAgentId.isNotEmpty) {
          throw Exception("Désolé, un autre agent vient de capturer ce dossier !");
        }

        transaction.update(factureRef, {
          FactureFields.agentId: myId,
          FactureFields.assignedAdminId: myId,
          'dateCaptureAgent': FieldValue.serverTimestamp(),
        });
      });

      if (context.mounted) {
        Navigator.pop(context); // Ferme le loader
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dossier capturé avec succès !"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Ferme le loader
        _showConflictDialog(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  void _showConflictDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Dossier indisponible")]),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("COMPRIS"))],
      ),
    );
  }

  // ✅ ÉTAPE 4 : Alignement strict du workflow sur la nomenclature standardisée en minuscules
  Future<void> _process(BuildContext context, FactureModel facture, bool ok, String adminId, {String? motif}) async {
    final DocumentReference factureRef = FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(facture.id);
    final DocumentReference proprieteRef = FirebaseFirestore.instance.collection(FirestoreCollections.properties).doc(facture.propertyId); 
    final GoalTrackingService goalService = GoalTrackingService();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(factureRef, {
          FactureFields.paymentStatus: ok ? FactureFields.statusPaid : FactureFields.statusRejected,
          // Utilisation des marqueurs nettoyés à la place de l'ancien bloc 'ServiceFields.statutPaye' / 'cancelled'
          FactureFields.etapeDossier: ok ? FactureFields.etapePaye : FactureFields.etapeAnnule, 
          FactureFields.motifRejet: motif,
          FactureFields.dateActionAdmin: FieldValue.serverTimestamp(),
          FactureFields.adminValidator: adminId,
          FactureFields.assignedAdminId: adminId,
        });
        transaction.update(proprieteRef, {
          FirestoreFields.status: ok ? PropertyStatus.reserved : PropertyStatus.disponible,
          FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
        });
      });

      if (ok) {
        final String villeAction = (facture.ville != null && facture.ville!.isNotEmpty) ? facture.ville! : 'bukavu'; 
        unawaited(goalService.trackAction(ville: villeAction, type: MissionType.reservations));
      }

      if (context.mounted) {
        context.read<AdminCountsProvider>().refresh(); 
        Navigator.pop(context); // Ferme l'AlertDialog de traitement
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? "Paiement validé !" : "Paiement rejeté."), backgroundColor: ok ? Colors.green : Colors.red, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red));
    }
  }

  void _showValidationDialog(BuildContext context, FactureModel facture, String myId) {
    final TextEditingController motifController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Traitement MoMo : ${facture.nomClient}"),
        content: SizedBox(
          width: 400, // 💡 SOLUTION FIXE POUR EVITER INPUT.ISFINITE ERROR
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, // 💡 CONTRAINT LE DIALOGUE EN HAUTEUR
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (facture.urlPreuve != null) ...[
                  const Text("Preuve de transfert :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showZoomedImage(context, facture.urlPreuve!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        facture.urlPreuve!, 
                        height: 180, 
                        width: double.infinity, 
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: motifController, 
                  decoration: const InputDecoration(
                    labelText: "Note ou raison de rejet", 
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          OutlinedButton(onPressed: () => _process(context, facture, false, myId, motif: motifController.text), style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text("REJETER")),
          ElevatedButton(onPressed: () => _process(context, facture, true, myId, motif: motifController.text), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text("CONFIRMER")),
        ],
      ),
    );
  }

  void _showZoomedImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            PhotoView(imageProvider: NetworkImage(url), backgroundDecoration: const BoxDecoration(color: Colors.black)),
            Positioned(top: 40, right: 20, child: CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)))),
          ],
        ),
      ),
    );
  }

  void _informerBailleurWhatsApp(BuildContext context, FactureModel facture) async {
    String telephone = (facture.telBailleur ?? "").replaceAll(' ', ''); 
    if (telephone.isEmpty) return;
    if (telephone.startsWith('0')) telephone = "243${telephone.substring(1)}";
    final String message = "Bonjour, votre maison (Réf: ${facture.refMaison}) a été réservée. Un agent vous contactera.";
    final String url = "https://wa.me/$telephone?text=${Uri.encodeComponent(message)}";
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), const Text("Aucun paiement MoMo en attente", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]));
  }
}