// lib/widgets/carte_propriete_widget.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:easylocation_mvp/utils/ui_utils.dart';
// On cache PropertyStatus du modèle pour éviter le conflit avec les constantes
import 'package:easylocation_mvp/models/property_model.dart' hide PropertyStatus; 
import 'package:easylocation_mvp/widgets/badge_statut_propriete.dart';
import 'package:easylocation_mvp/screens/details_propriete_page.dart'; 
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easylocation_mvp/widgets/reference_badge_widget.dart';
import 'package:easylocation_mvp/services/property_service.dart';
import 'package:easylocation_mvp/constants/constants.dart'; 

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
    // ✅ LOGIQUE DE CALCUL DU STATUT RÉEL (Optimisée)
    String statutAffiche = property.status;
    
    if (property.status == PropertyStatus.booking && property.lockTimestamp != null) {
      final int maintenant = DateTime.now().millisecondsSinceEpoch;
      
      // Si le temps de verrou (10 min) est dépassé
      if (maintenant - property.lockTimestamp! > AppConfig.bookingLockDurationMillis) {
        statutAffiche = PropertyStatus.disponible;
        // On nettoie en tâche de fond sans bloquer l'affichage
        _silentlyReleaseLock();
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
        : "Propriété disponible";

    return isHorizontal 
      ? _buildHorizontalCard(context, descriptionSynthetique, statutAffiche)
      : _buildVerticalListTile(context, descriptionSynthetique, statutAffiche);
  }

  // ✅ Nettoyage asynchrone pour ne pas saturer le build
  void _silentlyReleaseLock() {
    Future.microtask(() async {
      try {
        await PropertyService().verifierEtLibererVerrou(property.id, property.lockTimestamp!);
      } catch (e) {
        debugPrint("⚠️ Nettoyage silencieux auto-géré : $e");
      }
    });
  }

  // --- DESIGN VERTICAL (Liste principale) ---
  Widget _buildVerticalListTile(BuildContext context, String desc, String statut) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _handleTap(context, statut),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(100, 100, statut),
              const SizedBox(width: 15),
              Expanded(child: _buildTextContent(desc, isSmall: false, statut: statut)),
              const SizedBox(width: 8),
              _buildPriceSection(context),
            ],
          ),
        ),
      ),
    );
  }

  // --- DESIGN HORIZONTAL ---
  Widget _buildHorizontalCard(BuildContext context, String desc, String statut) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12, bottom: 8, top: 8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _handleTap(context, statut),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(double.infinity, 110, statut),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildTextContent(desc, isSmall: true, statut: statut),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: _buildPriceSection(context, compact: true),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 LOGIQUE DE CLIC SÉCURISÉE (Avec gestion de la file d'attente de paiement)
  void _handleTap(BuildContext context, String statut) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isMyReservation = currentUser != null && property.lastLocataireId == currentUser.uid;

    // 1. Cas : Quelqu'un d'autre est en train de payer (Booking temporaire de 10 min)
    if (statut == PropertyStatus.booking && !isMyReservation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚡ Quelqu'un est en train de réserver ce bien. Réessayez dans quelques minutes."),
          backgroundColor: Colors.blueGrey,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. Cas SECURISÉ : Quelqu'un d'autre a un paiement en cours de vérification par les agents CCV
    if (statut == PropertyStatus.enAttentePaiement && !isMyReservation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚡ Un paiement est en cours de traitement pour ce bien. Réessayez plus tard."),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 3. Cas : Déjà réservé définitivement / Payé validé (Reserved)
    if (statut == PropertyStatus.reserved && !isMyReservation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🔒 Ce bien est déjà réservé pour une visite."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 4. Cas : Libre, ou c'est ma propre session de réservation/paiement -> Accès autorisé
    _navigateToDetails(context);
  }

  Widget _buildImage(double w, double h, String statut) {
    return Stack(
      children: [
        if (property.mainImageUrl != null || property.imageUrls.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: CachedNetworkImage(
              imageUrl: property.mainImageUrl ?? property.imageUrls.first,
              width: w, 
              height: h, 
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[100]),
              errorWidget: (context, url, error) => Container(color: Colors.grey[100], child: const Icon(Icons.home_work, color: Colors.grey)),
            ),
          )
        else
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.home_work, color: Colors.grey),
          ),
        Positioned(top: 5, left: 5, child: BadgeStatutPropriete(status: statut)),
        if (property.isVerified)
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
              child: const Icon(Icons.verified, color: Colors.blue, size: 16),
            ),
          ),
      ],
    );
  }

  Widget _buildTextContent(String desc, {required bool isSmall, required String statut}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    // Inclusion optimisée du statut enAttentePaiement pour l'identification du locataire concerné
    final bool isMyFinalReservation = (statut == PropertyStatus.reserved || 
                                       statut == PropertyStatus.booking || 
                                       statut == PropertyStatus.enAttentePaiement) 
                                      && currentUser != null 
                                      && property.lastLocataireId == currentUser.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            PropertyTypes.getShortLabel(property.typeBien), 
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.deepPurple),
          ),
        ),
        const SizedBox(height: 4),
        Text('${property.province}, ${property.ville}', 
          style: TextStyle(fontSize: 9, color: Colors.grey[600], letterSpacing: 0.5),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text('${property.commune} - ${property.quartier}', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmall ? 13 : 15, color: Colors.black87),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        ReferenceBadgeWidget(reference: property.referenceUnique),
        const SizedBox(height: 4),
        
        // Affichage conditionnel du statut de paiement pour le locataire
        if (isMyFinalReservation && statut != PropertyStatus.enAttentePaiement)
           _buildPaymentSuccessLabel()
        else
          Text(desc, 
            style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.2),
            maxLines: isSmall ? 1 : 2, overflow: TextOverflow.ellipsis),
        
        if (!isSmall) ...[
          const SizedBox(height: 6),
          Builder(builder: (context) {
            String label = 'Voir détails →';
            Color labelColor = Colors.blue[800]!;

            if (statut == PropertyStatus.reserved || statut == PropertyStatus.booking) {
              if (isMyFinalReservation) {
                label = 'Consulter mon dossier →';
                labelColor = Colors.green[700]!;
              } else {
                label = 'Indisponible';
                labelColor = Colors.grey;
              }
            }
            // ✅ AJOUT D'AFFICHAGE DU LABEL D'ACTION SELON LES MEILLEURES PRATIQUES
            else if (statut == PropertyStatus.enAttentePaiement) {
              if (isMyFinalReservation) {
                label = 'Suivre mon paiement →';
                labelColor = Colors.amber[900]!;
              } else {
                label = 'Vérification en cours →';
                labelColor = Colors.orange[700]!;
              }
            }

            return Text(label, 
              style: TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.bold));
          }),
        ]
      ],
    );
  }

  // ✅ Nouveau Widget pour rassurer le locataire après paiement
  Widget _buildPaymentSuccessLabel() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.withOpacity(0.3))
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 12),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              "PAYÉ - CONTACTEZ L'AGENT",
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection(BuildContext context, {bool compact = false}) {
    return Column(
      crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${UIUtils.formatPrice(property.price)}\$',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: compact ? 16 : 18, 
            color: Theme.of(context).colorScheme.secondary
          )
        ),
        const Text('par mois', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _navigateToDetails(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetailsProprietePage(
        propertiesIds: allPropertiesIds, 
        initialIndex: index,
        propertyId: property.id,
      ),
    ));
  }
}