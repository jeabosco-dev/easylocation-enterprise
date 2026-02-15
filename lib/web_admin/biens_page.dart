import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/property_model.dart';
import '../../widgets/badge_statut_propriete.dart';
import '../../widgets/reference_badge_widget.dart';
import 'package:easylocation_mvp/widgets/admin/property_details_panel.dart';

class BiensPage extends StatefulWidget {
  const BiensPage({super.key});

  @override
  State<BiensPage> createState() => _BiensPageState();
}

class _BiensPageState extends State<BiensPage> {
  String _searchQuery = "";
  String _statusFilter = "Tous";
  Property? _selectedProperty; // Gère l'affichage du panneau latéral

  // ✅ FONCTION DE SUPPRESSION AVEC CONFIRMATION
  Future<void> _deleteProperty(BuildContext context, Property property) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer ce bien ?"),
        content: Text("Voulez-vous vraiment supprimer la référence ${property.referenceCourte} ? Cette action est irréversible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("ANNULER"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("SUPPRIMER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('proprietes').doc(property.id).delete();
        if (mounted && _selectedProperty?.id == property.id) {
          setState(() => _selectedProperty = null);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bien supprimé avec succès"), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la suppression : $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            // --- PARTIE GAUCHE : TABLEAU ET FILTRES ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildFilterBar(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Card(
                      elevation: 4,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: _buildPropertyTable(),
                    ),
                  ),
                ],
              ),
            ),

            // --- PARTIE DROITE : PANEL DE DÉTAILS ---
            if (_selectedProperty != null)
              PropertyDetailsPanel(
                property: _selectedProperty!,
                onClose: () => setState(() => _selectedProperty = null),
              ),
          ],
        ),
      ),
    );
  }

  // --- ENTÊTE (Titre + Recherche) ---
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Parc Immobilier", 
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        SizedBox(
          width: 350,
          child: TextField(
            decoration: InputDecoration(
              hintText: "Réf, Propriétaire, Quartier...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), 
                borderSide: BorderSide.none
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          ),
        ),
      ],
    );
  }

  // --- BARRE DE FILTRES ---
  Widget _buildFilterBar() {
    List<String> filtres = ["Tous", "Disponible", "Réservation en cours", "Déjà louée"];
    return Row(
      children: filtres.map((f) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: ChoiceChip(
          label: Text(f),
          selected: _statusFilter == f,
          onSelected: (val) {
            if (val) setState(() => _statusFilter = f);
          },
          selectedColor: Colors.blue.withOpacity(0.2),
          labelStyle: TextStyle(
            color: _statusFilter == f ? Colors.blue[800] : Colors.black87,
            fontWeight: _statusFilter == f ? FontWeight.bold : FontWeight.normal
          ),
        ),
      )).toList(),
    );
  }

  // --- TABLEAU DES PROPRIÉTÉS ---
  Widget _buildPropertyTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('proprietes').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Erreur de connexion"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var properties = snapshot.data!.docs.map((doc) => 
          Property.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

        // Application des filtres Recherche + Statut
        var filtered = properties.where((p) {
          final matchesSearch = p.id.toLowerCase().contains(_searchQuery) || 
                                p.nomProprietaire.toLowerCase().contains(_searchQuery) ||
                                p.quartier.toLowerCase().contains(_searchQuery) ||
                                p.referenceCourte.toLowerCase().contains(_searchQuery);
          final matchesStatus = _statusFilter == "Tous" || p.status == _statusFilter;
          return matchesSearch && matchesStatus;
        }).toList();

        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                horizontalMargin: 20,
                columnSpacing: 40,
                columns: const [
                  DataColumn(label: Text('RÉFÉRENCE')),
                  DataColumn(label: Text('STATUT')),
                  DataColumn(label: Text('ADRESSE')),
                  DataColumn(label: Text('PROPRIÉTAIRE')),
                  DataColumn(label: Text('PRIX / GARANTIE')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: filtered.map((p) {
                  final bool isSelected = _selectedProperty?.id == p.id;
                  
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (val) {
                      setState(() => _selectedProperty = p);
                    },
                    cells: [
                      DataCell(ReferenceBadgeWidget(reference: p.referenceCourte)),
                      DataCell(BadgeStatutPropriete(statut: p.status)),
                      DataCell(Text("${p.avenue}, Q.${p.quartier}", 
                        style: const TextStyle(fontSize: 13))),
                      DataCell(Text("${p.prenomProprietaire} ${p.nomProprietaire}", 
                        style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text("${p.price}\$ (${p.garantieMinimale}m)", 
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                      DataCell(Row(
                        children: [
                          if (p.isVerified) 
                            const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: Icon(Icons.verified, color: Colors.blue, size: 20),
                            ),
                          IconButton(
                            icon: const Icon(Icons.visibility, color: Colors.blue, size: 20),
                            onPressed: () => setState(() => _selectedProperty = p),
                            tooltip: "Voir détails",
                          ),
                          // ✅ BOUTON SUPPRIMER AJOUTÉ ICI
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => _deleteProperty(context, p),
                            tooltip: "Supprimer",
                          ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
