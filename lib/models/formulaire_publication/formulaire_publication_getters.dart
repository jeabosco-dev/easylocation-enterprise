// lib/models/formulaire_publication/formulaire_publication_getters.dart
import 'formulaire_publication.dart';
import 'formulaire_publication_image_source.dart';

extension FormulairePublicationGetters on FormulairePublicationModel {
  
  // ***************************************************************
  // ✅ LOGIQUE DE NORMALISATION (Gestion du "Autre")
  // ***************************************************************
  String get finalProvince => (province == "Autre" && provinceSpecifique != null && provinceSpecifique!.isNotEmpty) 
      ? provinceSpecifique! : (province ?? "");

  String get finalVille => (ville == "Autre" && villeSpecifique != null && villeSpecifique!.isNotEmpty) 
      ? villeSpecifique! : (ville ?? "");

  String get finalCommune => (commune == "Autre" && communeSpecifique != null && communeSpecifique!.isNotEmpty) 
      ? communeSpecifique! : (commune ?? "");

  String get finalQuartier => (quartier == "Autre" && quartierSpecifique != null && quartierSpecifique!.isNotEmpty) 
      ? quartierSpecifique! : (quartier ?? "");

  String get finalAvenue => (avenue == "Autre" && avenueSpecifique != null && avenueSpecifique!.isNotEmpty) 
      ? avenueSpecifique! : (avenue ?? "");

  // ***************************************************************
  // ✅ LOGIQUE DE RÉFÉRENCE UNIQUE HARMONISÉE
  // ***************************************************************
  String get referenceUnique {
    if (id != null && id!.length >= 6) {
      return id!.substring(0, 6).toUpperCase();
    }
    return id?.toUpperCase() ?? "PENDING"; 
  }

  // ***************************************************************
  // ✅ GETTERS POUR LES TOILETTES (Validation UX & Galerie)
  // ***************************************************************

  /// Indique si l'utilisateur a sélectionné au moins un type de toilette
  bool get hasAtLeastOneToilette {
    return (hasToiletteParentale == true) ||
           (hasToiletteInterneCommune == true) ||
           (hasToiletteExterne == true);
  }

  /// Retourne toutes les images de toilettes fournies
  List<ImageSource> get allToiletteImages {
    final images = <ImageSource>[];
    if (toiletteParentaleImage != null && !toiletteParentaleImage!.isEmpty) {
      images.add(toiletteParentaleImage!);
    }
    if (toiletteInterneCommuneImage != null && !toiletteInterneCommuneImage!.isEmpty) {
      images.add(toiletteInterneCommuneImage!);
    }
    if (toiletteExterneImage != null && !toiletteExterneImage!.isEmpty) {
      images.add(toiletteExterneImage!);
    }
    return images;
  }

  // ***************************************************************
  // ✅ GETTER POUR LE RAPPORT D'EXPERTISE & IMAGES SPÉCIFIQUES
  // ***************************************************************
  Map<String, ImageSource> get specificImages => {
    if (salonImage != null && !salonImage!.isEmpty) 'salonImage': salonImage!,
    if (cuisineImage != null && !cuisineImage!.isEmpty) 'cuisineImage': cuisineImage!,
    if (toiletteParentaleImage != null && !toiletteParentaleImage!.isEmpty) 'toiletteParentaleImage': toiletteParentaleImage!,
    if (toiletteInterneCommuneImage != null && !toiletteInterneCommuneImage!.isEmpty) 'toiletteInterneCommuneImage': toiletteInterneCommuneImage!,
    if (toiletteExterneImage != null && !toiletteExterneImage!.isEmpty) 'toiletteExterneImage': toiletteExterneImage!,
    if (garageImage != null && !garageImage!.isEmpty) 'garageImage': garageImage!,
    if (courRecreationImage != null && !courRecreationImage!.isEmpty) 'courRecreationImage': courRecreationImage!,
    if (depotImage != null && !depotImage!.isEmpty) 'depotImage': depotImage!,
  };

  // ***************************************************************
  // ✅ LOGIQUE DE RECHERCHE (Optimisée avec les valeurs finales)
  // ***************************************************************
  List<String> get searchKeywords {
    List<String> keywords = [];
    void addKeyword(String? value) {
      if (value != null && value.trim().isNotEmpty) {
        keywords.add(value.toLowerCase().trim());
      }
    }
    
    addKeyword(finalProvince); 
    addKeyword(finalVille); 
    addKeyword(finalCommune);
    addKeyword(finalQuartier); 
    addKeyword(typeBien);
    
    return keywords.toSet().toList();
  }
}