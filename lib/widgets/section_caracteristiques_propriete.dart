// lib/widgets/section_caracteristiques_propriete.dart

import 'package:flutter/material.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:intl/intl.dart';
import '../../constants/constants.dart';

class SectionCaracteristiquesPropriete extends StatelessWidget {
  final Property property;

  const SectionCaracteristiquesPropriete({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    String dateLibre = "Date non spécifiée";
    if (property.dateDisponibilite != null) {
      dateLibre = DateFormat('d MMMM yyyy', 'fr').format(property.dateDisponibilite!);
    }

    final String type = property.typeBien ?? PropertyTypes.maison;
    final bool isTerrain = type == PropertyTypes.terrain;
    final bool isEntrepot = type == PropertyTypes.entrepot;
    final bool isPro = type == PropertyTypes.bureau || type == PropertyTypes.commercial;
    final bool isStudio = type == PropertyTypes.studio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Détails de la propriété",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // --- BLOC 1 : COMPOSITION ---
        _buildCategoryTitle("Composition du bien"),
        
        // ✅ AJOUT : AFFICHAGE CLAIR DU TYPE DE BIEN
        _buildFeatureRow(
          icon: Icons.category_outlined, 
          text: "Type de bien : ${type.toUpperCase()}",
          customIconColor: Colors.blueAccent,
        ),

        if (!isTerrain) ...[
          // Niveau / Étage
          _buildFeatureRow(
            icon: property.maisonEnEtage ? Icons.layers : Icons.foundation, 
            text: property.maisonEnEtage 
                ? "Niveau : ${property.niveauText}" 
                : property.niveauText,
          ),

          // Salon et Chambres
          if (!isEntrepot && !isStudio) ...[
            _buildFeatureRow(icon: Icons.weekend, text: "Salon", isAvailable: property.hasSalon),
            
            (() {
              int n = property.nombreChambres;
              if (isPro) {
                String label = n > 1 ? 'pièces de travail' : 'pièce de travail';
                return _buildFeatureRow(icon: Icons.work, text: "$n $label");
              } else {
                String label = n > 1 ? 'chambres' : 'chambre';
                return _buildFeatureRow(icon: Icons.bed, text: "$n $label");
              }
            })(),
          ],

          if (isStudio) _buildFeatureRow(icon: Icons.auto_awesome_mosaic, text: "Espace unique optimisé"),
          
          _buildFeatureRow(icon: Icons.kitchen, text: "Cuisine", isAvailable: property.hasCuisine && !isPro),
          _buildFeatureRow(icon: Icons.wc, text: "Toilette Parentale", isAvailable: property.hasToiletteParentale),
          
          // On garde cette ligne car typeMaison peut préciser (ex: Type de bien: Maison, Type: Villa)
          if (property.typeMaison != null)
            _buildFeatureRow(icon: Icons.home, text: "Catégorie: ${property.typeMaison}"),
          
          const Divider(height: 30),
        ],

        // --- BLOC 2 : COMMODITÉS ET RÈGLES ---
        _buildCategoryTitle("Commodités & Conditions"),
        _buildFeatureRow(icon: Icons.money, text: "Garantie Idéale: ${property.garantieIdeale} mois"),
        _buildFeatureRow(icon: Icons.money_off, text: "Garantie Minimale: ${property.garantieMinimale} mois"),
        
        (() {
          final now = DateTime.now();
          bool estDejaPassee = property.dateDisponibilite != null && property.dateDisponibilite!.isBefore(now);
          
          if (property.disponibiliteImmediate || estDejaPassee) {
            return _buildFeatureRow(
              icon: Icons.calendar_today, 
              text: "Disponible immédiatement",
              customIconColor: Colors.green,
              showCheck: true,
            );
          } else {
            return _buildFeatureRow(
              icon: Icons.event_busy, 
              text: "Libre le : $dateLibre", 
              customIconColor: Colors.orange 
            );
          }
        })(),
        
        if (!isTerrain) ...[
          _buildFeatureRow(icon: Icons.pets, text: "Possibilité d'animaux", isAvailable: property.possibiliteAnimaux, showCheck: true),
          _buildFeatureRow(icon: Icons.person_pin, text: "Bailleur habite sur place", isAvailable: property.bailleurHabiteAvec),
          _buildFeatureRow(icon: Icons.verified, text: "Bailleur réactif", isAvailable: property.estReactif, showCheck: true),
        ],

        const Divider(height: 30),

        // --- BLOC 3 : ÉNERGIE & INFRASTRUCTURE ---
        _buildCategoryTitle("Services & Infrastructure"),
        _buildFeatureRow(icon: Icons.water_drop, text: "Eau disponible", isAvailable: property.hasEau, showCheck: true),
        if (property.hasEau)
          _buildFeatureRow(icon: Icons.water_damage, text: "Compteur d'eau individuel", isAvailable: property.compteurEau, showCheck: true),
        
        // ✅ CORRECTION LOGIQUE : On affiche l'électricité si ce n'est pas "Pas d’électricité" ou vide
        if (property.electricite.isNotEmpty && property.electricite != 'Pas d’électricité' && property.electricite != 'aucune')
          _buildFeatureRow(icon: Icons.electric_bolt, text: "Source Électricité: ${property.electricite}"),
        
        if (!isTerrain)
          _buildFeatureRow(icon: Icons.grid_on, text: "Type de sol: ${property.selectedTypeSol ?? 'Non spécifié'}"),
        
        const Divider(height: 30),

        // --- BLOC 4 : EXTÉRIEUR ET ACCÈS ---
        _buildCategoryTitle("Extérieur & Environnement"),
        _buildFeatureRow(icon: Icons.fence, text: "Maison en enclos", isAvailable: property.maisonEnclos, showCheck: true),
        
        if (!isTerrain)
          _buildFeatureRow(icon: Icons.group, text: "Nombre de ménages: ${property.nombreMenages ?? '1'}"),
        
        _buildFeatureRow(icon: Icons.drive_eta, text: "Accessibilité voiture", isAvailable: property.accessibiliteVoiture, showCheck: true),
        _buildFeatureRow(icon: Icons.garage, text: "Garage disponible", isAvailable: property.hasGarage, showCheck: true),
        _buildFeatureRow(icon: Icons.deck, text: "Cour / Espace de Récréation", isAvailable: property.hasCourRecreation, showCheck: true),
        _buildFeatureRow(icon: Icons.store, text: "Espace de stockage (Dépôt)", isAvailable: property.hasDepot, showCheck: true),
        
        const SizedBox(height: 20),
      ],
    );
  }

  // --- WIDGETS DE CONSTRUCTION ---

  Widget _buildCategoryTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple.withOpacity(0.8),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String text,
    bool? isAvailable,
    Color? customIconColor,
    bool showCheck = false,
  }) {
    if (isAvailable == false) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (customIconColor ?? Colors.deepPurple).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: customIconColor ?? Colors.deepPurple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
          if (showCheck)
            const Icon(
              Icons.check_circle_outline,
              size: 16,
              color: Colors.green,
            ),
        ],
      ),
    );
  }
}