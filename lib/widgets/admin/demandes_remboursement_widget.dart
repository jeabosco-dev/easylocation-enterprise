import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DemandesRemboursementWidget extends StatefulWidget {
  const DemandesRemboursementWidget({super.key});

  @override
  State<DemandesRemboursementWidget> createState() => _DemandesRemboursementWidgetState();
}

class _DemandesRemboursementWidgetState extends State<DemandesRemboursementWidget> {
  String _userRole = 'agent'; // Rôle restrictif par défaut
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _verifierPermissions();
  }

  /// Récupère le rôle de l'utilisateur connecté dans Firestore
  Future<void> _verifierPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('utilisateurs')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          setState(() {
            _userRole = doc.data()?['role'] ?? 'agent';
            _isLoadingRole = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingRole = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Seuls le super_admin et le finance_admin peuvent agir sur l'argent
    final bool peutModifier = _userRole == 'super_admin' || _userRole == 'finance_admin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Demandes de Remboursement",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (!_isLoadingRole)
                Chip(
                  label: Text(_userRole.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: peutModifier ? Colors.green : Colors.amber,
                ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('refund_requests')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}"));
              if (!snapshot.hasData || _isLoadingRole) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data!.docs.where((d) {
                String s = d['status'] ?? '';
                return s == 'en_attente' || s == 'approuve';
              }).toList();

              if (docs.isEmpty) {
                return const Center(child: Text("Aucune demande en cours."));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var doc = docs[index];
                  var data = doc.data() as Map<String, dynamic>;

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: data['paymentMethod'] == 'office' ? Colors.blue.shade100 : Colors.orange.shade100,
                        child: Icon(
                          data['paymentMethod'] == 'office' ? Icons.business : Icons.phone_android,
                          color: data['paymentMethod'] == 'office' ? Colors.blue : Colors.orange,
                        ),
                      ),
                      title: Text("${data['userName'] ?? 'Utilisateur'} — ${(data['netAmount'] ?? 0).toStringAsFixed(2)} \$",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("Méthode : ${data['paymentMethod'] == 'office' ? 'Bureau' : 'Transfert Mobile'}"),
                          Text("Date : ${data['createdAt'] != null ? DateFormat('dd/MM/yyyy HH:mm').format((data['createdAt'] as Timestamp).toDate()) : '...'}"),
                          const SizedBox(height: 4),
                          _badgeStatut(data['status'] ?? 'en_attente'),
                        ],
                      ),
                      trailing: _construireActions(context, doc.id, data, peutModifier),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _badgeStatut(String status) {
    Color color = Colors.grey;
    String label = status.toUpperCase();

    if (status == 'en_attente') {
      color = Colors.orange;
      label = "EN ATTENTE";
    } else if (status == 'approuve') {
      color = Colors.blue;
      label = "APPROUVÉ";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _construireActions(BuildContext context, String docId, Map<String, dynamic> data, bool peutModifier) {
    // Si l'utilisateur n'a pas les droits, on affiche un cadenas
    if (!peutModifier) {
      return const Tooltip(
        message: "Accès restreint à la Finance",
        child: Icon(Icons.lock_outline, color: Colors.amber),
      );
    }

    if (data['status'] == 'en_attente') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            tooltip: "Approuver la demande",
            onPressed: () => _mettreAJourStatut(docId, 'approuve'),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: "Rejeter",
            onPressed: () => _mettreAJourStatut(docId, 'rejete'),
          ),
        ],
      );
    } else if (data['status'] == 'approuve') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        onPressed: () => _finaliserPaiement(context, docId, data),
        child: const Text("CONFIRMER LE PAIEMENT", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _mettreAJourStatut(String docId, String nouveauStatut) async {
    await FirebaseFirestore.instance.collection('refund_requests').doc(docId).update({
      'status': nouveauStatut,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _finaliserPaiement(BuildContext context, String docId, Map<String, dynamic> data) async {
    final batch = FirebaseFirestore.instance.batch();
    final String userId = data['userId'];
    final double montantADeduire = (data['amount'] ?? 0).toDouble();

    batch.update(FirebaseFirestore.instance.collection('refund_requests').doc(docId), {
      'status': 'paye',
      'paidAt': FieldValue.serverTimestamp(),
      'processedBy': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
    });

    DocumentReference walletRef = FirebaseFirestore.instance.collection('wallets').doc(userId);
    batch.update(walletRef, {
      'balance': FieldValue.increment(-montantADeduire),
      'pendingRefund': 0.0,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });

    DocumentReference txRef = FirebaseFirestore.instance.collection('transactions').doc();
    batch.set(txRef, {
      'userId': userId,
      'amount': montantADeduire,
      'title': "Remboursement versé",
      'type': 'retrait',
      'isPositive': false,
      'date': FieldValue.serverTimestamp(),
      'status': 'success'
    });

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Opération réussie : Paiement validé."))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur : $e"))
        );
      }
    }
  }
}