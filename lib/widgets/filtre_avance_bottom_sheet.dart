// lib/widgets/filtre_avance_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:easylocation_mvp/models/filtre_propriete_model.dart';
import 'package:easylocation_mvp/widgets/selecteur_localisation.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import 'package:easylocation_mvp/services/location_service.dart';

class FiltreAvanceBottomSheet extends StatefulWidget {
  final FiltreProprieteModel initialFiltre;
  const FiltreAvanceBottomSheet({super.key, required this.initialFiltre});

  @override
  State<FiltreAvanceBottomSheet> createState() => _FiltreAvanceBottomSheetState();
}

class _FiltreAvanceBottomSheetState extends State<FiltreAvanceBottomSheet> {
  final LocationService _locService = LocationService();
  late FiltreProprieteModel _tempFiltre;

  List<String> _villes = [];
  List<String> _communes = [];
  List<String> _quartiers = [];

  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _villeSpecCtrl = TextEditingController();
  final TextEditingController _communeSpecCtrl = TextEditingController();
  final TextEditingController _quartierSpecCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tempFiltre = widget.initialFiltre.copy();
    _priceController.text = _tempFiltre.maxPrice?.toString() ?? '';
    _refController.text = _tempFiltre.queryReference ?? '';
    _villeSpecCtrl.text = _tempFiltre.villeSpecifique ?? '';
    _communeSpecCtrl.text = _tempFiltre.communeSpecifique ?? '';
    _quartierSpecCtrl.text = _tempFiltre.quartierSpecifique ?? '';

