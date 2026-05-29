// lib/widgets/admin/bouton_assignation_agent_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart'; // Importation nécessaire pour FactureFields & FirestoreCollections

class BoutonAssignationAgentWidget extends StatelessWidget {
  final String factureId;
  final String? currentAgentTerrainId; // ✅ MODIFIÉ : Renommé pour correspondre à la clé unifiée
  final String villeMaison;           // La ville de la maison (ex: 'Bukavu' ou 'Goma')

  const BoutonAssignationAgentWidget({
    super.key,
    required this.factureId,
    required this.currentAgentTerrainId, // ✅ MODIFIÉ
    required this.villeMaison,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // 🔍 Filtrage industriel : Rôle 'operations' ET même ville que la propriété
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.utilisateurs) // Utilisé la constante si dispo, sinon 'utilisateurs'
          .where('role', isEqualTo: 'operations')
          .where('ville', isEqualTo: villeMaison)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                SizedBox(width: 5),
                Text(
                  "Aucun agent terrain dispo dans cette ville",
                  style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        final agentsDisponibles = snapshot.data!.docs;

        // Sécurité : On vérifie si l'agentTerrainId stocké dans la facture existe toujours dans notre liste filtrée
        final bool lAgentActuelEstDansLaListe = agentsDisponibles.any((doc) => doc.id == currentAgentTerrainId);
        final String? dropdownValue = lAgentActuelEstDansLaListe ? currentAgentTerrainId : null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(
                dropdownValue != null ? Icons.directions_run : Icons.person_add_alt_1,
                size: 18,
                color: dropdownValue != null ? const Color(0xFF1E293B) : Colors.grey,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    hint: const Text(
                      "Assigner un agent de terrain",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    value: dropdownValue,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1E293B)),
                    items: agentsDisponibles.map((agentDoc) {
                      final agent = agentDoc.data() as Map<String, dynamic>;
                      final prenom = agent['prenom'] ?? '';
                      final nom = agent['nom'] ?? '';
                      
                      return DropdownMenuItem<String>(
                        value: agentDoc.id,
                        child: Text(
                          "$prenom $nom",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                    onChanged: (nouveauAgentTerrainId) async {
                      if (nouveauAgentTerrainId != null) {
                        try {
                          // 📝 Écriture directe et propre de la nouvelle clé cible dans Firestore
                          await FirebaseFirestore.instance
                              .collection(FirestoreCollections.factures)
                              .doc(factureId)
                              .update({FactureFields.agentTerrainId: nouveauAgentTerrainId}); // ✅ MODIFIÉ : Clé propre sans repli

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Mission terrain assignée avec succès !"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Erreur lors de l'assignation : $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}