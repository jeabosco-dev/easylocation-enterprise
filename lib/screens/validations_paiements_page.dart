import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ValidationsPaiementsPage extends StatefulWidget {
  final String? contratId;

  const ValidationsPaiementsPage({super.key, this.contratId});

  @override
  State<ValidationsPaiementsPage> createState() => _ValidationsPaiementsPageState();
}

class _ValidationsPaiementsPageState extends State<ValidationsPaiementsPage> {
  bool _isProcessing = false;

  Future<void> _confirmerPaiement(String contratId, Map<String, dynamic> lastPayment) async {
    setState(() => _isProcessing = true);

    try {
      // 1. Mettre à jour le contrat pour marquer le paiement comme VALIDE
      await FirebaseFirestore.instance.collection('contracts').doc(contratId).update({
        'lastPaymentStatus': 'VALIDE',
        'statutPaiement': 'A_JOUR', 
        'dernierLoyerPaye': FieldValue.serverTimestamp(),
      });

      // 2. Optionnel : Ajouter une transaction dans un historique global
      await FirebaseFirestore.instance.collection('transactions_historique').add({
        'contratId': contratId,
        'montant': lastPayment['montant'],
        'dateValidation': FieldValue.serverTimestamp(),
        'type': 'LOYER',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Paiement confirmé avec succès !"), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Retour au profil
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erreur : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Validation de Paiement"),
        backgroundColor: const Color(0xFF1E5D8F),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('contracts')
            .doc(widget.contratId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Contrat introuvable."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final lastPayment = data['dernierPaiementDeclare'] as Map<String, dynamic>?;

          if (lastPayment == null || data['lastPaymentStatus'] != 'EN_ATTENTE') {
            return const Center(
              child: Text("Aucun paiement en attente de validation pour ce contrat."),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Nouveau paiement déclaré",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text("Locataire : ${data['locataireNom'] ?? 'Inconnu'}"),
                const Divider(height: 30),
                
                _buildInfoCard("Montant déclaré", "${lastPayment['montant']} USD"),
                _buildInfoCard("Mois concerné", lastPayment['mois'] ?? "N/A"),
                _buildInfoCard("Référence / Preuve", lastPayment['reference'] ?? "Aucune"),
                
                const SizedBox(height: 40),
                
                if (_isProcessing)
                  const Center(child: CircularProgressIndicator())
                else
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => _confirmerPaiement(widget.contratId!, lastPayment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("CONFIRMER LA RÉCEPTION", 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                
                const SizedBox(height: 15),
                
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Plus tard", style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}