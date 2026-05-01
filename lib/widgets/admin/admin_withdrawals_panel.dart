// lib/widgets/admin/admin_withdrawals_panel.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminWithdrawalsPanel extends StatelessWidget {
  const AdminWithdrawalsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Validation des Retraits"),
        backgroundColor: Colors.orangeAccent,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // On récupère uniquement les demandes en attente
        stream: FirebaseFirestore.instance
            .collection('demandes_retrait')
            .where('statut', isEqualTo: 'EN_ATTENTE')
            .orderBy('date', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Erreur de chargement : ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("Aucune demande de retrait en attente."),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemBuilder: (context, index) {
              var demande = docs[index];
              var data = demande.data() as Map<String, dynamic>;
              
              double montant = (data['montant'] ?? 0.0).toDouble();
              String partnerId = data['partner_id'] ?? "ID Inconnu";
              Timestamp? dateDemande = data['date'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.2),
                      child: const Icon(Icons.payments, color: Colors.orange),
                    ),
                    // Correction de l'overflow : Utilisation de contraintes flexibles
                    title: Text(
                      "$montant \$",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          "ID: $partnerId",
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (dateDemande != null)
                          Text(
                            "Le : ${dateDemande.toDate().day}/${dateDemande.toDate().month} à ${dateDemande.toDate().hour}h${dateDemande.toDate().minute.toString().padLeft(2, '0')}",
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                      ],
                    ),
                    // Bouton ajusté pour éviter de pousser sur la droite
                    trailing: SizedBox(
                      width: 100, // Largeur fixe pour stabiliser le Row interne de ListTile
                      child: ElevatedButton(
                        onPressed: () => _confirmPayment(context, demande.id, partnerId, montant),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("VALIDER"),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- LOGIQUE DE VALIDATION (BATCH WRITE) ---
  Future<void> _confirmPayment(BuildContext context, String demandeId, String partnerId, double montant) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Confirmer le règlement"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Avez-vous réellement payé $montant \$ à ce partenaire ?"),
            const SizedBox(height: 10),
            const Text(
              "Cette action est irréversible et déduira son solde instantanément.",
              style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("ANNULER", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("OUI, PAIEMENT EFFECTUÉ"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        WriteBatch batch = FirebaseFirestore.instance.batch();

        // A. Marquer la demande comme payée
        DocumentReference demandeRef = FirebaseFirestore.instance.collection('demandes_retrait').doc(demandeId);
        batch.update(demandeRef, {
          'statut': 'PAYÉ',
          'date_reglement': FieldValue.serverTimestamp(),
        });

        // B. Déduire le montant du solde du partenaire
        DocumentReference partnerRef = FirebaseFirestore.instance.collection('partenaires').doc(partnerId);
        batch.update(partnerRef, {
          'solde_commission': FieldValue.increment(-montant),
        });

        await batch.commit();
        
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Paiement validé et solde mis à jour !"), backgroundColor: Colors.green)
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erreur lors de la validation : $e"), backgroundColor: Colors.red)
        );
      }
    }
  }
}