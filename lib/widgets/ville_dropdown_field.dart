// lib/widgets/ville_dropdown_field.dart
import 'package:flutter/material.dart';
import 'package:easylocation_mvp/services/location_service.dart';

class VilleDropdownField extends StatefulWidget {
  final String? selectedVille;
  final String? province; // Obligatoire pour utiliser le service correctement
  final Function(String?) onChanged;

  const VilleDropdownField({
    super.key,
    required this.selectedVille,
    required this.province,
    required this.onChanged,
  });

  @override
  State<VilleDropdownField> createState() => _VilleDropdownFieldState();
}

class _VilleDropdownFieldState extends State<VilleDropdownField> {
  final LocationService _locService = LocationService();
  List<String> _villesDisponibles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.province != null) _loadVilles();
  }

  @override
  void didUpdateWidget(covariant VilleDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recharge uniquement si la province change
    if (oldWidget.province != widget.province) {
      if (widget.province != null) {
        _loadVilles();
      } else {
        setState(() => _villesDisponibles = []);
      }
    }
  }

  Future<void> _loadVilles() async {
    setState(() => _isLoading = true);
    
    // Utilisation de votre méthode getVilles(provinceId)
    final villes = await _locService.getVilles(widget.province!);
    
    if (mounted) {
      setState(() {
        _villesDisponibles = villes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si aucune province n'est sélectionnée, on affiche un champ désactivé ou un message
    if (widget.province == null) {
      return const TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Veuillez d\'abord choisir une province',
          border: OutlineInputBorder(),
        ),
      );
    }

    if (_isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return DropdownButtonFormField<String>(
      // 1. Assurez-vous que la valeur est valide
      value: (_villesDisponibles.contains(widget.selectedVille)) ? widget.selectedVille : null,
      decoration: InputDecoration(
        labelText: 'Ville',
        prefixIcon: const Icon(Icons.location_city, color: Colors.blue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      // 2. Ajoutez une option "Autre" pour ne jamais être bloqué
      items: [
        ..._villesDisponibles.map((String ville) {
          return DropdownMenuItem<String>(value: ville, child: Text(ville));
        }).toList(),
        const DropdownMenuItem<String>(value: 'Autre', child: Text('Autre (Préciser)')),
      ],
      // 3. Supprimez la condition _villesDisponibles.isEmpty ici
      // On autorise toujours le onChanged pour permettre la sélection
      onChanged: widget.onChanged,
      validator: (value) => value == null ? 'Veuillez choisir une ville' : null,
    );
  }
}