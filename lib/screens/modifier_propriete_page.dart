// lib/screens/modifier_propriete_page.dart

import 'package:flutter/material.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/screens/formulaire_de_mise_en_publication_page.dart';

class ModifierProprietePage extends StatelessWidget {
  final Property property;

  const ModifierProprietePage({
    super.key,
    required this.property,
  });

  @override
  Widget build(BuildContext context) {
    // On extrait la référence courte pour le titre
    final String idPrefix = property.id.length >= 6 
        ? property.id.substring(0, 6).toUpperCase() 
        : property.id.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modifier Réf: $idPrefix', 
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      // C'est ici que l'objet est passé. 
      // Il faut maintenant s'assurer que FormulaireDeMiseEnPublicationPage l'utilise !
      body: FormulaireDeMiseEnPublicationPage(
        propertyToEdit: property,
      ),
    );
  }
}
