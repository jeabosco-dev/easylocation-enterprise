import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:easylocation_mvp/widgets/bouton_archivage_widget.dart';

class MesArchivesPage extends StatelessWidget {
  const MesArchivesPage({super.key});

  Future<void> _supprimerDefinitivement(BuildContext context, Property property) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer définitivement ?"),
        content: Text("L'annonce '${property.title}' sera supprimée de nos serveurs de façon irréversible. Cette action ne peut pas être annulée."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("SUPPRIMER", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.properties)
            .doc(property.id)
            .delete();
            
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("🗑️ Annonce supprimée définitivement"), behavior: SnackBarBehavior.floating)
          );
        }
      } catch (e) {
        debugPrint("Erreur suppression: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Mes Archives", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(FirestoreCollections.properties)
            .where('bailleurId', isEqualTo: user?.uid)
            .where('status', isEqualTo: 'archive')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 70, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text("Votre dossier d'archives est vide.", style: TextStyle(color: Colors.grey, fontSize: 15)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final property = Property.fromFirestore(docs[index] as DocumentSnapshot<Map<String, dynamic>>);
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[100],
                    child: const Icon(Icons.archive, color: Colors.grey),
                  ),
                  title: Text(property.title, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                  ),
                  subtitle: Text("${property.price.toStringAsFixed(0)} \$ / mois", 
                    style: TextStyle(fontSize: 13, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ Utilisation du mode forcé pour garantir l'affichage "Restaurer"
                      BoutonArchivageWidget(
                        property: property,
                        forceArchiveMode: true, 
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 22),
                        onPressed: () => _supprimerDefinitivement(context, property),
                        tooltip: "Supprimer définitivement",
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
}
