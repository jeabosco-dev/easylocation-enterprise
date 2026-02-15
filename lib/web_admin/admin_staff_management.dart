import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminStaffManagement extends StatelessWidget {
  const AdminStaffManagement({super.key});

  Future<void> _approuverEmploye(BuildContext context, String uid, String requestedRole, String nom) async {
    try {
      await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({
        'role': 'ADMIN',
        'direction': requestedRole.toUpperCase(),
        'staffStatus': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Accès validé pour $nom")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur de validation")));
    }
  }

  Future<void> _refuserDemande(String uid) async {
    await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({
      'staffStatus': 'rejected',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Demandes en attente", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('utilisateurs')
                  .where('staffStatus', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("Aucune demande."));

                return SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('EMPLOYÉ')),
                      DataColumn(label: Text('DÉPARTEMENT')),
                      DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: docs.map((doc) {
                      final user = doc.data() as Map<String, dynamic>;
                      final String nom = "${user['prenom']} ${user['nom']}";
                      final String role = user['requestedRole'] ?? 'Inconnu';

                      return DataRow(cells: [
                        DataCell(Text(nom)),
                        DataCell(Text(role.toUpperCase())),
                        DataCell(Row(
                          children: [
                            TextButton(onPressed: () => _refuserDemande(doc.id), child: const Text("Refuser", style: TextStyle(color: Colors.red))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E5D8F)),
                              onPressed: () => _approuverEmploye(context, doc.id, role, nom),
                              child: const Text("Approuver", style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        )),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