    _initData();
  }

  Future<void> _initData() async {
    if (_tempFiltre.province != null) await _loadVilles(_tempFiltre.province!);
    if (_tempFiltre.ville != null && _tempFiltre.ville != "Autre") await _loadCommunes(_tempFiltre.province!, _tempFiltre.ville!);
    if (_tempFiltre.commune != null && _tempFiltre.commune != "Autre") await _loadQuartiers(_tempFiltre.province!, _tempFiltre.ville!, _tempFiltre.commune!);
  }

  Future<void> _loadVilles(String p) async {
    final list = await _locService.getVilles(p);
    if (mounted) setState(() => _villes = [...list, "Autre"]);
  }

  Future<void> _loadCommunes(String p, String v) async {
    final list = await _locService.getCommunes(p, v);
    if (mounted) setState(() => _communes = [...list, "Autre"]);
  }

  Future<void> _loadQuartiers(String p, String v, String c) async {
    final list = await _locService.getQuartiers(p, v, c);
    if (mounted) setState(() => _quartiers = [...list, "Autre"]);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _refController.dispose();
    _villeSpecCtrl.dispose();
    _communeSpecCtrl.dispose();
    _quartierSpecCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 35, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
          _buildHeader(),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(top: 15, bottom: bottomInset + 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Type de bien"),
                  _buildTypeBienDropdown(),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Rechercher par référence"),
                  _buildReferenceField(),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Localisation"),
                  
                  FutureBuilder<List<String>>(
                    future: _locService.getProvinces(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final provincesList = snapshot.data ?? [];

                      return SelecteurLocalisation(
                        afficherAvenue: false, // Désactivé pour le filtre
                        provincesDispo: provincesList,
                        provinceSaisie: _tempFiltre.province,
                        villeSaisie: _tempFiltre.ville,
                        communeSaisie: _tempFiltre.commune,
                        quartierSaisi: _tempFiltre.quartier,
                        villesDispo: _villes,
                        communesDispo: _communes,
                        quartiersDispo: _quartiers,
                        avenuesDispo: [], // Vide
                        villeSpecifiqueCtrl: _villeSpecCtrl,
                        communeSpecifiqueCtrl: _communeSpecCtrl,
                        quartierSpecifiqueCtrl: _quartierSpecCtrl,
                        onProvinceChange: (v) {
                          setState(() { _tempFiltre.province = v; _tempFiltre.ville = null; _tempFiltre.commune = null; _tempFiltre.quartier = null; });
                          if (v != null) _loadVilles(v);
                        },
                        onVilleChange: (v) {
                          setState(() { _tempFiltre.ville = v; _tempFiltre.commune = null; _tempFiltre.quartier = null; if (v != "Autre") _villeSpecCtrl.clear(); });
                          if (v != null && v != "Autre") _loadCommunes(_tempFiltre.province!, v);
                        },
                        onCommuneChange: (v) {
                          setState(() { _tempFiltre.commune = v; _tempFiltre.quartier = null; if (v != "Autre") _communeSpecCtrl.clear(); });
                          if (v != null && v != "Autre") _loadQuartiers(_tempFiltre.province!, _tempFiltre.ville!, v);
                        },
                        onQuartierChange: (v) => setState(() { _tempFiltre.quartier = v; if (v != "Autre") _quartierSpecCtrl.clear(); }),
                        onAvenueChange: (v) {}, // Inutile ici
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle("Nombre de chambres"),
                  _buildChambreSelector(),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Budget Max (USD)"),
                  _buildBudgetField(),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Équipements & Conditions"),
                  _buildEquipementGrid(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: _buildApplyButton()),
        ],
      ),
    );
  }

  Widget _buildHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text("Filtres", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      TextButton(
        onPressed: () {
          setState(() { 
            _tempFiltre.reset(); 
            _priceController.clear(); 
            _refController.clear();
            _villeSpecCtrl.clear(); _communeSpecCtrl.clear(); _quartierSpecCtrl.clear();
          });
        },
        child: const Text("Effacer tout", style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
      )
    ],
  );

  Widget _buildReferenceField() => SizedBox(
    height: 48,
    child: TextField(
      controller: _refController,
      style: const TextStyle(fontSize: 14),
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(hintText: "Ex: G2GMVL", prefixIcon: const Icon(Icons.tag, size: 20, color: Color(0xFF1E5D8F)), filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)), contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
      onChanged: (value) => _tempFiltre.queryReference = value.trim().toUpperCase(),
    ),
  );

  Widget _buildTypeBienDropdown() {
    List<String> options = ["Tous", ...PropertyTypes.all];
    return DropdownButtonFormField<String>(
      value: _tempFiltre.typeBien,
      decoration: InputDecoration(filled: true, fillColor: Colors.grey[50], prefixIcon: const Icon(Icons.home_work_outlined, color: Color(0xFF1E5D8F)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!))),
      items: options.map((type) => DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: (value) => setState(() => _tempFiltre.typeBien = value),
    );
  }

  Widget _buildChambreSelector() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [1, 2, 3, 4].map((n) {
      bool isSelected = _tempFiltre.nbChambres == n; 
      return GestureDetector(
        onTap: () => setState(() => _tempFiltre.nbChambres = isSelected ? null : n),
        child: Container(
          width: 75, padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? const Color(0xFF1E5D8F) : Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? const Color(0xFF1E5D8F) : Colors.grey[300]!)),
          child: Center(child: Text(n == 4 ? "4+" : "$n", style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14))),
        ),
      );
    }).toList(),
  );

  Widget _buildBudgetField() => SizedBox(
    height: 48,
    child: TextField(
      controller: _priceController,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(hintText: "Ex: 100", prefixIcon: const Icon(Icons.payments_outlined, size: 20, color: Color(0xFF1E5D8F)), filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)), contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
    ),
  );

  Widget _buildEquipementGrid() => Wrap(
    spacing: 8, runSpacing: 8, 
    children: [
      _buildChip("Garantie idéale (≤6 mois)", _tempFiltre.garentieIdeale, (v) => setState(() => _tempFiltre.garentieIdeale = v)),
      _buildChip("Électricité", _tempFiltre.hasElectricity, (v) => setState(() => _tempFiltre.hasElectricity = v)),
      _buildChip("Eau", _tempFiltre.hasEau, (v) => setState(() => _tempFiltre.hasEau = v)),
      _buildChip("Enclos", _tempFiltre.isEnclos, (v) => setState(() => _tempFiltre.isEnclos = v)),
      _buildChip("Salon", _tempFiltre.hasSalon, (v) => setState(() => _tempFiltre.hasSalon = v)),
      _buildChip("Cuisine", _tempFiltre.hasCuisine, (v) => setState(() => _tempFiltre.hasCuisine = v)),
      _buildChip("Toilette Parentale", _tempFiltre.hasToiletteParentale, (v) => setState(() => _tempFiltre.hasToiletteParentale = v)),
      _buildChip("Garage", _tempFiltre.hasGarage, (v) => setState(() => _tempFiltre.hasGarage = v)),
      _buildChip("Accès voiture", _tempFiltre.accessibiliteVoiture, (v) => setState(() => _tempFiltre.accessibiliteVoiture = v)),
      _buildChip("En étage", _tempFiltre.maisonEnEtage, (v) => setState(() => _tempFiltre.maisonEnEtage = v)),
      _buildChip("Peu de ménages", _tempFiltre.peuDeMenages, (v) => setState(() => _tempFiltre.peuDeMenages = v)),
      _buildChip("Bailleur absent", _tempFiltre.bailleurAbsent, (v) => setState(() => _tempFiltre.bailleurAbsent = v)),
    ],
  );

  Widget _buildSectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))));

  Widget _buildChip(String label, bool isSelected, Function(bool) onSelected) => FilterChip(
    label: Text(label), selected: isSelected, onSelected: onSelected, visualDensity: VisualDensity.compact, labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 11), selectedColor: const Color(0xFF1E5D8F), checkmarkColor: Colors.white, backgroundColor: Colors.grey[100], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), side: BorderSide.none,
  );

  Widget _buildApplyButton() => ElevatedButton(
    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFF1E5D8F), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    onPressed: () {
      _tempFiltre.maxPrice = double.tryParse(_priceController.text);
      _tempFiltre.villeSpecifique = _villeSpecCtrl.text.isNotEmpty ? _villeSpecCtrl.text : null;
      _tempFiltre.communeSpecifique = _communeSpecCtrl.text.isNotEmpty ? _communeSpecCtrl.text : null;
      _tempFiltre.quartierSpecifique = _quartierSpecCtrl.text.isNotEmpty ? _quartierSpecCtrl.text : null;
      Navigator.pop(context, _tempFiltre);
    },
    child: const Text("Afficher les résultats", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
  );
}