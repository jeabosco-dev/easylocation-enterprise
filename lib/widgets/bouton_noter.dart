import 'package:flutter/material.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/widgets/boite_avis_unique.dart';

class BoutonNoter extends StatelessWidget {
  final Property property;
  final VoidCallback onRefresh;
  final String? userRole; // ✅ Ajout du rôle pour gérer l'affichage

  const BoutonNoter({
    super.key, 
    required this.property, 
    required this.onRefresh,
    this.userRole, // Optionnel : si non fourni, le bouton reste actif par défaut
  });

  void _ouvrirFormulaireAvis(BuildContext context) async {
    // Empêcher l'ouverture si on sait déjà que l'utilisateur n'est pas locataire
    if (userRole != null && userRole != 'locataire') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Seuls les locataires peuvent noter ce logement."))
      );
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: BoiteAvisUnique(property: property),
      ),
    );

    if (result == true) {
      onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Vérification de l'éligibilité pour le style visuel
    final bool isEligible = userRole == null || userRole == 'locataire';

    return InkWell(
      onTap: isEligible ? () => _ouvrirFormulaireAvis(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        // On réduit l'opacité si le bailleur regarde, pour montrer que c'est désactivé
        opacity: isEligible ? 1.0 : 0.4, 
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_outline, 
                color: isEligible ? Colors.amber : Colors.grey, 
                size: 28
              ),
              const SizedBox(height: 4),
              const Text(
                "Noter", 
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
              ),
              const Text(
                "avis", 
                style: TextStyle(fontSize: 10, color: Colors.grey)
              ),
            ],
          ),
        ),
      ),
    );
  }
}
