import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VerificationReservationPage extends StatelessWidget {
  final String refMaison;
  final String clientId;

  const VerificationReservationPage({
    super.key, 
    required this.refMaison, 
    required this.clientId
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Vérification de Réservation", style: TextStyle(fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('factures') 
            .where('refMaison', isEqualTo: refMaison)
            .where('clientId', isEqualTo: clientId)
            .limit(1)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blue));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildStatus(
              icon: Icons.gpp_bad_rounded,
              color: Colors.redAccent,
              title: "DOCUMENT NON RECONNU",
              message: "Cette facture ne correspond à aucune réservation active dans notre système Easy Location.",
            );
          }

          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;

          return _buildStatus(
            icon: Icons.verified_user_rounded,
            color: Colors.green.shade700,
            title: "RÉSERVATION VALIDÉE",
            message: "L'authenticité de cette facture est confirmée par Easy Location.",
            details: Column(
              children: [
                _buildDetailRow("Locataire", data['nomClient'] ?? 'Inconnu'),
                _buildDetailRow("Bien", data['refMaison'] ?? 'Inconnu'),
                _buildDetailRow("Loyer Mensuel", "${data['loyer']} \$"),
                _buildDetailRow("Statut", "PAYÉ"),
              ],
            ),
            isSuccess: true,
          );
        },
      ),
    );
  }

  Widget _buildStatus({
    required IconData icon, 
    required Color color, 
    required String title, 
    required String message, 
    Widget? details,
    bool isSuccess = false
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Icon(icon, size: 100, color: color),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 15),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 30),
          if (details != null) 
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: details,
            ),
          if (isSuccess) ...[
            const SizedBox(height: 40),
            const Divider(),
            const Text("SYSTÈME DE SÉCURITÉ EASY LOCATION", 
              style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: Colors.grey, fontWeight: FontWeight.bold)),
          ]
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}
