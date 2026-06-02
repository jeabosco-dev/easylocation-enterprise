// lib/widgets/section_description_dynamique.dart

import 'package:flutter/material.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:intl/intl.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

class SectionDescriptionDynamique extends StatelessWidget {
  final Property property;

  const SectionDescriptionDynamique({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "À propos de ce bien",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        Text(
          _genererDescriptionAutomatique(),
          softWrap: true, // Évite les débordements horizontaux
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: Colors.black87,
          ),
        ),
        
        if (property.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Divider(thickness: 0.5),
          Text(
            property.description,
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.grey[700],
            ),
          ),
        ],
      ],
    );
  }

  String _genererDescriptionAutomatique() {
    List<String> phrases = [];
    final String type = property.typeBien ?? ''; 
    
    final bool isTerrain = type == PropertyTypes.terrain;
    final bool isStudio = type == PropertyTypes.studio;
    final bool isEntrepot = type == PropertyTypes.entrepot;
    final bool isPro = type == PropertyTypes.bureau || type == PropertyTypes.commercial;
    final bool isLogementClassique = type == PropertyTypes.maison || type == PropertyTypes.appartement;

    // --- LOGIQUE DE GENRE (Masculin / Féminin) ---
    String determinat; // "Ce" ou "Cette"
    String nomAffiche;

    switch (type) {
      case PropertyTypes.maison:
        determinat = "Cette";
        nomAffiche = "maison";
        break;
      case PropertyTypes.appartement:
        determinat = "Cet"; // "Cet" devant voyelle
        nomAffiche = "appartement";
        break;
      case PropertyTypes.studio:
        determinat = "Ce";
        nomAffiche = "studio";
        break;
      case PropertyTypes.entrepot:
        determinat = "Cet";
        nomAffiche = "entrepôt";
        break;
      case PropertyTypes.bureau:
        determinat = "Ce";
        nomAffiche = "bureau";
        break;
      case PropertyTypes.commercial:
        determinat = "Ce";
        nomAffiche = "local commercial";
        break;
      default:
        determinat = "Ce";
        nomAffiche = "bien";
    }

    // --- 1. INTRODUCTION & TYPE DE CONSTRUCTION ---
    if (isTerrain) {
      phrases.add("Il s'agit d'un terrain nu, idéalement situé pour vos projets.");
    } else if (isEntrepot) {
      phrases.add("Il s'agit d'un espace de stockage de type entrepôt/dépôt.");
    } else {
      if (property.maisonEnEtage == false) {
        phrases.add("$determinat $nomAffiche est une construction de plain-pied située au niveau du sol.");
      } else {
        if (property.niveauEtage == 99) {
          phrases.add("$determinat $nomAffiche est aménagé sous les combles (grenier).");
        } else if (property.niveauEtage == 0 || property.niveauEtage == null) {
          phrases.add("$determinat $nomAffiche est situé au rez-de-chaussée d'un bâtiment en étage.");
        } else {
          String etage = property.niveauEtage == 1 ? "1er" : "${property.niveauEtage}ème";
          phrases.add("$determinat $nomAffiche se situe au $etage étage.");
        }
      }
    }

    // --- 2. COMPOSITION DE L'ESPACE ---
    if (isTerrain) {
    } else if (isStudio) {
      phrases.add("Ce studio est conçu comme une pièce unique optimisée, incluant l'espace de vie et de nuit.");
    } else if (isEntrepot) {
      phrases.add("L'espace offre une grande surface dégagée pour le stockage ou l'activité industrielle.");
    } else if (isPro) {
      String motPiece = property.nombreChambres > 1 ? 'pièces' : 'pièce';
      phrases.add("L'espace professionnel dispose de ${property.nombreChambres} $motPiece de travail.");
    } else if (isLogementClassique) {
      String motChambre = property.nombreChambres > 1 ? 'chambres' : 'chambre';
      String compo = "Le logement comprend ${property.nombreChambres} $motChambre";
      if (property.hasSalon) compo += " et un salon spacieux";
      phrases.add("$compo.");
    }

    // --- 3. FINITIONS & SOL ---
    if (!isTerrain && !isEntrepot && property.selectedTypeSol != null && property.selectedTypeSol != 'autre' && property.selectedTypeSol!.isNotEmpty) {
      String typeSol = property.selectedTypeSol!.contains('carrelé') ? "carreaux" : "ciment propre";
      phrases.add("Le revêtement du sol est en $typeSol.");
    }

    // --- 4. COMMODITÉS INTERNES ---
    List<String> commodites = [];
    if (property.hasToiletteParentale) commodites.add("une toilette interne");
    if (property.hasCuisine && isLogementClassique) commodites.add("une cuisine");
    if (property.hasDepot) commodites.add("un petit dépôt");

    if (commodites.isNotEmpty && !isTerrain) {
      phrases.add("À l'intérieur, vous trouverez : ${commodites.join(', ')}.");
    }

    // --- 5. ÉNERGIE & EAU ---
    if (property.electricite.isNotEmpty && property.electricite != 'Pas d’électricité' && property.electricite != 'aucune') {
      String modeElec = property.electricite.toLowerCase().contains('cash-power') 
          ? "via un compteur Cash-power individuel" 
          : "via un compteur commun";
      phrases.add("L'électricité est installée $modeElec.");
    }

    if (property.hasEau) {
      phrases.add("L'accès à l'eau est garanti ${property.compteurEau ? 'directement à l\'intérieur' : 'dans la parcelle'}.");
    }

    // --- 6. EXTÉRIEUR & ACCÈS ---
    List<String> ext = [];
    if (property.hasGarage) ext.add("un garage");
    if (property.hasCourRecreation) ext.add("une cour");
    if (property.maisonEnclos) ext.add("un enclos sécurisé");

    if (ext.isNotEmpty) {
      phrases.add("Le site bénéficie de : ${ext.join(', ')}.");
    }

    if (property.accessibiliteVoiture) {
      phrases.add("L'accessibilité en véhicule est excellente.");
    }

    // --- 7. VIE COMMUNE ---
    if (!isTerrain) {
      if (!property.bailleurHabiteAvec) {
        phrases.add("Note importante : le bailleur ne réside pas dans la même concession.");
      }
      if (property.nombreMenages != null && property.nombreMenages! > 1) {
        String motMenage = property.nombreMenages! > 1 ? 'ménages' : 'ménage';
        phrases.add("Le voisinage immédiat se compose de ${property.nombreMenages} $motMenage.");
      }
    }

    // --- 8. DISPONIBILITÉ ---
    final now = DateTime.now();
    bool estDejaPassee = property.dateDisponibilite != null && property.dateDisponibilite!.isBefore(now);

    if (property.disponibiliteImmediate || estDejaPassee) {
      phrases.add("Le bien est libre et disponible immédiatement.");
    } else if (property.dateDisponibilite != null) {
      String dateStr = DateFormat('d MMMM yyyy', 'fr').format(property.dateDisponibilite!);
      phrases.add("Le bien sera libéré le $dateStr.");
    }

    return phrases.join(" ");
  }
}