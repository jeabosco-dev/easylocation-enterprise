import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/facture_model.dart';
import '../widgets/manuel_payment_sheet.dart';

class MesCommandesServicesWidget extends StatelessWidget {
  final String? userId; // Ajout du paramètre pour corriger l'erreur

  const MesCommandesServicesWidget({
    super.key,
    this.userId, // Paramètre optionnel ou requis selon votre préférence
  });

  @override
  Widget build(BuildContext context) {
    // Utilise l'ID passé en paramètre, sinon récupère l'utilisateur actuel
    final String? effectiveUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;

    if (effectiveUserId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      // On écoute les factures de type 'service' liées à cet utilisateur
      stream: FirebaseFirestore.instance
          .collection('factures')
          .where('tenantId', isEqualTo: effectiveUserId)
          .where('typeFacture', isEqualTo: 'service')
          .orderBy('createdAt', descending: true)
          .limit(5) // On affiche les 5 plus récents
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // Discret si vide pour ne pas encombrer le profil
          return const SizedBox.shrink();
        }

        final documents = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.history_edu_rounded,
                      color: Colors.blueGrey.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    "Suivi de mes services",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: documents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = documents[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildServiceStatusCard(context, data, doc.id);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildServiceStatusCard(
      BuildContext context, Map<String, dynamic> data, String docId) {
    final String libelle = data['libelleService'] ?? 'Service';
    final String statut =
        (data['status'] ?? 'pending').toString().toLowerCase();
    final double montant = (data['totalAmount'] ?? 0).toDouble();

    // Logique visuelle selon le statut
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (['paid', 'validé', 'valide'].contains(statut)) {
      statusColor = Colors.green;
      statusText = "Payé / Confirmé";
      statusIcon = Icons.check_circle_outline;
    } else if (statut == 'in_progress') {
      statusColor = Colors.blue;
      statusText = "En cours d'exécution";
      statusIcon = Icons.engineering;
    } else if (statut == 'completed') {
      statusColor = Colors.purple;
      statusText = "Service terminé";
      statusIcon = Icons.verified;
    } else if (statut.contains('rejet')) {
      statusColor = Colors.red;
      statusText = "Paiement rejeté";
      statusIcon = Icons.error_outline;
    } else {
      statusColor = Colors.orange;
      statusText = "En attente de paiement";
      statusIcon = Icons.hourglass_empty;
    }

    return InkWell(
      onTap: () => _ouvrirPaiement(context, data, docId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    libelle,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${NumberFormat('#,###').format(montant)} USD",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1A237E)),
                ),
                const Text(
                  "Total",
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _ouvrirPaiement(
      BuildContext context, Map<String, dynamic> data, String docId) {
    // Conversion de la map vers le modèle Facture pour le paiement manuel
    final facture = FactureModel.fromServiceMap(data, docId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManuelPaymentSheet(
        facture: facture,
        montantFinal: (data['totalAmount'] ?? 0).toDouble(),
        devise: "USD",
        docId: docId,
        target: PaymentTarget.service,
      ),
    );
  }
}