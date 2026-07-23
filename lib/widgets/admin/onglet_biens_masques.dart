// lib/widgets/admin/onglet_biens_masques.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/widgets/admin/moderation_actions_widget.dart';
import 'package:easylocation_mvp/widgets/admin/property_details_panel.dart';
import 'package:intl/intl.dart';

class OngletBiensMasques extends StatelessWidget {
  const OngletBiensMasques({super.key});

  Future<void> _ouvrirDetails(BuildContext context, Property property) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.95,
        child: PropertyDetailsPanel(
          property: property,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.properties)
          .where('moderationStatus', isEqualTo: 'masquee')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Erreur de chargement : ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility_off_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text("Aucun bien masqué pour le moment.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final property = Property.fromMap(data, doc.id);

            final String reason = data['moderationReason'] ?? 'Aucune raison spécifiée';
            final Timestamp? modDate = data['moderationDate'] as Timestamp?;
            final String dateFormatted = modDate != null 
                ? DateFormat('dd/MM/yyyy HH:mm').format(modDate.toDate()) 
                : "Date inconnue";

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.orange.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.orange.withOpacity(0.1),
                              radius: 16,
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${property.typeBien} (Réf : ${property.id})",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "MASQUÉ",
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text("📅 Date de masquage : $dateFormatted", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 6),
                    Text(
                      "⚠️ Motif : $reason",
                      style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _ouvrirDetails(context, property),
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text("Inspecter le bien"),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    // Intégration directe de votre widget de modération pour permettre la remise en ligne immédiate
                    ModerationActionsWidget(property: property),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}