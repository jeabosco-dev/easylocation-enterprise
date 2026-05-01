// lib/widgets/admin/onglet_validation_paiements.dart

import 'dart:async'; // ✅ Pour unawaited
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:easylocation_mvp/models/facture_model.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart'; 
import 'package:url_launcher/url_launcher.dart';

// ✅ AJOUTS POUR LE TRACKING
import 'package:easylocation_mvp/services/goal_tracking_service.dart';
import 'package:easylocation_mvp/models/community_goal_model.dart';

class OngletValidationPaiements extends StatelessWidget {
  const OngletValidationPaiements({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Récupération de l'ID de l'agent connecté
    final String? myId = context.watch<UserProfileProvider>().userData?.uid;

    if (myId == null) {
      return const Center(child: Text("Erreur d'authentification agent."));
    }

    return StreamBuilder<QuerySnapshot>(
      // ✅ Affiche les factures créées par cet agent qui sont en attente.
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.factures)
          .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPending)
          .where('agentId', isEqualTo: myId) 
          .orderBy(FactureFields.dateCreation, descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Erreur de flux : ${snapshot.error}"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            
            // ✅ Utilisation du modèle pour la sécurité des données
            final facture = FactureModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

            return _buildFactureCard(context, facture, myId);
          },
        );
      },
    );
  }

  Widget _buildFactureCard(BuildContext context, FactureModel facture, String myId) {
    final bool isCash = facture.methodePaiement == 'cash';
    final bool isExpired = facture.dateExpiration != null && facture.dateExpiration!.isBefore(DateTime.now());
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isExpired ? Colors.red.shade300 : (isCash ? Colors.orange.shade200 : Colors.blue.shade100), 
          width: 1.5
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero, // ✅ Ajusté pour un meilleur alignement
              leading: CircleAvatar(
                backgroundColor: isExpired ? Colors.red.shade50 : (isCash ? Colors.orange.shade50 : Colors.blue.shade50),
                child: Icon(
                  isExpired ? Icons.timer_off : (isCash ? Icons.point_of_sale : Icons.receipt_long), 
                  color: isExpired ? Colors.red : (isCash ? Colors.orange : Colors.blue.shade800)
                ),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(facture.nomClient, style: const TextStyle(fontWeight: FontWeight.bold))),
                  if (isCash) _badge("CASH", Colors.orange),
                  if (isExpired) _badge("EXPIRÉ", Colors.red),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text("🏠 Réf Maison : ${facture.refMaison}", style: const TextStyle(fontSize: 13)),
                  Text("💰 Montant : ${facture.totalUSD} USD", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  if (facture.dateExpiration != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "⏳ Expire : ${DateFormat('dd/MM à HH:mm').format(facture.dateExpiration!)}",
                        style: TextStyle(
                          color: isExpired ? Colors.red : Colors.blue.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: IconButton.filledTonal(
                icon: const Icon(Icons.phone),
                onPressed: () => launchUrl(Uri.parse("tel:${facture.telClient}")),
                style: IconButton.styleFrom(foregroundColor: Colors.green),
              ),
            ),
            const Divider(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 1. Bouton WhatsApp Bailleur
                  TextButton.icon(
                    onPressed: () => _informerBailleurWhatsApp(context, facture),
                    icon: const Icon(Icons.send, size: 18, color: Colors.green),
                    label: const Text("WHATSAPP BAILLEUR"),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  // 2. Bouton Prolonger délai
                  TextButton.icon(
                    onPressed: () => _prolongerDelai(context, facture),
                    icon: const Icon(Icons.add_alarm, size: 18),
                    label: const Text("DÉLAI +1H"),
                    style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
                  ),
                  const SizedBox(width: 8),
                  // 3. Bouton Valider
                  ElevatedButton.icon(
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
              ),
            )
          ],
        ),
      ),
    );
  }

  void _informerBailleurWhatsApp(BuildContext context, FactureModel facture) async {
    String telephone = (facture.telBailleur ?? "").replaceAll(' ', ''); 
    
    if (telephone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Numéro du bailleur manquant."), backgroundColor: Colors.orange),
      );
      return;
    }

    if (telephone.startsWith('0')) {
      telephone = "243${telephone.substring(1)}";
    }

    final String message = 
        "Bonjour Cher Partenaire, votre maison (Réf: ${facture.refMaison}) vient d'être réservée sur l'application EasyLocation. "
        "Un agent de EasyLocation rentrera en contact avec vous tout à l'heure pour fixer la visite. "
        "Merci de votre confiance !";

    final String url = "https://wa.me/$telephone?text=${Uri.encodeComponent(message)}";
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")),
        );
      }
    }
  }

  Future<void> _prolongerDelai(BuildContext context, FactureModel facture) async {
    if (facture.dateExpiration == null) return;
    
    final nouvelleDate = facture.dateExpiration!.add(const Duration(hours: 1));
    await FirebaseFirestore.instance
        .collection(FirestoreCollections.factures)
        .doc(facture.id)
        .update({'dateExpiration': Timestamp.fromDate(nouvelleDate)});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Temps de visite prolongé !"), backgroundColor: Colors.blue),
      );
    }
  }

  void _showValidationDialog(BuildContext context, FactureModel facture, String myId) {
    final TextEditingController motifController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Traitement : ${facture.nomClient}"),
            const Text("VALIDER LE PAIEMENT", style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (facture.urlPreuve != null) ...[
                const Text("Preuve de transfert :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    facture.urlPreuve!, 
                    height: 250, 
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: motifController,
                decoration: const InputDecoration(
                  labelText: "Note interne ou raison du rejet",
                  hintText: "Ex: Reçu illisible, Cash reçu...",
                  border: OutlineInputBorder()
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          OutlinedButton(
            onPressed: () => _process(context, facture, false, myId, motif: motifController.text),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("REJETER"),
          ),
          ElevatedButton(
            onPressed: () => _process(context, facture, true, myId, motif: motifController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("CONFIRMER"),
          ),
        ],
      ),
    );
  }

  Future<void> _process(BuildContext context, FactureModel facture, bool ok, String adminId, {String? motif}) async {
    final factureRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.factures)
        .doc(facture.id);

    final GoalTrackingService goalService = GoalTrackingService();

    try {
      await factureRef.update({
        FactureFields.paymentStatus: ok ? FactureFields.statusPaid : FactureFields.statusRejected,
        FactureFields.etapeDossier: ok ? 'paye' : 'cancelled',
        FactureFields.motifRejet: motif,
        FactureFields.dateActionAdmin: FieldValue.serverTimestamp(),
        'adminValidator': adminId,
      });

      // ✅ DÉCLENCHEMENT DU TRACKING SI VALIDATION
      if (ok) {
        // Sécurité : récupère la ville ou utilise Goma par défaut pour le tracking
        final String villeAction = (facture.ville != null && facture.ville!.isNotEmpty) 
            ? facture.ville! 
            : 'Goma';

        unawaited(goalService.trackAction(
          ville: villeAction, 
          type: MissionType.reservations
        ));
      }

      if (context.mounted) {
        context.read<AdminCountsProvider>().refresh(); 
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? "Paiement validé. Challenge mis à jour !" : "Dossier rejeté."),
            backgroundColor: ok ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur technique : $e"), backgroundColor: Colors.red));
      }
    }
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("Tout est à jour !", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const Text("Aucun paiement en attente pour vos dossiers.", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}