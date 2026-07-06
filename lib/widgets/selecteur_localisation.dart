// lib/widgets/selecteur_localisation.dart

import 'package:flutter/material.dart';

class SelecteurLocalisation extends StatelessWidget {
  // Paramètre de configuration
  final bool afficherAvenue;

  // Valeurs sélectionnées
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

  // Callbacks pour les sélections (Dropdown)
  final ValueChanged<String?> onProvinceChange;
  final ValueChanged<String?> onVilleChange;
  final ValueChanged<String?> onCommuneChange;
  final ValueChanged<String?> onQuartierChange;
  final ValueChanged<String?> onAvenueChange;

  // Callbacks optionnels pour la saisie manuelle
  final ValueChanged<String>? onProvinceManualChange;
  final ValueChanged<String>? onVilleManualChange;
  final ValueChanged<String>? onCommuneManualChange;
  final ValueChanged<String>? onQuartierManualChange;
  final ValueChanged<String>? onAvenueManualChange;

  const SelecteurLocalisation({
    super.key,
    this.afficherAvenue = true,
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
    this.onProvinceManualChange,
    this.onVilleManualChange,
    this.onCommuneManualChange,
    this.onQuartierManualChange,
    this.onAvenueManualChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Province
        _buildMenu("Province", provinceSaisie, provincesDispo, onProvinceChange),
        if (provinceSaisie == "Autre")
          _buildManualField("Précisez la province", provinceSpecifiqueCtrl, onProvinceManualChange),

        // Ville
        if (provinceSaisie != null) ...[
          const SizedBox(height: 16),
          _buildMenu("Ville", villeSaisie, villesDispo, onVilleChange),
          if (villeSaisie == "Autre")
            _buildManualField("Précisez la ville", villeSpecifiqueCtrl, onVilleManualChange),
        ],

        // Commune
        if (villeSaisie != null && villeSaisie != "Autre") ...[
          const SizedBox(height: 16),
          _buildMenu("Commune", communeSaisie, communesDispo, onCommuneChange),
          if (communeSaisie == "Autre")
            _buildManualField("Précisez la commune", communeSpecifiqueCtrl, onCommuneManualChange),
        ],

        // Quartier
        if (communeSaisie != null && communeSaisie != "Autre") ...[
          const SizedBox(height: 16),
          _buildMenu("Quartier", quartierSaisi, quartiersDispo, onQuartierChange),
          if (quartierSaisi == "Autre")
            _buildManualField("Précisez le quartier", quartierSpecifiqueCtrl, onQuartierManualChange),
        ],

        // Avenue (Conditionnelle selon le paramètre afficherAvenue)
        if (afficherAvenue && quartierSaisi != null && quartierSaisi != "Autre") ...[
          const SizedBox(height: 16),
          _buildMenu("Avenue", avenueSaisie, avenuesDispo, onAvenueChange),
          if (avenueSaisie == "Autre")
            _buildManualField("Précisez l'avenue", avenueSpecifiqueCtrl, onAvenueManualChange),
        ],
      ],
    );
  }

  Widget _buildMenu(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
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
      value: uniqueItems.contains(value) ? value : (value != null ? "Autre" : null),
      items: uniqueItems.map((i) => DropdownMenuItem(
        value: i, 
        child: Text(i, style: const TextStyle(fontSize: 14))
      )).toList(),
      onChanged: onChanged,
      validator: (v) => (value == "Autre" && (v == null || v.isEmpty)) ? "Veuillez préciser $label" : null,
    );
  }

  Widget _buildManualField(String label, TextEditingController? controller, ValueChanged<String>? onManualChange) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: TextFormField(
        controller: controller,
        onChanged: (val) => onManualChange?.call(val),
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