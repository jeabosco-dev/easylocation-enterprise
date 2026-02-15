import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OngletUrgent extends StatelessWidget {
  const OngletUrgent({super.key});

  // Fonction pour marquer comme résolu (supprime le document de Firestore)
  Future<void> _marquerCommeResolu(String docId) async {
    await FirebaseFirestore.instance.collection('rapports_erreurs').doc(docId).delete();
  }

  // Fonction pour afficher les détails techniques dans une fenêtre surgissante
  void _afficherDetails(BuildContext context, Map<String, dynamic> metadata) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Détails Techniques"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📱 Modèle : ${metadata['device'] ?? 'Inconnu'}"),
            Text("⚙️ OS : ${metadata['os'] ?? 'Inconnu'}"),
            Text("📍 Ville : ${metadata['localisation'] ?? 'Inconnue'}"),
            const SizedBox(height: 10),
            const Text(
              "Conseil : Vérifiez si cette erreur est spécifique à cette version d'OS ou ce modèle.",
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rapports_erreurs')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("Aucune alerte critique pour le moment."),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var error = doc.data() as Map<String, dynamic>;
            String docId = doc.id;

            // Logique de détection intelligente de la gravité
            bool isCritique = (error['gravite'] ?? '') == 'critique' || 
                             (error['level'] ?? '') == 'error';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isCritique ? Colors.red.shade200 : Colors.orange.shade200,
                  width: 1,
                ),
              ),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: isCritique ? Colors.red.shade50 : Colors.orange.shade50,
                  child: Icon(
                    Icons.bug_report, 
                    color: isCritique ? Colors.red : Colors.orange
                  ),
                ),
                title: Text(
                  error['message'] ?? "Erreur non spécifiée", 
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
                subtitle: Text(
                  "Appareil: ${error['metadata']?['device'] ?? 'Inconnu'} | Statut: ${error['status'] ?? 'Ouvert'}",
                  style: const TextStyle(fontSize: 12),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _afficherDetails(context, error['metadata'] ?? {}),
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: const Text("Détails"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _marquerCommeResolu(docId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade50,
                            foregroundColor: Colors.green,
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text("Marquer Résolu"),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
