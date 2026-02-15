// lib/widgets/selecteur_localisation.dart

import 'package:flutter/material.dart';
import '../donnees/localisation_donnees.dart';

class SelecteurLocalisation extends StatelessWidget {
  final String? provinceSaisie;
  final String? villeSaisie;
  final String? communeSaisie;
  final String? quartierSaisi;
  final String? avenueSaisie;
  
  final String? villeSpecifique;
  final String? communeSpecifique;
  final String? quartierSpecifique;
  final String? avenueSpecifique;

  final Function(String?) onProvinceChange;
  final Function(String?) onVilleChange;
  final Function(String?) onCommuneChange;
  final Function(String?) onQuartierChange;
  final Function(String?) onAvenueChange;
  
  final Function(String?) onVilleSpecifiqueChange;
  final Function(String?) onCommuneSpecifiqueChange;
  final Function(String?) onQuartierSpecifiqueChange;
  final Function(String?) onAvenueSpecifiqueChange;

  const SelecteurLocalisation({
    super.key,
    this.provinceSaisie,
    this.villeSaisie,
    this.communeSaisie,
    this.quartierSaisi,
    this.avenueSaisie,
    this.villeSpecifique,
    this.communeSpecifique,
    this.quartierSpecifique,
    this.avenueSpecifique,
    required this.onProvinceChange,
    required this.onVilleChange,
    required this.onCommuneChange,
    required this.onQuartierChange,
    required this.onAvenueChange,
    required this.onVilleSpecifiqueChange,
    required this.onCommuneSpecifiqueChange,
    required this.onQuartierSpecifiqueChange,
    required this.onAvenueSpecifiqueChange,
  });

  @override
  Widget build(BuildContext context) {
    final provinceData = provincesCongo.firstWhere(
      (p) => p.nom == provinceSaisie,
      orElse: () => provincesCongo.first,
    );

    List<String> villesVisibles = provinceData.villes.keys.toList();
    
    Map<String, Map<String, List<String>>> communesVisibles = 
        (villeSaisie != null && villeSaisie != "Autre") ? provinceData.villes[villeSaisie] ?? {} : {};
    
    Map<String, List<String>> quartiersVisibles = 
        (communeSaisie != null && communeSaisie != "Autre") ? communesVisibles[communeSaisie] ?? {} : {};
    
    List<String> avenuesVisibles = 
        (quartierSaisi != null && quartierSaisi != "Autre") ? quartiersVisibles[quartierSaisi] ?? [] : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMenu("Province *", provinceSaisie, provincesCongo.map((p) => p.nom).toList(), onProvinceChange),
        const SizedBox(height: 16),

        _buildMenu("Ville *", villeSaisie, villesVisibles, onVilleChange),
        if (villeSaisie == "Autre") ...[
          const SizedBox(height: 12),
          _buildManualField("Précisez la ville *", villeSpecifique, onVilleSpecifiqueChange),
        ],
        const SizedBox(height: 16),

        if (villeSaisie != null) ...[
          if (villeSaisie == "Autre")
            _buildManualField("Commune *", communeSpecifique, onCommuneSpecifiqueChange)
          else
            _buildMenu("Commune *", communeSaisie, communesVisibles.keys.toList(), onCommuneChange),
          
          if (communeSaisie == "Autre" && villeSaisie != "Autre")
            _buildManualField("Précisez la commune *", communeSpecifique, onCommuneSpecifiqueChange),
          const SizedBox(height: 16),
        ],

        if (communeSaisie != null || (villeSaisie == "Autre" && communeSpecifique != null)) ...[
          if (communeSaisie == "Autre" || villeSaisie == "Autre")
            _buildManualField("Quartier *", quartierSpecifique, onQuartierSpecifiqueChange)
          else
            _buildMenu("Quartier *", quartierSaisi, quartiersVisibles.keys.toList(), onQuartierChange),

          if (quartierSaisi == "Autre" && communeSaisie != "Autre" && villeSaisie != "Autre")
            _buildManualField("Précisez le quartier *", quartierSpecifique, onQuartierSpecifiqueChange),
          const SizedBox(height: 16),
        ],

        if (quartierSaisi != null || quartierSpecifique != null) ...[
          if (quartierSaisi == "Autre" || communeSaisie == "Autre" || villeSaisie == "Autre")
            _buildManualField("Avenue *", avenueSpecifique, onAvenueSpecifiqueChange)
          else
            _buildMenu("Avenue *", avenueSaisie, avenuesVisibles, onAvenueChange),

          if (avenueSaisie == "Autre" && quartierSaisi != "Autre" && communeSaisie != "Autre")
            _buildManualField("Précisez l'avenue *", avenueSpecifique, onAvenueSpecifiqueChange),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildMenu(String etiquette, String? valeur, List<String> choix, Function(String?) auChangement) {
    if (choix.isNotEmpty && !choix.contains("Autre")) {
      choix.add("Autre");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiquette, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: choix.contains(valeur) ? valeur : null,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: choix.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: auChangement,
          validator: (v) => v == null ? 'Obligatoire' : null,
        ),
      ],
    );
  }

  Widget _buildManualField(String label, String? valeur, Function(String?) auChangement) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Le titre est maintenant EN DEHORS de la bordure
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: valeur,
          decoration: InputDecoration(
            hintText: "Saisissez le nom ici",
            prefixIcon: const Icon(Icons.edit_location_alt, color: Colors.blue, size: 20),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            filled: true,
            fillColor: Colors.blue[50]?.withOpacity(0.3),
          ),
          onChanged: auChangement,
          validator: (v) => (v == null || v.isEmpty) ? 'Veuillez préciser' : null,
        ),
      ],
    );
  }
}
