// lib/widgets/active_filters_bar.dart

import 'package:flutter/material.dart';
import 'package:easylocation_mvp/models/filtre_propriete_model.dart';

class ActiveFiltersBar extends StatelessWidget {
  final FiltreProprieteModel filtre;
  final VoidCallback onFilterChanged;

  const ActiveFiltersBar({
    super.key,
    required this.filtre,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!filtre.hasActiveFilters) return const SizedBox.shrink();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Référence
          if (filtre.queryReference != null && filtre.queryReference!.isNotEmpty)
            _buildFilterChip("Réf: ${filtre.queryReference!}", () {
              filtre.queryReference = null;
              onFilterChanged();
            }),
          // Type de bien
          if (filtre.typeBien != null && filtre.typeBien != "Tous")
            _buildFilterChip(filtre.typeBien!, () {
              filtre.typeBien = null;
              onFilterChanged();
            }),
          // Province
          if (filtre.province != null && filtre.province != "Toutes")
            _buildFilterChip(filtre.province!, () {
              filtre.province = "Toutes";
              onFilterChanged();
            }),
          // Ville
          if (filtre.ville != null && filtre.ville != "Toutes")
            _buildFilterChip(
              filtre.ville == "Autre" ? filtre.villeSpecifique ?? "Ville" : filtre.ville!,
              () {
                filtre.ville = "Toutes";
                onFilterChanged();
              },
            ),
          // Commune
          if (filtre.commune != null && filtre.commune != "Toutes")
            _buildFilterChip(
              filtre.commune == "Autre" ? filtre.communeSpecifique ?? "Commune" : filtre.commune!,
              () {
                filtre.commune = "Toutes";
                onFilterChanged();
              },
            ),
          // Quartier
          if (filtre.quartier != null && filtre.quartier != "Toutes")
            _buildFilterChip(
              filtre.quartier == "Autre" ? filtre.quartierSpecifique ?? "Quartier" : filtre.quartier!,
              () {
                filtre.quartier = "Toutes";
                onFilterChanged();
              },
            ),
          // Budget Max
          if (filtre.maxPrice != null)
            _buildFilterChip("Budget Max: ${filtre.maxPrice}\$", () {
              filtre.maxPrice = null;
              onFilterChanged();
            }),
          // Chambres
          if (filtre.nbChambres != null)
            _buildFilterChip(
              "${filtre.nbChambres == 4 ? '4+' : filtre.nbChambres} Chambres",
              () {
                filtre.nbChambres = null;
                onFilterChanged();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onDeleted: onDeleted,
        deleteIconColor: Colors.blue[800],
        backgroundColor: const Color(0xFFF0F7FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}