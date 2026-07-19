import 'package:easylocation_mvp/constants/all_constants.dart';

class PropertyStatusNormalizer {
  /// Normalise les statuts provenant de Firestore.
  static String normalize(String? rawStatus) {
    if (rawStatus == null || rawStatus.isEmpty) {
      return PropertyStatus.disponible;
    }

    final String status = rawStatus.toLowerCase().trim();

    if (status == 'archive' || status == 'archivé') {
      return 'archive';
    }

    if ([
      'publiée',
      'active',
      'published',
      'disponible',
    ].contains(status)) {
      return PropertyStatus.disponible;
    }

    if ([
      'en_cours_de_reservation',
      'in_progress',
      'booking',
      'en cours',
    ].contains(status)) {
      return PropertyStatus.booking;
    }

    if ([
      'en_attente_paiement',
      'enattentepaiement',
      'pending_payment',
      'pending',
    ].contains(status)) {
      return PropertyStatus.enAttentePaiement;
    }

    if ([
      'reserve_paye',
      'reserved',
      'réservée',
      'réservé',
    ].contains(status)) {
      return PropertyStatus.reserved;
    }

    if ([
      'rented',
      'louée',
      'loué',
      'occupée',
      'occupé',
    ].contains(status)) {
      return PropertyStatus.rented;
    }

    return PropertyStatus.disponible;
  }

  /// Priorité métier du statut.
  ///
  /// Plus le nombre est petit, plus la propriété est prioritaire.
  static int getStatusPriority(String status) {
    switch (normalize(status)) {
      case PropertyStatus.disponible:
        return 1;

      case PropertyStatus.booking:
        return 2;

      case PropertyStatus.enAttentePaiement:
        return 3;

      case PropertyStatus.reserved:
        return 4;

      case PropertyStatus.rented:
        return 5;

      default:
        return 1;
    }
  }
}