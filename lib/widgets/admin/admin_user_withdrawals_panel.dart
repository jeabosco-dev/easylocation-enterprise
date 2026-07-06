import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

class AdminUserWithdrawalsPanel extends StatefulWidget {
  const AdminUserWithdrawalsPanel({super.key});

  @override
  State<AdminUserWithdrawalsPanel> createState() => _AdminUserWithdrawalsPanelState();
}

class _AdminUserWithdrawalsPanelState extends State<AdminUserWithdrawalsPanel> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Retraits Utilisateurs"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('withdraw_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Erreur : ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("Aucune demande en attente."));
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemBuilder: (context, index) {
              var demande = docs[index];
              var data = demande.data() as Map<String, dynamic>;

              double amount = (data['amount'] ?? 0.0).toDouble();
              String prenom = data['prenom'] ?? "Inconnu";
              String nom = data['nom'] ?? "";
              String telephone = data['telephone'] ?? "N/A";
              String method = data['method'] ?? "N/A";
              String accountInfo = data['accountInfo'] ?? "N/A";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text("$prenom $nom", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tél: $telephone"),
                      Text("Montant: ${amount.toStringAsFixed(2)} \$", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Text("Méthode: $method ($accountInfo)"),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: _isProcessing
                            ? null
                            : () => _handleAction(context, demande.id, "$prenom $nom", amount, false),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        onPressed: _isProcessing
                            ? null
                            : () => _handleAction(context, demande.id, "$prenom $nom", amount, true),
                        child: _isProcessing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("VAL.", style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String docId, String userName, double amount, bool isApprove) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApprove ? "Confirmer le paiement" : "Refuser le retrait"),
        content: Text("${isApprove ? "Valider" : "Refuser"} le retrait de $amount \$ pour $userName ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isApprove ? Colors.blue : Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      
      String functionName = isApprove ? 'confirmWithdrawal' : 'rejectWithdrawal';
      
      debugPrint("══════════════════════════════");
      debugPrint("🚀 Début appel Cloud Function");
      debugPrint("Fonction : $functionName");
      debugPrint("RequestId : $docId");
      debugPrint("Region : europe-west1");

      try {
        debugPrint("Envoi de la requête...");

        final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
        final callable = functions.httpsCallable(functionName);
        
        final result = await callable.call({
          'requestId': docId,
        });

        debugPrint("✅ Réponse reçue");
        debugPrint(result.data.toString());

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isApprove ? "Retrait validé avec succès !" : "Retrait refusé."),
            backgroundColor: isApprove ? Colors.green : Colors.orange,
          ),
        );
      } on FirebaseFunctionsException catch (e) {
        debugPrint("❌ FirebaseFunctionsException");
        debugPrint("code = ${e.code}");
        debugPrint("message = ${e.message}");
        debugPrint("details = ${e.details}");
        
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${e.message}"), backgroundColor: Colors.red),
        );
      } catch (e, stack) {
        debugPrint("❌ Exception inattendue");
        debugPrint(e.toString());
        debugPrint(stack.toString());
        
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur technique: ${e.toString()}"), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }
}