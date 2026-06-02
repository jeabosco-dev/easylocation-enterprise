import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import 'package:easylocation_mvp/services/service_journal.dart';

class BoutonArchivageWidget extends StatelessWidget {
  final Property property;
  final VoidCallback? onActionComplete;
  final bool forceArchiveMode; // ✅ Utilisé pour forcer l'état "Restaurer" dans la page Archive

  const BoutonArchivageWidget({
    super.key,
    required this.property,
    this.onActionComplete,
    this.forceArchiveMode = false, 
  });

  // ✅ Détermine si l'annonce est traitée comme archivée
  bool get isArchived => forceArchiveMode || property.status == 'archive';

  Future<void> _toggleStatus(BuildContext context) async {
    // Si isArchived est vrai, on restaure en 'disponible', sinon on passe en 'archive'.
    final String nouveauStatut = isArchived ? 'disponible' : 'archive';
    final String titreDialog = isArchived ? "Remettre en ligne ?" : "Archiver l'annonce ?";
    final String texteBouton = isArchived ? "RESTAURER" : "ARCHIVER";
    final Color couleurBouton = isArchived ? Colors.green : Colors.redAccent;

    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(titreDialog),
        content: Text(
          isArchived 
            ? "L'annonce '${property.title}' sera de nouveau visible sur le Marketplace."
            : "L'annonce '${property.title}' ne sera plus visible, mais restera dans vos archives.",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("ANNULER", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: couleurBouton,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(texteBouton),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        // ✅ Mise à jour Firestore avec les constantes centralisées
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.properties)
            .doc(property.id)
            .update({
          FirestoreFields.status: nouveauStatut, 
          'updatedAt': FieldValue.serverTimestamp(),
          // Ajout de la date d'archivage uniquement lors d'un nouvel archivage
          if (!isArchived) 'archivedAt': FieldValue.serverTimestamp(),
        });

        // ✅ Journalisation de l'activité
        await ServiceJournal.enregistrerActivite(
          activite: isArchived 
              ? 'Annonce restaurée : ${property.title}' 
              : 'Annonce archivée : ${property.title}',
          type: isArchived ? 'restauration' : 'archivage',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isArchived ? "✅ Annonce remise en ligne" : "📦 Annonce déplacée vers les archives"),
              behavior: SnackBarBehavior.floating,
              backgroundColor: isArchived ? Colors.green : Colors.black87,
            ),
          );
          if (onActionComplete != null) onActionComplete!();
        }
      } catch (e) {
        debugPrint("Erreur changement statut: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Une erreur est survenue")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Vert pour restaurer, Rouge/Grisé pour archiver
    final Color themeColor = isArchived ? Colors.green : Colors.red;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: themeColor.withOpacity(0.08),
        foregroundColor: themeColor,
        elevation: 0,
        side: BorderSide(color: themeColor.withOpacity(0.2)),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => _toggleStatus(context),
      icon: Icon(
        isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, 
        size: 16
      ),
      label: Text(
        isArchived ? "Restaurer" : "Archiver", 
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)
      ),
    );
  }
}
