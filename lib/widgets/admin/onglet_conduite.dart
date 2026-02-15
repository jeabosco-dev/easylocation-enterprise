import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:easylocation_mvp/constants/constants.dart';

class OngletConduite extends StatelessWidget {
  const OngletConduite({super.key});

  // Fonction pour forcer un agent à relire et resigner (Reset)
  void _reinitialiserCertification(BuildContext context, String uid, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mise à jour des règles"),
        content: Text("Voulez-vous réinitialiser la signature de $name ? L'agent devra valider à nouveau le code de conduite à sa prochaine connexion."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.utilisateurs)
                  .doc(uid)
                  .update({
                'certification_conduite': false,
                'date_signature': null,
              });
              Navigator.pop(context);
            },
            child: const Text("RÉINITIALISER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.utilisateurs)
          .where('role', whereIn: ['operations', 'tech_support', 'certificateur', 'logistique'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                "Suivi de l'engagement éthique et confidentialité",
                style: TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  bool estCertifie = data['certification_conduite'] ?? false;
                  String dateSign = data['date_signature'] ?? "Jamais signé";
                  String agentName = "${data['prenom']} ${data['nom']}";

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        estCertifie ? Icons.verified_user : Icons.gpp_maybe_rounded,
                        color: estCertifie ? Colors.green : Colors.red,
                        size: 30,
                      ),
                      title: Text(agentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        estCertifie 
                        ? "Certifié le : $dateSign" 
                        : "Accès restreint - Signature manquante",
                        style: TextStyle(color: estCertifie ? Colors.green[700] : Colors.red),
                      ),
                      trailing: estCertifie 
                        ? IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.grey),
                            tooltip: "Forcer une nouvelle signature",
                            onPressed: () => _reinitialiserCertification(context, docs[index].id, agentName),
                          )
                        : const Badge(
                            label: Text("À SIGNER"),
                            backgroundColor: Colors.red,
                          ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
