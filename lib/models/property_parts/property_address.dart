// lib/models/property_parts/property_address.dart

class PropertyAddress {
  final String province;
  final String ville;
  final String? villeSpecifique;
  final String commune;
  final String? communeSpecifique;
  final String quartier;
  final String? quartierSpecifique;
  final String avenue;
  final String? avenueSpecifique;
  final String numeroMaison;

  PropertyAddress({
    required this.province,
    required this.ville,
    this.villeSpecifique,
    required this.commune,
    this.communeSpecifique,
    required this.quartier,
    this.quartierSpecifique,
    required this.avenue,
    this.avenueSpecifique,
    required this.numeroMaison,
  });

  factory PropertyAddress.fromMap(Map<String, dynamic> data) {
    return PropertyAddress(
      province: data['province']?.toString() ?? '',
      ville: data['ville']?.toString() ?? '',
      villeSpecifique: data['villeSpecifique']?.toString(),
      commune: data['commune']?.toString() ?? '',
      communeSpecifique: data['communeSpecifique']?.toString(),
      quartier: data['quartier']?.toString() ?? '',
      quartierSpecifique: data['quartierSpecifique']?.toString(),
      avenue: data['avenue']?.toString() ?? '',
      avenueSpecifique: data['avenueSpecifique']?.toString(),
      numeroMaison: data['numeroMaison']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'province': province,
      'ville': ville,
      'villeSpecifique': villeSpecifique,
      'commune': commune,
      'communeSpecifique': communeSpecifique,
      'quartier': quartier,
      'quartierSpecifique': quartierSpecifique,
      'avenue': avenue,
      'avenueSpecifique': avenueSpecifique,
      'numeroMaison': numeroMaison,
    };
  }

  // Permet de mettre à jour une partie de l'adresse sans tout recréer
  PropertyAddress copyWith({
    String? province,
    String? ville,
    String? villeSpecifique,
    String? commune,
    String? communeSpecifique,
    String? quartier,
    String? quartierSpecifique,
    String? avenue,
    String? avenueSpecifique,
    String? numeroMaison,
  }) {
    return PropertyAddress(
      province: province ?? this.province,
      ville: ville ?? this.ville,
      villeSpecifique: villeSpecifique ?? this.villeSpecifique,
      commune: commune ?? this.commune,
      communeSpecifique: communeSpecifique ?? this.communeSpecifique,
      quartier: quartier ?? this.quartier,
      quartierSpecifique: quartierSpecifique ?? this.quartierSpecifique,
      avenue: avenue ?? this.avenue,
      avenueSpecifique: avenueSpecifique ?? this.avenueSpecifique,
      numeroMaison: numeroMaison ?? this.numeroMaison,
    );
  }

  // Getter utilitaire (ex: pour l'affichage)
  String get fullAddress {
    String v = (ville == "Autre" && villeSpecifique != null) ? villeSpecifique! : ville;
    String c = (commune == "Autre" && communeSpecifique != null) ? communeSpecifique! : commune;
    String q = (quartier == "Autre" && quartierSpecifique != null) ? quartierSpecifique! : quartier;
    return '$province, $v, $c, $q';
  }
}