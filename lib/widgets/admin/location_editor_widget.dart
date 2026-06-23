import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LocationEditorWidget extends StatefulWidget {
  const LocationEditorWidget({super.key});

  @override
  State<LocationEditorWidget> createState() => _LocationEditorWidgetState();
}

class _LocationEditorWidgetState extends State<LocationEditorWidget> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Map<String, dynamic> _rootData = {'villes': {}};
  
  String? _selectedProvinceId; 
  String? _selectedVille;
  String? _selectedCommune;
  String? _selectedQuartier;

  // --- LOGIQUE DE DONNÉES ---

  Future<void> _fetchProvinceData(String provinceId) async {
    final doc = await _db.collection('zones_geographiques').doc(provinceId).get();
    if (doc.exists) {
      setState(() {
        _rootData = doc.data() as Map<String, dynamic>;
        _selectedProvinceId = provinceId;
        _selectedVille = null;
        _selectedCommune = null;
        _selectedQuartier = null;
      });
    }
  }

  // --- BOÎTE DE DIALOGUE DE SÉCURITÉ ---

  void _confirmDelete(String key, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: Text("Êtes-vous sûr de vouloir supprimer '$key' ? Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(String title, Function(String) onAdd) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "Nom")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(onPressed: () { if(controller.text.isNotEmpty) onAdd(controller.text); Navigator.pop(context); }, child: const Text("Valider")),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSection(String title, Map<String, dynamic> items, Function(String) onSelect, Function(String) onDelete, Function(String) onAdd) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ...items.keys.map((key) => ListTile(
          title: Text(key),
          tileColor: Colors.grey.shade50,
          onTap: () => onSelect(key),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red), 
            onPressed: () => _confirmDelete(key, () => onDelete(key))
          ),
        )),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text("Ajouter $title"),
          onTap: () => _showAddDialog("Nouveau $title", onAdd),
        ),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Étape 1 : Sélection de la province
    if (_selectedProvinceId == null) {
      return Scaffold(
        body: StreamBuilder<QuerySnapshot>(
          stream: _db.collection('zones_geographiques').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            return ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Gestion des Provinces", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                ...snapshot.data!.docs.map((doc) => ListTile(
                  title: Text(doc.id.toUpperCase()),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () => _confirmDelete("la province ${doc.id.toUpperCase()}", () async {
                      await _db.collection('zones_geographiques').doc(doc.id).delete();
                    }),
                  ),
                  onTap: () => _fetchProvinceData(doc.id),
                )),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text("Ajouter une Province"),
          onPressed: () => _showAddDialog("Nom de la nouvelle province", (name) async {
            await _db.collection('zones_geographiques').doc(name.toLowerCase().trim()).set({'villes': {}});
          }),
        ),
      );
    }

    // Étape 2 : Édition
    var villes = (_rootData['villes'] as Map? ?? {}).cast<String, dynamic>();
    var communes = (_selectedVille != null) ? (villes[_selectedVille] as Map? ?? {}).cast<String, dynamic>() : <String, dynamic>{};
    var quartiers = (_selectedCommune != null) ? (communes[_selectedCommune] as Map? ?? {}).cast<String, dynamic>() : <String, dynamic>{};
    var avenues = (_selectedQuartier != null) ? (quartiers[_selectedQuartier] as List? ?? []).cast<dynamic>() : <dynamic>[];

    return Column(
      children: [
        ListTile(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedProvinceId = null)),
          title: Text("Province : ${_selectedProvinceId!.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: ElevatedButton(
            onPressed: () => _db.collection('zones_geographiques').doc(_selectedProvinceId).set(_rootData), 
            child: const Text("💾 Enregistrer")
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSection("Villes", villes, (v) => setState(() => {_selectedVille = v, _selectedCommune = null, _selectedQuartier = null}), (v) => setState(() => villes.remove(v)), (v) => setState(() => villes[v] = {})),
                if (_selectedVille != null) 
                  _buildSection("Communes de $_selectedVille", communes, (c) => setState(() => {_selectedCommune = c, _selectedQuartier = null}), (c) => setState(() => communes.remove(c)), (c) => setState(() => communes[c] = {})),
                if (_selectedCommune != null)
                  _buildSection("Quartiers de $_selectedCommune", quartiers, (q) => setState(() => _selectedQuartier = q), (q) => setState(() => quartiers.remove(q)), (q) => setState(() => quartiers[q] = [])),
                if (_selectedQuartier != null) ...[
                  const Padding(padding: EdgeInsets.all(8), child: Text("Avenues", style: TextStyle(fontWeight: FontWeight.bold))),
                  ...avenues.map((a) => ListTile(title: Text(a.toString()), trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _confirmDelete(a, () => setState(() => avenues.remove(a)))))),
                  ListTile(leading: const Icon(Icons.add), title: const Text("Ajouter une avenue"), onTap: () => _showAddDialog("Nouvelle avenue", (a) => setState(() => avenues.add(a)))),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }
}