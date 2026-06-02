import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

class OngletZones extends StatefulWidget {
  const OngletZones({super.key});

  @override
  State<OngletZones> createState() => _OngletZonesState();
}

class _OngletZonesState extends State<OngletZones> {
  
  // --- GESTION DU RÉSEAU (AJOUT/SUPPRESSION DE QUARTIERS DANS LE SYSTÈME) ---
  void _gererConfigurationZones() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Configuration du Réseau"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: _ajouterNouveauQuartierDialog,
                icon: const Icon(Icons.add),
                label: const Text("Ajouter un Quartier"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                ),
              ),
              const Divider(),
              const Text("Quartiers actifs (Glisser pour supprimer) :", 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('config_localisation').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        return Dismissible(
                          key: Key(doc.id),
                          background: Container(
                            color: Colors.red, 
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) => doc.reference.delete(),
                          child: ListTile(
                            dense: true,
                            title: Text(doc['quartier']),
                            subtitle: Text(doc['ville']),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                              onPressed: () => _confirmerSuppressionZone(doc),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("FERMER")),
        ],
      ),
    );
  }

  void _ajouterNouveauQuartierDialog() {
    final TextEditingController villeController = TextEditingController(text: "Goma");
    final TextEditingController quartierController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nouveau Quartier"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: villeController, decoration: const InputDecoration(labelText: "Ville")),
            TextField(controller: quartierController, decoration: const InputDecoration(labelText: "Nom du Quartier")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          TextButton(
            onPressed: () async {
              if (quartierController.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('config_localisation').add({
                  'ville': villeController.text,
                  'quartier': quartierController.text,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (!mounted) return;
                Navigator.pop(context);
              }
            },
            child: const Text("VALIDER"),
          ),
        ],
      ),
    );
  }

  void _confirmerSuppressionZone(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer ?"),
        content: Text("Voulez-vous retirer '${doc['quartier']}' du système ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("NON")),
          TextButton(onPressed: () {
            doc.reference.delete();
            Navigator.pop(context);
          }, child: const Text("OUI, SUPPRIMER", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  // --- FONCTION POUR RÉINITIALISER (VIDER) LES ZONES D'UN AGENT ---
  void _reinitialiserZones(String uid, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Réinitialiser"),
        content: Text("Voulez-vous retirer toutes les zones assignées à $name ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.utilisateurs)
                  .doc(uid)
                  .update({'quartiers': []});
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text("VIDER TOUT", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- FONCTION POUR ASSIGNER UN AGENT (CHECKLIST) ---
  void _attribuerSecteur(String uid, List<String> actuels, String name) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('config_localisation').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          List<String> selectionTemp = List.from(actuels);
          var zonesDispo = snapshot.data!.docs;

          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text("Affectation : $name"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (zonesDispo.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setDialogState(() => selectionTemp.clear()),
                          icon: const Icon(Icons.layers_clear, size: 18, color: Colors.orange),
                          label: const Text("Tout décocher", style: TextStyle(fontSize: 12, color: Colors.orange)),
                        ),
                      ),
                    Expanded(
                      child: zonesDispo.isEmpty 
                        ? const Center(child: Text("Aucun quartier configuré."))
                        : ListView(
                          shrinkWrap: true,
                          children: zonesDispo.map((doc) {
                            String q = doc['quartier'];
                            return CheckboxListTile(
                              title: Text(q),
                              subtitle: Text(doc['ville']),
                              value: selectionTemp.contains(q),
                              onChanged: (val) {
                                setDialogState(() {
                                  val! ? selectionTemp.add(q) : selectionTemp.remove(q);
                                });
                              },
                            );
                          }).toList(),
                        ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection(FirestoreCollections.utilisateurs).doc(uid).update({
                      'quartiers': selectionTemp,
                    });
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text("ENREGISTRER"),
                )
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _gererConfigurationZones,
        backgroundColor: const Color(0xFF1E293B),
        icon: const Icon(Icons.settings_suggest, color: Colors.white),
        label: const Text("Paramétrer le Réseau", style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(FirestoreCollections.utilisateurs)
            .where('role', whereIn: ['operations', 'tech_support', 'certificateur', 'logistique'])
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) return const Center(child: Text("Aucun agent RH trouvé."));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              List<String> quartiers = List<String>.from(data['quartiers'] ?? []);
              String agentName = "${data['prenom']} ${data['nom']}";

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: const Icon(Icons.person, color: Colors.blue),
                  ),
                  title: Text(agentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    quartiers.isEmpty ? "Zone : Non assigné" : "Zones : ${quartiers.join(', ')}",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (quartiers.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.layers_clear_outlined, color: Colors.orangeAccent),
                          tooltip: "Vider les zones",
                          onPressed: () => _reinitialiserZones(docs[index].id, agentName),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_location_alt, color: Color(0xFF1E293B)),
                        onPressed: () => _attribuerSecteur(docs[index].id, quartiers, agentName),
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
