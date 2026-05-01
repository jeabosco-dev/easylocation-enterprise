// lib/widgets/ville_dropdown_field.dart
import 'package:flutter/material.dart';
import 'package:easylocation_mvp/donnees/localisation_donnees.dart';

class VilleDropdownField extends StatelessWidget {
  final String? selectedVille;
  final Function(String?) onChanged;

  const VilleDropdownField({
    super.key,
    required this.selectedVille,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // On récupère la liste via la fonction utilitaire de ton fichier de données
    final List<String> villesDisponibles = getAllVilles();

    return DropdownButtonFormField<String>(
      value: selectedVille,
      decoration: InputDecoration(
        labelText: 'Votre ville actuelle',
        prefixIcon: const Icon(Icons.location_city, color: Colors.blue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: villesDisponibles.map((String ville) {
        return DropdownMenuItem<String>(
          value: ville,
          child: Text(ville),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Veuillez choisir une ville' : null,
    );
  }
}