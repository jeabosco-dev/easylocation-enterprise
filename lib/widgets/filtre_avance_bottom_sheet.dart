import 'package:flutter/material.dart';
import 'package:easylocation_mvp/models/filtre_propriete_model.dart';
import 'package:easylocation_mvp/widgets/selecteur_localisation.dart'; 
import 'package:easylocation_mvp/constants/constants.dart'; 

class FiltreAvanceBottomSheet extends StatefulWidget {
  final FiltreProprieteModel initialFiltre;
  const FiltreAvanceBottomSheet({super.key, required this.initialFiltre});

  @override
  State<FiltreAvanceBottomSheet> createState() => _FiltreAvanceBottomSheetState();
}

class _FiltreAvanceBottomSheetState extends State<FiltreAvanceBottomSheet> {
  late FiltreProprieteModel _tempFiltre;
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _refController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tempFiltre = widget.initialFiltre.copy();
    _priceController.text = _tempFiltre.maxPrice?.toString() ?? '';
    _refController.text = _tempFiltre.queryReference ?? '';
  }

  @override
  void dispose() {
    _priceController.dispose();
    _refController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9, 
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 35, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300], 
                borderRadius: BorderRadius.circular(10)
              ),
            ),
          ),
          
          _buildHeader(),
          const Divider(height: 1),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: 15,
                bottom: bottomInset + 20 
              ),
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
                  SelecteurLocalisation(
                    provinceSaisie: _tempFiltre.province,
                    villeSaisie: _tempFiltre.ville ?? "Toutes",
                    communeSaisie: _tempFiltre.commune ?? "Toutes",
                    quartierSaisi: _tempFiltre.quartier ?? "Toutes",
                    villeSpecifique: _tempFiltre.villeSpecifique,
                    communeSpecifique: _tempFiltre.communeSpecifique,
                    quartierSpecifique: _tempFiltre.quartierSpecifique,
                    
                    onProvinceChange: (v) => setState(() => _tempFiltre.province = v),
                    onVilleChange: (v) => setState(() {
                      _tempFiltre.ville = v;
                      if (v != "Autre") _tempFiltre.villeSpecifique = null;
                    }),
                    onCommuneChange: (v) => setState(() {
                      _tempFiltre.commune = v;
                      if (v != "Autre") _tempFiltre.communeSpecifique = null;
                    }),
                    onQuartierChange: (v) => setState(() {
                      _tempFiltre.quartier = v;
                      if (v != "Autre") _tempFiltre.quartierSpecifique = null;
                    }),
                    onVilleSpecifiqueChange: (v) => setState(() => _tempFiltre.villeSpecifique = v),
                    onCommuneSpecifiqueChange: (v) => setState(() => _tempFiltre.communeSpecifique = v),
                    onQuartierSpecifiqueChange: (v) => setState(() => _tempFiltre.quartierSpecifique = v),
                    
                    onAvenueChange: (v) => setState(() => _tempFiltre.avenue = v),
                    onAvenueSpecifiqueChange: (v) => setState(() => _tempFiltre.avenueSpecifique = v),
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

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: _buildApplyButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _refController,
        style: const TextStyle(fontSize: 14),
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          hintText: "Ex: G2GMVL",
          prefixIcon: const Icon(Icons.tag, size: 20, color: Color(0xFF1E5D8F)),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onChanged: (value) {
          _tempFiltre.queryReference = value.trim().toUpperCase();
        },
      ),
    );
  }

  Widget _buildTypeBienDropdown() {
    // ✅ Création d'une liste incluant "Tous" pour le dropdown
    List<String> options = ["Tous", ...PropertyTypes.all];

    return DropdownButtonFormField<String>(
      value: _tempFiltre.typeBien, // Utilise la valeur du modèle ("Tous" par défaut)
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[50],
        prefixIcon: const Icon(Icons.home_work_outlined, color: Color(0xFF1E5D8F)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
      ),
      items: options.map((type) => DropdownMenuItem(
        value: type,
        child: Text(type, style: const TextStyle(fontSize: 14)),
      )).toList(),
      onChanged: (value) => setState(() => _tempFiltre.typeBien = value),
    );
  }

  Widget _buildChambreSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [1, 2, 3, 4].map((n) {
        bool isSelected = _tempFiltre.nbChambres == n; 
        return GestureDetector(
          onTap: () => setState(() => _tempFiltre.nbChambres = isSelected ? null : n),
          child: Container(
            width: 75,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E5D8F) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? const Color(0xFF1E5D8F) : Colors.grey[300]!),
            ),
            child: Center(
              child: Text(
                n == 4 ? "4+" : "$n",
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBudgetField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _priceController,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: "Ex: 100",
          prefixIcon: const Icon(Icons.payments_outlined, size: 20, color: Color(0xFF1E5D8F)),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildEquipementGrid() {
    return Wrap(
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
          });
        },
        child: const Text("Effacer tout", style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
      )
    ],
  );

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
  );

  Widget _buildChip(String label, bool isSelected, Function(bool) onSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 11),
      selectedColor: const Color(0xFF1E5D8F),
      checkmarkColor: Colors.white,
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    );
  }

  Widget _buildApplyButton() => ElevatedButton(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 50),
      backgroundColor: const Color(0xFF1E5D8F),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: () {
      _tempFiltre.maxPrice = double.tryParse(_priceController.text);
      Navigator.pop(context, _tempFiltre);
    },
    child: const Text("Afficher les résultats", 
      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
  );
}