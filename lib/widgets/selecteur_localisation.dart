// lib/widgets/selecteur_localisation.dart

import 'package:flutter/material.dart';

class SelecteurLocalisation extends StatelessWidget {
  final String? provinceSaisie;
  final String? villeSaisie;
  final String? communeSaisie;
  final String? quartierSaisi;
  final String? avenueSaisie;

  // Listes injectées
  final List<String> provincesDispo;
  final List<String> villesDispo;
  final List<String> communesDispo;
  final List<String> quartiersDispo;
  final List<String> avenuesDispo;

  // Contrôleurs pour la saisie manuelle
  final TextEditingController? provinceSpecifiqueCtrl;
  final TextEditingController? villeSpecifiqueCtrl;
  final TextEditingController? communeSpecifiqueCtrl;
  final TextEditingController? quartierSpecifiqueCtrl;
  final TextEditingController? avenueSpecifiqueCtrl;

  // Callbacks
  final Function(String?) onProvinceChange;
  final Function(String?) onVilleChange;
  final Function(String?) onCommuneChange;
  final Function(String?) onQuartierChange;
  final Function(String?) onAvenueChange;

  const SelecteurLocalisation({
    super.key,
    this.provinceSaisie,
    this.villeSaisie,
    this.communeSaisie,
    this.quartierSaisi,
    this.avenueSaisie,
    required this.provincesDispo,
    required this.villesDispo,
    required this.communesDispo,
    required this.quartiersDispo,
    required this.avenuesDispo,
    this.provinceSpecifiqueCtrl,
    this.villeSpecifiqueCtrl,
    this.communeSpecifiqueCtrl,
    this.quartierSpecifiqueCtrl,
    this.avenueSpecifiqueCtrl,
    required this.onProvinceChange,
    required this.onVilleChange,
    required this.onCommuneChange,
    required this.onQuartierChange,
    required this.onAvenueChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Province
        _buildMenu("Province", provinceSaisie, provincesDispo, onProvinceChange, provinceSpecifiqueCtrl),
        if (provinceSaisie == "Autre") _buildManualField("Précisez la province", provinceSpecifiqueCtrl),

        // Ville
        if (provinceSaisie != null) ...[
          const SizedBox(height: 16),
          _buildMenu("Ville", villeSaisie, villesDispo, onVilleChange, villeSpecifiqueCtrl),
          if (villeSaisie == "Autre") _buildManualField("Précisez la ville", villeSpecifiqueCtrl),
        ],

        // Commune
        if (villeSaisie != null && villeSaisie != "Autre") ...[
          const SizedBox(height: 16),
          _buildMenu("Commune", communeSaisie, communesDispo, onCommuneChange, communeSpecifiqueCtrl),
          if (communeSaisie == "Autre") _buildManualField("Précisez la commune", communeSpecifiqueCtrl),
        ],

        // Quartier
        if (communeSaisie != null && communeSaisie != "Autre") ...[
          const SizedBox(height: 16),
          _buildMenu("Quartier", quartierSaisi, quartiersDispo, onQuartierChange, quartierSpecifiqueCtrl),
          if (quartierSaisi == "Autre") _buildManualField("Précisez le quartier", quartierSpecifiqueCtrl),
        ],

        // Avenue
        if (quartierSaisi != null && quartierSaisi != "Autre") ...[
          const SizedBox(height: 16),
          _buildMenu("Avenue", avenueSaisie, avenuesDispo, onAvenueChange, avenueSpecifiqueCtrl),
          if (avenueSaisie == "Autre") _buildManualField("Précisez l'avenue", avenueSpecifiqueCtrl),
        ],
      ],
    );
  }

  Widget _buildMenu(String label, String? value, List<String> items, Function(String?) onChanged, TextEditingController? ctrl) {
    // ✅ CORRECTION : On s'assure d'avoir une liste unique sans doublon de "Autre"
    final uniqueItems = items.toSet().toList();
    if (!uniqueItems.contains("Autre")) {
      uniqueItems.add("Autre");
    }

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: "$label *",
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
      ),
      // Si la valeur est dans la liste, on l'affiche, sinon on affiche "Autre" si la valeur n'est pas nulle
      value: uniqueItems.contains(value) ? value : (value != null ? "Autre" : null),
      items: uniqueItems.map((i) => DropdownMenuItem(
        value: i, 
        child: Text(i, style: const TextStyle(fontSize: 14))
      )).toList(),
      onChanged: (val) {
        if (val != "Autre") ctrl?.clear();
        onChanged(val);
      },
      validator: (v) => (value == "Autre" && (ctrl?.text.isEmpty ?? true)) ? "Veuillez préciser $label" : null,
    );
  }

  Widget _buildManualField(String label, TextEditingController? controller) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
        ),
        validator: (v) => (v == null || v.isEmpty) ? "Champ obligatoire" : null,
      ),
    );
  }
}