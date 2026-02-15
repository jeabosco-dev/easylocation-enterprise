// lib/screens/mes_factures_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/facture_model.dart';
import '../widgets/manuel_payment_sheet.dart';
import '../services/pdf_service.dart';
import '../providers/user_profile_provider.dart';

class MesFacturesPage extends StatefulWidget {
  const MesFacturesPage({super.key});

  @override
  State<MesFacturesPage> createState() => _MesFacturesPageState();
}

class _MesFacturesPageState extends State<MesFacturesPage> {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  /// Gère le renvoi de preuve si l'admin a rejeté le paiement
  void _ouvrirRenvoiPreuve(Map<String, dynamic> data, String docId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManuelPaymentSheet(
        facture: FactureModel.fromMap(data),
        montantFinal: (data['totalUSD'] ?? 0).toDouble(),
        devise: "USD",
        docId: docId,
      ),
    );
  }

  /// Formatage intelligent des dates (gère Timestamp et String)
  String _formatDate(dynamic rawDate) {
    try {
      if (rawDate == null) return "Date inconnue";
      if (rawDate is Timestamp) {
        return DateFormat('dd/MM/yyyy HH:mm').format(rawDate.toDate());
      }
      if (rawDate is String) {
        DateTime dt = DateTime.parse(rawDate);
        return DateFormat('dd/MM/yyyy HH:mm').format(dt);
      }
      return "---";
    } catch (e) {
      return "---";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Paiements & Reçus",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: userId == null
          ? const Center(child: Text("Connectez-vous pour voir votre historique"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('factures')
                  .where('clientId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 70, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text("Aucune transaction trouvée.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                // Tri par date décroissante
                docs.sort((a, b) {
                  var d1 = (a.data() as Map<String, dynamic>)['dateCreation'] ?? "";
                  var d2 = (b.data() as Map<String, dynamic>)['dateCreation'] ?? "";
                  return d2.toString().compareTo(d1.toString());
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildTransactionCard(data, doc.id);
                  },
                );
              },
            ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> data, String docId) {
    final String status = (data['paymentStatus'] ?? '').toString().toLowerCase();
    final bool isValidated = status.contains('complete') || status.contains('validé');
    final bool isRejected = status.contains('reject') || status.contains('rejeté');

    Color statusColor = Colors.orange;
    String statusLabel = "EN ATTENTE";
    IconData statusIcon = Icons.access_time_rounded;

    if (isValidated) {
      statusColor = Colors.green;
      statusLabel = "PAIEMENT VALIDÉ";
      statusIcon = Icons.verified_rounded;
    } else if (isRejected) {
      statusColor = Colors.red;
      statusLabel = "PAIEMENT REJETÉ";
      statusIcon = Icons.error_outline_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER : Date et Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDate(data['dateCreation']),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // INFOS PRINCIPALES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${data['totalUSD']} \$ USD",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                    const SizedBox(height: 4),
                    Text("Réf Bien : ${data['refMaison'] ?? 'N/A'}",
                        style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  ],
                ),
                
                // BOUTON ACTIONS : Soit PDF (si validé), soit Action Invisible
                if (isValidated)
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0D47A1), size: 30),
                    onPressed: () {
                      final userProvider = Provider.of<UserProfileProvider>(context, listen: false);
                      PdfService.genererEtPartagerFacture(
                        FactureModel.fromMap(data),
                        estPaye: true,
                        tauxApplique: userProvider.tauxChange,
                      );
                    },
                  ),
              ],
            ),

            // SECTION REJET (Si applicable)
            if (isRejected) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Motif du rejet :", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(data['motifRejet'] ?? "Preuve illisible ou non conforme.",
                        style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _ouvrirRenvoiPreuve(data, docId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text("CORRIGER ET RENVOYER", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],

            // FOOTER (Si en attente)
            if (!isValidated && !isRejected)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Text(
                  "En cours de traitement par nos services...",
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade500, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
