import 'package:flutter/material.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:intl/intl.dart';

class SectionDescriptionDynamique extends StatelessWidget {
  final Property property;

  const SectionDescriptionDynamique({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "À propos de ce logement",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        Text(
          _genererDescriptionAutomatique(),
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: Colors.black87,
          ),
        ),
        
        // Affiche la description manuelle si elle existe (ajoutée par l'utilisateur)
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

    // --- 1. TYPE DE CONSTRUCTION ET NIVEAU (Logique Sol vs Étages) ---
    if (property.maisonEnEtage == false) {
      phrases.add("Il s'agit d'une maison simple, construite au niveau du sol (non en étage).");
    } else {
      if (property.niveauEtage == 99) {
        phrases.add("Ce logement est situé au niveau du grenier.");
      } else if (property.niveauEtage == 0 || property.niveauEtage == null) {
        phrases.add("Ce logement est situé au rez-de-chaussée d'un bâtiment en étage.");
      } else {
        String rang = property.niveauEtage == 1 ? "1er" : "${property.niveauEtage}ème";
        phrases.add("Ce logement se situe au $rang étage.");
      }
    }

    // --- 2. COMPOSITION ET SOL ---
    String composition = "Il dispose de ${property.nombreChambres} ${property.nombreChambres > 1 ? 'chambres' : 'chambre'}";
    if (property.hasSalon) composition += " et d'un salon";
    phrases.add("$composition.");

    if (property.selectedTypeSol != null && property.selectedTypeSol != 'autre' && property.selectedTypeSol!.isNotEmpty) {
      String typeSol = property.selectedTypeSol!.contains('carrelé') ? "carreaux" : "ciment";
      phrases.add("L'intérieur de la maison est en $typeSol.");
    }

    // --- 3. COMMODITÉS INTERNES ---
    List<String> interne = [];
    if (property.hasToiletteParentale) interne.add("une toilette interne");
    if (property.hasCuisine) interne.add("une cuisine");
    if (property.hasDepot) interne.add("un espace de stockage (dépôt)");
    
    if (interne.isNotEmpty) {
      phrases.add("Le confort intérieur est assuré par ${interne.join(', ')}.");
    }

    // --- 4. SERVICES : EAU & ÉLECTRICITÉ ---
    if (property.electricite == 'propre cash-power' || property.electricite == 'Propre Cash-power') {
      phrases.add("Côté électricité, vous disposez de votre propre compteur Cash-power.");
    } else if (property.electricite.toLowerCase().contains('commun')) {
      phrases.add("L'électricité est fournie via un compteur commun.");
    }

    if (property.hasEau) {
      String emplacementEau = property.compteurEau ? "dans la maison" : "dans la parcelle";
      phrases.add("L'eau est disponible $emplacementEau.");
    }

    // --- 5. ACCÈS, EXTERIEUR ET COHABITATION ---
    List<String> exterieur = [];
    if (property.hasGarage) exterieur.add("un garage");
    if (property.hasCourRecreation) exterieur.add("une cour de récréation");
    if (property.maisonEnclos) exterieur.add("un enclos (clôture)");

    if (exterieur.isNotEmpty) {
      phrases.add("Vous disposez aussi de : ${exterieur.join(', ')}.");
    }

    if (property.accessibiliteVoiture) {
      phrases.add("Le site est facilement accessible en voiture.");
    }

    if (!property.bailleurHabiteAvec) {
      phrases.add("Le bailleur n'habite pas sur place, garantissant votre intimité.");
    }

    if (property.nombreMenages != null && property.nombreMenages! > 1) {
      phrases.add("La parcelle est occupée par ${property.nombreMenages} ménages.");
    }

    // --- 6. DISPONIBILITÉ ---
    final now = DateTime.now();
    bool estDejaPassee = property.dateDisponibilite != null && property.dateDisponibilite!.isBefore(now);

    if (property.disponibiliteImmediate || estDejaPassee) {
      phrases.add("Le logement est disponible immédiatement.");
    } else if (property.dateDisponibilite != null) {
      String dateStr = DateFormat('d MMMM yyyy', 'fr').format(property.dateDisponibilite!);
      phrases.add("Le logement sera prêt pour emménagement le $dateStr.");
    }

    // --- 7. CONDITIONS FINANCIÈRES ---
    if (property.garantieMinimale <= 6 && property.garantieMinimale > 0) {
      phrases.add("Les conditions de garantie sont particulièrement avantageuses.");
    }

    return phrases.join(" ");
  }
}
