// lib/web_admin/biens_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/property_model.dart';
import '../../widgets/badge_statut_propriete.dart';
import '../../widgets/reference_badge_widget.dart';
import '../../services/export_service.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import 'package:easylocation_mvp/widgets/admin/property_details_panel.dart';
import 'package:easylocation_mvp/widgets/admin/onglet_audit_certifications.dart';

class BiensPage extends StatefulWidget {
  const BiensPage({super.key});

  @override
  State<BiensPage> createState() => _BiensPageState();
}

class _BiensPageState extends State<BiensPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _horizontalScrollController = ScrollController();
  
  String _searchQuery = "";
  String _statusFilter = "Tous";
  String _typeFilter = "Tous"; 
  Property? _selectedProperty;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _handleExport(List<QueryDocumentSnapshot> docs) async {
    setState(() => _isExporting = true);
    try {
      await ExportService.exportPropertiesToExcel(
        docs: docs,
        fileName: "Export_Parc_Immobilier.xlsx",
        sheetName: "Propriétés",
        headers: ["Réf", "Type", "Statut", "Quartier", "Avenue", "Propriétaire", "Prix (\$)", "Garantie (mois)"],
        keys: ["referenceCourte", "typeBien", "status", "quartier", "avenue", "nomProprietaire", "price", "garantieMinimale"],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Exportation réussie !"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur export : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _deleteProperty(BuildContext context, Property property) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer ce bien ?"),
        content: Text("Voulez-vous vraiment supprimer la référence ${property.referenceCourte} ? Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER")),
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
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.properties) 
            .doc(property.id)
            .delete();
            
        if (mounted && _selectedProperty?.id == property.id) {
          setState(() => _selectedProperty = null);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bien supprimé avec succès"), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur suppression : $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(FirestoreCollections.properties).snapshots(),
        builder: (context, snapshot) {
          final int totalBiens = snapshot.data?.docs.length ?? 0;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Gestion du Parc Immobilier", 
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(20)
                      ),
                      child: Text(
                        "$totalBiens Biens enregistrés", 
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF1E5D8F),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF1E5D8F),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.home_work, size: 18),
                            const SizedBox(width: 8),
                            const Text("Inventaire"),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                              child: Text(
                                "$totalBiens", 
                                style: const TextStyle(fontSize: 10, color: Colors.white)
                              ),
                            )
                          ],
                        ),
                      ),
                      const Tab(icon: Icon(Icons.history_edu), text: "Audit des Certifications"),
                    ],
                  ),
                ),
                
                const SizedBox(height: 25),
                
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMainInventoryTab(snapshot),
                      const OngletAuditCertifications(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildMainInventoryTab(AsyncSnapshot<QuerySnapshot> snapshot) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isSmallScreen = constraints.maxWidth < 950;

        return Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderActions(snapshot.data?.docs ?? []),
                      const SizedBox(height: 20),
                      _buildFilterBar(),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Card(
                          elevation: 4,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: _buildPropertyTable(snapshot),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedProperty != null && !isSmallScreen)
                  SizedBox(
                    width: 450,
                    child: PropertyDetailsPanel(
                      property: _selectedProperty!,
                      onClose: () => setState(() => _selectedProperty = null),
                    ),
                  ),
              ],
            ),

            if (_selectedProperty != null && isSmallScreen)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: constraints.maxWidth < 500 ? constraints.maxWidth : 450,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15)
                    ],
                  ),
                  child: PropertyDetailsPanel(
                    property: _selectedProperty!,
                    onClose: () => setState(() => _selectedProperty = null),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderActions(List<QueryDocumentSnapshot> docs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: "Réf, Nom, Quartier...",
              prefixIcon: const Icon(Icons.search, color: Colors.blue),
              suffixIcon: _searchQuery.isNotEmpty 
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _searchQuery = ""),
                  ) 
                : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim().toUpperCase()),
          ),
        ),
        const SizedBox(width: 15),
        ElevatedButton.icon(
          onPressed: _isExporting || docs.isEmpty ? null : () => _handleExport(docs),
          icon: _isExporting 
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.file_download),
          label: const Text("EXPORTER EXCEL"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ["Tous", ...PropertyStatus.all].map((f) => ChoiceChip(
            label: Text(f == "Tous" ? f : PropertyStatus.getLabel(f)),
            selected: _statusFilter == f,
            onSelected: (val) { if (val) setState(() => _statusFilter = f); },
            selectedColor: Colors.blue.withOpacity(0.2),
          )).toList(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ["Tous", ...PropertyTypes.all].map((t) => ChoiceChip(
            label: Text(t == "Tous" ? "Tous les Types" : PropertyTypes.getShortLabel(t)),
            selected: _typeFilter == t,
            onSelected: (val) { if (val) setState(() => _typeFilter = t); },
            selectedColor: Colors.orange.withOpacity(0.2),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildPropertyTable(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (snapshot.hasError) return const Center(child: Text("Erreur de connexion Firestore"));
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

    var properties = snapshot.data!.docs.map((doc) => 
      Property.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

    if (_selectedProperty != null) {
      try {
        _selectedProperty = properties.firstWhere((p) => p.id == _selectedProperty!.id);
      } catch (e) {
        _selectedProperty = null;
      }
    }

    var filtered = properties.where((p) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = (p.referenceCourte ?? "").toLowerCase().contains(query) || 
                            (p.nomProprietaire ?? "").toLowerCase().contains(query) ||
                            (p.quartier ?? "").toLowerCase().contains(query);

      final matchesStatus = _statusFilter == "Tous" || p.status == _statusFilter;
      final matchesType = _typeFilter == "Tous" || p.typeBien == _typeFilter;

      return matchesSearch && matchesStatus && matchesType;
    }).toList();

    return Scrollbar(
      controller: _horizontalScrollController,
      thumbVisibility: true, 
      child: SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
            columns: const [
              DataColumn(label: Text('#')), 
              DataColumn(label: Text('RÉFÉRENCE')),
              DataColumn(label: Text('TYPE')),
              DataColumn(label: Text('STATUT')),
              DataColumn(label: Text('ADRESSE')),
              DataColumn(label: Text('PROPRIÉTAIRE')),
              DataColumn(label: Text('PRIX / GARANTIE')),
              DataColumn(label: Text('ACTIONS')),
            ],
            rows: filtered.asMap().entries.map((entry) {
              int index = entry.key;
              Property p = entry.value;

              return DataRow(
                selected: _selectedProperty?.id == p.id,
                onSelectChanged: (val) => setState(() => _selectedProperty = p),
                cells: [
                  DataCell(Text("${index + 1}", style: TextStyle(color: Colors.grey[400], fontSize: 11))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReferenceBadgeWidget(reference: p.referenceCourte),
                        if (p.hasPriorityRequest == true) 
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Tooltip(
                              message: "Demande de certification urgente",
                              child: Icon(Icons.bolt, color: Colors.orange, size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                  DataCell(Text(PropertyTypes.getShortLabel(p.typeBien))),
                  DataCell(BadgeStatutPropriete(status: p.status)),
                  DataCell(Text("${p.avenue}, Q.${p.quartier}", style: const TextStyle(fontSize: 12))),
                  DataCell(Text("${p.prenomProprietaire} ${p.nomProprietaire}")),
                  DataCell(Text("${p.price}\$ (${p.garantieMinimale}m)", 
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  DataCell(Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.blue, size: 18),
                        onPressed: () => setState(() => _selectedProperty = p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        onPressed: () => _deleteProperty(context, p),
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
  }
}