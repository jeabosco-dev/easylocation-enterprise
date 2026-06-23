// lib/widgets/admin/category_editor_widget.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CategoryEditorWidget extends StatefulWidget {
  const CategoryEditorWidget({super.key});

  @override
  State<CategoryEditorWidget> createState() => _CategoryEditorWidgetState();
}

class _CategoryEditorWidgetState extends State<CategoryEditorWidget> {
  // On garde _db ici
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // ✅ CORRECTION : Utilisation d'un getter pour éviter l'erreur d'initialisation
  DocumentReference get _configRef => _db.collection('immobilier_config').doc('categories_bien');

  void _showAddDialog(List<dynamic> currentList) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ajouter une catégorie"),
        content: TextField(
          controller: controller, 
          decoration: const InputDecoration(hintText: "Nom de la nouvelle catégorie"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              String val = controller.text.trim();
              if (val.isEmpty) return;
              
              if (currentList.contains(val)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cette catégorie existe déjà !")));
                return;
              }

              await _configRef.update({
                'liste_categories': FieldValue.arrayUnion([val])
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(String category) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("⚠️ Attention", style: TextStyle(color: Colors.red)),
        content: Text("Êtes-vous sûr de vouloir supprimer '$category' ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _configRef.update({
        'liste_categories': FieldValue.arrayRemove([category])
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _configRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final List<dynamic> categories = data?['liste_categories'] ?? [];

        return Scaffold(
          appBar: AppBar(title: const Text("Gestion des catégories")),
          body: ListView.separated(
            // ✅ PADDING INFERIEUR AJOUTE (80) pour laisser de la place au FAB
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), 
            itemCount: categories.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(categories[index]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteCategory(categories[index]),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddDialog(categories),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}