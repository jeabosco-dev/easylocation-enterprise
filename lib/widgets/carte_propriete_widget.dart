// lib/widgets/carte_propriete_widget.dart

import 'package:flutter/material.dart';
// ✅ On cache PropertyStatus du modèle pour éviter le conflit
import 'package:easylocation_mvp/models/property_model.dart' hide PropertyStatus; 
import 'package:easylocation_mvp/widgets/badge_statut_propriete.dart';
import 'package:easylocation_mvp/screens/details_propriete_page.dart'; 
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easylocation_mvp/widgets/reference_badge_widget.dart';
import 'package:easylocation_mvp/services/property_service.dart';
import 'package:easylocation_mvp/constants/constants.dart'; // ✅ Utilisé pour PropertyStatus

class CarteProprieteWidget extends StatelessWidget {
  final Property property;
  final int index;
  final List<String> allPropertiesIds;
  final bool isHorizontal;

  const CarteProprieteWidget({
    super.key,
    required this.property,
    required this.index,
    required this.allPropertiesIds,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ LOGIQUE DE CALCUL DU STATUT RÉEL
    String statutAffiche = property.status;
    
    if (property.status == PropertyStatus.booking && property.lockTimestamp != null) {
      final int maintenant = DateTime.now().millisecondsSinceEpoch;
      final int quinzeMinutesEnMillis = 15 * 60 * 1000;

      if (maintenant - property.lockTimestamp! > quinzeMinutesEnMillis) {
        // Le verrou est expiré visuellement
        statutAffiche = PropertyStatus.disponible;
        
        // On libère en base de données de manière asynchrone
        PropertyService().verifierEtLibererVerrou(property.id, property.lockTimestamp!);
      }
    }

    // --- LOGIQUE DE DESCRIPTION SYNTHÉTIQUE ---
    List<String> details = [];
    if (property.nombreChambres > 0) {
      details.add("${property.nombreChambres} ${property.nombreChambres > 1 ? 'chambres' : 'chambre'}");
    }
    if (property.hasSalon) details.add("salon");
    if (property.hasCuisine) details.add("cuisine");
    if (property.hasToiletteParentale) details.add("toilette parentale");

    String descriptionSynthetique = details.isNotEmpty 
        ? details.join(", ").replaceFirst(details.first[0], details.first[0].toUpperCase())
        : "Résidentiel disponible";

    return isHorizontal 
      ? _buildHorizontalCard(context, descriptionSynthetique, statutAffiche)
      : _buildVerticalListTile(context, descriptionSynthetique, statutAffiche);
  }

  // --- DESIGN VERTICAL (Liste principale) ---
  Widget _buildVerticalListTile(BuildContext context, String desc, String statut) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(100, 100, statut),
              const SizedBox(width: 15),
              Expanded(child: _buildTextContent(desc, isSmall: false)),
              _buildPriceSection(context),
            ],
          ),
        ),
      ),
    );
  }

  // --- DESIGN HORIZONTAL (Suggestions/Recommandations) ---
  Widget _buildHorizontalCard(BuildContext context, String desc, String statut) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12, bottom: 8, top: 8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _navigateToDetails(context),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(double.infinity, 110, statut),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildTextContent(desc, isSmall: true),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildPriceSection(context, compact: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(double w, double h, String statut) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: CachedNetworkImage(
            imageUrl: property.mainImageUrl ?? (property.imageUrls.isNotEmpty ? property.imageUrls.first : ''),
            width: w, 
            height: h, 
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[100], 
              child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[100], 
              child: const Icon(Icons.home_work, color: Colors.grey)
            ),
          ),
        ),
        // Badge de statut (Disponible, Réservé, etc.)
        Positioned(
          top: 5, 
          left: 5, 
          child: BadgeStatutPropriete(statut: statut)
        ),
        // ✅ NOUVEAU : Badge "Vérifié" sur l'image
        if (property.isVerified)
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Icon(Icons.verified, color: Colors.blue, size: 18),
            ),
          ),
      ],
    );
  }

  Widget _buildTextContent(String desc, {required bool isSmall}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${property.province}, ${property.ville}', 
                style: TextStyle(fontSize: 9, color: Colors.grey[600], letterSpacing: 0.5),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            // ✅ Badge de vérification à côté de la localisation
            if (property.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: Colors.blue, size: 12),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text('${property.commune} - ${property.quartier}', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmall ? 13 : 15, color: Colors.black87),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        
        const SizedBox(height: 6),
        ReferenceBadgeWidget(reference: property.referenceCourte),
        const SizedBox(height: 6),
        
        Text(desc, 
          style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.2),
          maxLines: isSmall ? 1 : 2, overflow: TextOverflow.ellipsis),
        
        if (!isSmall) ...[
          const SizedBox(height: 8),
          Text('Voir détails →', 
            style: TextStyle(fontSize: 10, color: Colors.blue[800], fontWeight: FontWeight.bold)),
        ]
      ],
    );
  }

  Widget _buildPriceSection(BuildContext context, {bool compact = false}) {
    return Column(
      crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${property.price.toStringAsFixed(0)}\$',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 17, 
            color: Theme.of(context).colorScheme.secondary
          )
        ),
        const Text('par mois', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _navigateToDetails(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetailsProprietePage(propertiesIds: allPropertiesIds, initialIndex: index),
    ));
  }
}
