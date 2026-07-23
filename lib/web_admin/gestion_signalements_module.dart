import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/widgets/admin/property_details_panel.dart';
import 'package:easylocation_mvp/widgets/admin/onglet_biens_masques.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import 'package:intl/intl.dart';

class GestionSignalementsModule extends StatefulWidget {
  const GestionSignalementsModule({super.key});

  @override
  State<GestionSignalementsModule> createState() => _GestionSignalementsModuleState();
}

enum FilterStatus { tous, nouveau, traite }
enum SignalementSubView { signalements, biensMasques }

class _GestionSignalementsModuleState extends State<GestionSignalementsModule> {
  String _searchQuery = '';
  FilterStatus _selectedFilter = FilterStatus.tous;
  SignalementSubView _selectedSubView = SignalementSubView.signalements;

  Future<void> _updateStatus(DocumentReference ref, String newStatus) async {
    await ref.update({'status': newStatus});
  }

  Future<void> _confirmDelete(BuildContext context, DocumentReference ref) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: const Text("Voulez-vous vraiment supprimer ce signalement ? Cette action est irréversible."),
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
      await ref.delete();
    }
  }

  Future<void> _ouvrirDetails(BuildContext context, String propertyId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.properties)
          .doc(propertyId)
          .get();

      if (context.mounted) Navigator.pop(context);

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (context) => FractionallySizedBox(
              heightFactor: 0.95,
              child: PropertyDetailsPanel(
                property: Property.fromMap(data, doc.id),
                onClose: () => Navigator.pop(context),
              ),
            ),
          );
        }
      } else {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ce bien n'existe plus.")));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sélecteur de vue principale (Signalements vs Biens Masqués)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SegmentedButton<SignalementSubView>(
            segments: const [
              ButtonSegment(
                value: SignalementSubView.signalements,
                label: Text("Signalements d'abus"),
                icon: Icon(Icons.report_problem),
              ),
              ButtonSegment(
                value: SignalementSubView.biensMasques,
                label: Text("Biens masqués (Modération)"),
                icon: Icon(Icons.visibility_off),
              ),
            ],
            selected: {_selectedSubView},
            onSelectionChanged: (newSelection) => setState(() => _selectedSubView = newSelection.first),
          ),
        ),

        // Affichage dynamique selon la sous-vue choisie
        Expanded(
          child: _selectedSubView == SignalementSubView.signalements
              ? _buildSignalementsList()
              : const OngletBiensMasques(),
        ),
      ],
    );
  }

  Widget _buildSignalementsList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: "Rechercher un signalement",
              hintText: "ID, type ou description...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SegmentedButton<FilterStatus>(
            segments: const [
              ButtonSegment(value: FilterStatus.tous, label: Text("Tous")),
              ButtonSegment(value: FilterStatus.nouveau, label: Text("Nouveaux")),
              ButtonSegment(value: FilterStatus.traite, label: Text("Traités")),
            ],
            selected: {_selectedFilter},
            onSelectionChanged: (newSelection) => setState(() => _selectedFilter = newSelection.first),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('abus_signalement').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              var allDocs = snapshot.data!.docs;
              
              final int total = allDocs.length;
              final int nouveaux = allDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'nouveau').length;
              final int traites = allDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'traité').length;

              var docs = allDocs;

              if (_selectedFilter != FilterStatus.tous) {
                final statusString = _selectedFilter == FilterStatus.nouveau ? 'nouveau' : 'traité';
                docs = docs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == statusString).toList();
              }

              if (_searchQuery.isNotEmpty) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final text = "${doc.id} ${data['type_abus'] ?? ''} ${data['description'] ?? ''}".toLowerCase();
                  return text.contains(_searchQuery);
                }).toList();
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem("Total", "$total", Colors.black),
                            _statItem("Nouveaux", "$nouveaux", Colors.red),
                            _statItem("Traités", "$traites", Colors.green),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  Expanded(
                    child: docs.isEmpty 
                      ? const Center(child: Text("Aucun résultat trouvé."))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final ref = docs[index].reference;
                            final status = data['status'] ?? 'nouveau';
                            final propertyId = data['propriete_id'] ?? '';
                            final signaleurId = data['signaleur_id'] ?? '';
                            final description = data['description'] ?? 'Aucune description fournie.';
                            
                            final Timestamp? ts = data['timestamp'] as Timestamp?;
                            final String dateFormatted = ts != null 
                                ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate()) 
                                : "Date inconnue";

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("#${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Icon(status == 'traité' ? Icons.check_circle : Icons.warning_amber_rounded, 
                                         color: status == 'traité' ? Colors.green : Colors.orange, size: 20),
                                  ],
                                ),
                                title: Text("Signalement: ${data['type_abus'] ?? 'Non spécifié'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text("📅 $dateFormatted", style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                                    const SizedBox(height: 8),
                                    ExpandableDescription(text: description),
                                    const SizedBox(height: 8),
                                    SignalementInfoWidget(reporterId: signaleurId, propertyId: propertyId),
                                    const SizedBox(height: 4),
                                    Text("Statut: ${status.toUpperCase()}", style: TextStyle(fontWeight: FontWeight.bold, color: status == 'traité' ? Colors.green : Colors.red)),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(status == 'nouveau' ? Icons.check_circle_outline : Icons.refresh, color: Colors.blue),
                                      onPressed: () => _updateStatus(ref, status == 'nouveau' ? 'traité' : 'nouveau'),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.visibility, color: Colors.indigo),
                                      onPressed: propertyId.isNotEmpty ? () => _ouvrirDetails(context, propertyId) : null,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _confirmDelete(context, ref),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// --- Widgets auxiliaires ---
