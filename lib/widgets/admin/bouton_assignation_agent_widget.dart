// lib/widgets/admin/bouton_assignation_agent_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';

class BoutonAssignationAgentWidget extends StatelessWidget {
  final String factureId;
  final String? currentAgentTerrainId;
  final String villeMaison;

  const BoutonAssignationAgentWidget({
    super.key,
    required this.factureId,
    required this.currentAgentTerrainId,
    required this.villeMaison,
  });

  @override
  Widget build(BuildContext context) {
    // Standardisation locale de la ville recherchée (en minuscules pour la comparaison)
    final String villeRecherche = villeMaison.trim().toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      // 🕵️‍♂️ On filtre uniquement sur la direction au niveau Firestore pour rester flexible sur la casse du reste
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.utilisateurs)
          .where('direction', isEqualTo: 'OPERATIONS') 
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final docsUtilisateurs = snapshot.data?.docs ?? [];
        
        // 🛠️ Filtrage local ultra-robuste (Casse insensible pour la ville et vérification multi-rôles)
        final agentsDisponibles = docsUtilisateurs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final List<dynamic> rolesArray = data['roles'] ?? [];
          final String userVille = (data['ville'] ?? '').toString().trim().toLowerCase();
          
          final bool correspondALaVille = userVille == villeRecherche;
          final bool estValideEtActif = data['staffStatus'] == 'validated' && data['statut'] == 'actif';
          final bool aLeRoleAgent = rolesArray.contains('AGENT') || data['role'] == 'agent';

          return correspondALaVille && estValideEtActif && aLeRoleAgent;
        }).toList();

        if (agentsDisponibles.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                SizedBox(width: 5),
                Text(
                  "Aucun agent terrain dispo à BUKAVU",
                  style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

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
                      if (nouveauAgentTerrainId == null) return;

                      final bool? confirmer = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          title: const Text("Confirmer l'assignation"),
                          content: const Text("Êtes-vous sûr de vouloir assigner ce dossier à cet agent ?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true), 
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
                              child: const Text("Confirmer"),
                            ),
                          ],
                        ),
                      );

                      if (confirmer != true) return;

                      try {
                        final batch = FirebaseFirestore.instance.batch();
                        
                        final factureRef = FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(factureId);
                        batch.update(factureRef, {FactureFields.agentTerrainId: nouveauAgentTerrainId});

                        final logRef = FirebaseFirestore.instance.collection(FirestoreCollections.adminLogs).doc();
                        batch.set(logRef, {
                          AdminLogFields.typeAction: AdminLogFields.actionReassignation,
                          AdminLogFields.factureId: factureId,
                          "ancienAgent": currentAgentTerrainId,
                          "nouvelAgent": nouveauAgentTerrainId,
                          AdminLogFields.dateAction: FieldValue.serverTimestamp(),
                          AdminLogFields.details: "Changement d'agent terrain effectué par le backoffice.",
                        });

                        await batch.commit();

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Assignation réussie et loguée !"), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
                        );
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