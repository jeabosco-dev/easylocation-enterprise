// lib/widgets/carte_propriete_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easylocation_mvp/utils/ui_utils.dart';
import 'package:easylocation_mvp/models/property_model.dart' hide PropertyStatus;
import 'package:easylocation_mvp/widgets/badge_statut_propriete.dart';
import 'package:easylocation_mvp/screens/details_propriete_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easylocation_mvp/widgets/reference_badge_widget.dart';
import 'package:easylocation_mvp/widgets/rating_widget.dart';
import 'package:easylocation_mvp/services/property_service.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('proprietes').doc(property.id).snapshots(),
      builder: (context, snapshot) {
        String statutAffiche = property.status;
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          statutAffiche = data['status'] ?? property.status;
        }

        if (statutAffiche == PropertyStatus.booking && property.lockTimestamp != null) {
          final int maintenant = DateTime.now().millisecondsSinceEpoch;
          if (maintenant - property.lockTimestamp! > AppConfig.bookingLockDurationMillis) {
            statutAffiche = PropertyStatus.disponible;
            _silentlyReleaseLock();
          }
        }

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
      },
    );
  }

  void _silentlyReleaseLock() {
    Future.microtask(() async {
      try {
        await PropertyService().verifierEtLibererVerrou(property.id, property.lockTimestamp!);
      } catch (e) {
        debugPrint("⚠️ Nettoyage silencieux auto-géré : $e");
      }
    });
  }

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
              SizedBox(width: 100, height: 100, child: _buildImage(statut)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextContent(desc, isSmall: false, statut: statut),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 90), 
                child: _buildPriceSection(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
              const SizedBox(height: 110, width: double.infinity, child: ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(12)), child: SizedBox())), // Espace réservé
              SizedBox(height: 110, width: double.infinity, child: _buildImage(statut)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildTextContent(desc, isSmall: true, statut: statut),
                ),
              ),
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

  void _handleTap(BuildContext context, String statut) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isMyReservation = currentUser != null && property.lockedBy == currentUser.uid;

    if (statut == PropertyStatus.booking && !isMyReservation) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚡ Quelqu'un est en train de réserver ce bien."), backgroundColor: Colors.blueGrey));
      return;
    }
    if (statut == PropertyStatus.enAttentePaiement && !isMyReservation) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚡ Un paiement est en cours de traitement."), backgroundColor: Colors.amber));
      return;
    }
    if (statut == PropertyStatus.reserved && !isMyReservation) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🔒 Ce bien est déjà réservé."), backgroundColor: Colors.orange));
      return;
    }
    _navigateToDetails(context);
  }

  Widget _buildImage(String statut) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (property.mainImageUrl != null || property.imageUrls.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: CachedNetworkImage(
              imageUrl: property.mainImageUrl ?? property.imageUrls.first,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(color: Colors.grey[100], child: const Icon(Icons.home_work, color: Colors.grey)),
            ),
          )
        else
          Container(decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.home_work, color: Colors.grey)),
        Positioned(top: 5, left: 5, child: BadgeStatutPropriete(status: statut)),
        if (property.isVerified)
          Positioned(top: 5, right: 5, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]), child: const Icon(Icons.verified, color: Colors.blue, size: 16))),
      ],
    );
  }

  Widget _buildTextContent(String desc, {required bool isSmall, required String statut}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isMyFinalReservation = (statut == PropertyStatus.reserved || statut == PropertyStatus.booking || statut == PropertyStatus.enAttentePaiement) 
                                      && currentUser != null && (property.lockedBy == currentUser.uid || property.lastLocataireId == currentUser.uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
          child: Text(PropertyTypes.getShortLabel(property.typeBien), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        ),
        const SizedBox(height: 4),
        Text('${property.province}, ${property.ville}', style: TextStyle(fontSize: 9, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text('${property.commune} - ${property.quartier}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmall ? 13 : 15), maxLines: 1, overflow: TextOverflow.ellipsis),
        ReferenceBadgeWidget(reference: property.referenceUnique),
        const SizedBox(height: 4),
        RatingWidget(
          averageRating: property.averageRating?.toDouble() ?? 0.0,
          count: property.ratingCount ?? 0,
        ),
        const SizedBox(height: 4),
        if (isMyFinalReservation && statut != PropertyStatus.enAttentePaiement) _buildPaymentSuccessLabel()
        else Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey[700]), maxLines: isSmall ? 1 : 2, overflow: TextOverflow.ellipsis),
        if (!isSmall) ...[
           const SizedBox(height: 6),
           Builder(builder: (context) {
             String label = 'Voir détails →';
             Color labelColor = Colors.blue[800]!;
             if (statut == PropertyStatus.reserved || statut == PropertyStatus.booking) {
               label = isMyFinalReservation ? 'Consulter mon dossier →' : 'Indisponible';
               labelColor = isMyFinalReservation ? Colors.green[700]! : Colors.grey;
             } else if (statut == PropertyStatus.enAttentePaiement) {
               label = isMyFinalReservation ? 'Suivre mon paiement →' : 'Vérification en cours →';
               labelColor = isMyFinalReservation ? Colors.amber[900]! : Colors.orange[700]!;
             }
             return Text(label, style: TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis);
           }),
        ]
      ],
    );
  }

  Widget _buildPaymentSuccessLabel() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.withOpacity(0.3))),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              "PAYÉ - CONTACTEZ L'AGENT",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w900,
                fontSize: 9,
              ),
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
        Text(
          '${UIUtils.formatPrice(property.price)}\$', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: compact ? 16 : 18, color: Theme.of(context).colorScheme.secondary),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const Text('par mois', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _navigateToDetails(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsProprietePage(propertiesIds: allPropertiesIds, initialIndex: index, propertyId: property.id)));
  }
}