class ExpandableDescription extends StatefulWidget {
  final String text;
  const ExpandableDescription({super.key, required this.text});

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool isExpanded = false;
  @override
  Widget build(BuildContext context) {
    if (widget.text.length <= 100) return Text(widget.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isExpanded ? widget.text : "${widget.text.substring(0, 100)}..."),
        InkWell(
          onTap: () => setState(() => isExpanded = !isExpanded),
          child: Text(isExpanded ? "Voir moins" : "Voir plus", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }
}

class SignalementInfoWidget extends StatelessWidget {
  final String reporterId;
  final String propertyId;
  const SignalementInfoWidget({super.key, required this.reporterId, required this.propertyId});

  Future<Map<String, String>> _fetchDetails() async {
    final db = FirebaseFirestore.instance;
    final reporterDoc = await db.collection('utilisateurs').doc(reporterId).get();
    final r = reporterDoc.data() ?? {};
    final telR = r['telephone'] ?? r['tel'] ?? 'N/A';
    final emailR = r['email'] ?? 'N/A';
    final reporterInfo = "${r['nom'] ?? 'Inconnu'} ${r['prenom'] ?? ''} (Tél: $telR, Email: $emailR)";

    final propDoc = await db.collection(FirestoreCollections.properties).doc(propertyId).get();
    String bailleurInfo = "Bailleur inconnu";
    if (propDoc.exists) {
      final pData = propDoc.data()!;
      final nom = pData['nomProprietaire'] ?? '';
      final prenom = pData['prenomProprietaire'] ?? '';
      final tel = pData['telephoneProprietaire'] ?? 'N/A';
      final email = pData['emailProprietaire'] ?? 'N/A';
      if (nom.isNotEmpty || prenom.isNotEmpty) {
        bailleurInfo = "$nom $prenom (Tél: $tel, Email: $email)";
      }
    }
    return {'reporter': reporterInfo, 'bailleur': bailleurInfo};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _fetchDetails(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text("Chargement...", style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic));
        final data = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("👤 Signalé par: ${data['reporter']}", style: const TextStyle(fontSize: 12)),
            Text("🏠 Bailleur: ${data['bailleur']}", style: const TextStyle(fontSize: 12)),
          ],
        );
      },
    );
  }
}