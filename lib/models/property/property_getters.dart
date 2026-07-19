import 'package:easylocation_mvp/models/property/property.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

extension PropertyGetters on Property {
  bool get isRented => status == PropertyStatus.rented;
  
  String get type => typeBien; 
  
  bool get isEnclos => maisonEnclos;
  
  bool get hasElectricity => 
      electricite.toLowerCase() != 'non spécifié' && 
      electricite.toLowerCase() != 'aucune' && 
      electricite.toLowerCase() != 'pas d’électricité';
  
  String get referenceUnique {
    if (id.isEmpty) return "TEMP";
    return id.length >= 6 
        ? id.substring(0, 6).toUpperCase() 
        : id.toUpperCase();
  }

  String get referenceCourte => referenceUnique;
  
  String get title => id.isNotEmpty ? 'Référence $referenceUnique' : 'Propriété';
  
  String get location {
    String p = (province == "Autre" && provinceSpecifique != null) ? provinceSpecifique! : province; 
    String v = (ville == "Autre" && villeSpecifique != null) ? villeSpecifique! : ville;
    String c = (commune == "Autre" && communeSpecifique != null) ? communeSpecifique! : commune;
    String q = (quartier == "Autre" && quartierSpecifique != null) ? quartierSpecifique! : quartier;
    return '$p, $v, $c, $q';
  }

  String? get salonImageUrl => specificImageUrls['salonImage'];

  String get disponibiliteText {
    if (isRented) return "Louée / Occupée";
    if (status == PropertyStatus.enAttentePaiement) return "Traitement du paiement";
    if (status == PropertyStatus.booking) return "Réservation en cours";
    if (disponibiliteImmediate) return "Disponible immédiatement";
    if (dateDisponibilite != null) {
      return "Disponible le ${dateDisponibilite!.day.toString().padLeft(2, '0')}/${dateDisponibilite!.month.toString().padLeft(2, '0')}/${dateDisponibilite!.year}";
    }
    return "Disponibilité non spécifiée";
  }

  String get niveauText {
    if (!maisonEnEtage) return "Maison de plain-pied (Rez-de-chaussée)";
    if (niveauEtage == 99) return "Grenier aménagé";
    if (niveauEtage == 0 || niveauEtage == null) return "Rez-de-chaussée";
    if (niveauEtage == 1) return "1er étage";
    return "$niveauEtageème étage";
  }

  List<String> get imageUrls {
    if (firestoreImageUrls.isNotEmpty) return firestoreImageUrls;
    final List<String> all = [];
    if (mainImageUrl != null && mainImageUrl!.isNotEmpty) all.add(mainImageUrl!);
    all.addAll(chambresImageUrls);
    all.addAll(specificImageUrls.values);
    return all.toSet().toList();
  }
}