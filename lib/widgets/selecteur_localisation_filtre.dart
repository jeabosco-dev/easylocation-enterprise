// lib/widgets/selecteur_localisation.dart

import 'package:flutter/material.dart';
import '../donnees/localisation_donnees.dart';

class SelecteurLocalisation extends StatelessWidget {
  final String? provinceSaisie;
  final String? villeSaisie;
  final String? communeSaisie;
  final String? quartierSaisi;
  
  final String? villeSpecifique;
  final String? communeSpecifique;
  final String? quartierSpecifique;

  // Ajout des contrôleurs pour la gestion du texte
  final TextEditingController? villeSpecifiqueCtrl;
  final TextEditingController? communeSpecifiqueCtrl;
  final TextEditingController? quartierSpecifiqueCtrl;

  final Function(String?) onProvinceChange;
  final Function(String?) onVilleChange;
  final Function(String?) onCommuneChange;
  final Function(String?) onQuartierChange;
  
  final Function(String?) onVilleSpecifiqueChange;
  final Function(String?) onCommuneSpecifiqueChange;
  final Function(String?) onQuartierSpecifiqueChange;

  const SelecteurLocalisation({
    super.key,
    this.provinceSaisie,
    this.villeSaisie,
    this.communeSaisie,
    this.quartierSaisi,
    this.villeSpecifique,
    this.communeSpecifique,
    this.quartierSpecifique,
    // Contrôleurs optionnels
    this.villeSpecifiqueCtrl,
    this.communeSpecifiqueCtrl,
    this.quartierSpecifiqueCtrl,
    required this.onProvinceChange,
    required this.onVilleChange,
    required this.onCommuneChange,
    required this.onQuartierChange,
    required this.onVilleSpecifiqueChange,
    required this.onCommuneSpecifiqueChange,
    required this.onQuartierSpecifiqueChange,
    // Paramètres requis par la structure existante
    required void Function(String?) onAvenueChange, 
    required void Function(String?) onAvenueSpecifiqueChange,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Trouver les données de la province sélectionnée
    final provinceData = provincesCongo.firstWhere(
      (p) => p.nom == provinceSaisie,
      orElse: () => provincesCongo.first,
    );

    // 2. Préparation dynamique des listes avec "Toutes" forcé au début
    List<String> villesVisibles = ["Toutes", ...provinceData.villes.keys];
    List<String> communesList = ["Toutes"];
    List<String> quartiersList = ["Toutes"];

    // Remplissage logique des listes descendantes
    if (villeSaisie != "Toutes" && villeSaisie != "Autre" && villeSaisie != null) {
      final villeMap = provinceData.villes[villeSaisie];
      if (villeMap != null) {
        communesList.addAll(villeMap.keys);
        
        if (communeSaisie != "Toutes" && communeSaisie != "Autre" && communeSaisie != null) {
          final dynamic communeData = villeMap[communeSaisie];
          if (communeData is Map) {
            quartiersList.addAll(communeData.keys.cast<String>());
          } else if (communeData is List) {
            quartiersList.addAll(communeData.cast<String>());
          }
        }
      }
    }

    if (!villesVisibles.contains("Autre")) villesVisibles.add("Autre");
    if (!communesList.contains("Autre")) communesList.add("Autre");
    if (!quartiersList.contains("Autre")) quartiersList.add("Autre");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- PROVINCE ---
        _buildMenu("Province", provinceSaisie ?? "Sud-Kivu", provincesCongo.map((p) => p.nom).toList(), (val) {
          onProvinceChange(val);
          onVilleChange("Toutes"); 
          onCommuneChange("Toutes");
          onQuartierChange("Toutes");
          // On vide les contrôleurs lors d'un changement majeur
          villeSpecifiqueCtrl?.clear();
          communeSpecifiqueCtrl?.clear();
          quartierSpecifiqueCtrl?.clear();
        }),
        const SizedBox(height: 12),

        // --- VILLE ---
        _buildMenu("Ville", villeSaisie ?? "Toutes", villesVisibles, (val) {
          onVilleChange(val);
          onCommuneChange("Toutes");
          onQuartierChange("Toutes");
          if (val != "Autre") villeSpecifiqueCtrl?.clear();
          communeSpecifiqueCtrl?.clear();
          quartierSpecifiqueCtrl?.clear();
        }),
        
        if (villeSaisie == "Autre") ...[
          const SizedBox(height: 8),
          _buildManualField("Précisez la ville", villeSpecifiqueCtrl, onVilleSpecifiqueChange),
        ],

        // --- COMMUNE ---
        const SizedBox(height: 12),
        if (villeSaisie == "Autre")
          _buildManualField("Commune", communeSpecifiqueCtrl, onCommuneSpecifiqueChange)
        else
          _buildMenu("Commune", communeSaisie ?? "Toutes", communesList, (val) {
            onCommuneChange(val);
            onQuartierChange("Toutes");
            if (val != "Autre") communeSpecifiqueCtrl?.clear();
            quartierSpecifiqueCtrl?.clear();
          }),
        
        if (communeSaisie == "Autre" && villeSaisie != "Autre") ...[
          const SizedBox(height: 8),
          _buildManualField("Précisez la commune", communeSpecifiqueCtrl, onCommuneSpecifiqueChange),
        ],

        // --- QUARTIER ---
        const SizedBox(height: 12),
        if (communeSaisie == "Autre" || villeSaisie == "Autre")
          _buildManualField("Quartier", quartierSpecifiqueCtrl, onQuartierSpecifiqueChange)
        else
          _buildMenu("Quartier", quartierSaisi ?? "Toutes", quartiersList, (val) {
            onQuartierChange(val);
            if (val != "Autre") quartierSpecifiqueCtrl?.clear();
          }),

        if (quartierSaisi == "Autre" && communeSaisie != "Autre" && villeSaisie != "Autre") ...[
          const SizedBox(height: 8),
          _buildManualField("Précisez le quartier", quartierSpecifiqueCtrl, onQuartierSpecifiqueChange),
        ],
      ],
    );
  }

  Widget _buildMenu(String etiquette, String valeurAffichee, List<String> choix, Function(String?) auChangement) {
    String valeurFinale = choix.contains(valeurAffichee) ? valeurAffichee : "Toutes";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiquette, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          child: DropdownButtonFormField<String>(
            value: valeurFinale,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
            ),
            items: choix.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: auChangement,
          ),
        ),
      ],
    );
  }

  Widget _buildManualField(String label, TextEditingController? controller, Function(String?) auChangement) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E5D8F))),
        const SizedBox(height: 4),
        SizedBox(
          height: 45,
          child: TextFormField(
            controller: controller, // ✅ Utilisation du controller
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: "Saisir manuellement...",
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.blue[50]?.withOpacity(0.3),
            ),
            onChanged: auChangement,
          ),
        ),
      ],
    );
  }
}