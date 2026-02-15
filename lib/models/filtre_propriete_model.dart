// lib/models/filtre_propriete_model.dart

class FiltreProprieteModel {
  String? province = "Sud-Kivu"; 
  String? ville = "Toutes";
  String? commune = "Toutes";
  String? quartier = "Toutes";
  String? avenue = "Toutes";

  String? villeSpecifique;
  String? communeSpecifique;
  String? quartierSpecifique;
  String? avenueSpecifique;

  double? maxPrice;
  int? nbChambres; // ✅ Ajouté pour le sélecteur de chambres

  bool hasCuisine = false;
  bool hasEau = false;
  bool hasElectricity = false;
  bool hasGarage = false;
  bool isEnclos = false; 
  bool accessibiliteVoiture = false;
  bool hasToiletteParentale = false;
  bool hasSalon = false;            
  bool hasCourRecreation = false;   
  bool maisonEnEtage = false;       
  bool hasDepot = false;            
  
  bool garentieIdeale = false;      
  bool peuDeMenages = false;        
  bool bailleurAbsent = false;      

  bool _isFilled(String? value) {
    return value != null && value != "Toutes" && value != "Autre" && value.isNotEmpty;
  }

  bool isAnyFilterActive() => hasActiveFilters;

  int get activeFiltersCount {
    int count = 0;
    if (_isFilled(province)) count++;
    if (_isFilled(ville) || (ville == "Autre" && villeSpecifique != null)) count++;
    if (_isFilled(commune) || (commune == "Autre" && communeSpecifique != null)) count++;
    if (_isFilled(quartier) || (quartier == "Autre" && quartierSpecifique != null)) count++;
    if (_isFilled(avenue) || (avenue == "Autre" && avenueSpecifique != null)) count++;
    
    if (maxPrice != null) count++;
    if (nbChambres != null) count++; // ✅ Comptabilisé ici
    
    if (hasCuisine) count++;
    if (hasEau) count++;
    if (hasElectricity) count++;
    if (hasGarage) count++;
    if (isEnclos) count++;
    if (accessibiliteVoiture) count++;
    if (hasToiletteParentale) count++;
    if (hasSalon) count++;
    if (hasCourRecreation) count++;
    if (maisonEnEtage) count++;
    if (hasDepot) count++;
    if (garentieIdeale) count++;
    if (peuDeMenages) count++;
    if (bailleurAbsent) count++;
    return count;
  }

  bool get hasActiveFilters => activeFiltersCount > 0;

  FiltreProprieteModel copy() {
    return FiltreProprieteModel()
      ..province = province
      ..ville = ville
      ..commune = commune
      ..quartier = quartier
      ..avenue = avenue
      ..villeSpecifique = villeSpecifique
      ..communeSpecifique = communeSpecifique
      ..quartierSpecifique = quartierSpecifique
      ..avenueSpecifique = avenueSpecifique
      ..maxPrice = maxPrice
      ..nbChambres = nbChambres // ✅ Copié ici
      ..hasCuisine = hasCuisine
      ..hasEau = hasEau
      ..hasElectricity = hasElectricity
      ..hasGarage = hasGarage
      ..isEnclos = isEnclos
      ..accessibiliteVoiture = accessibiliteVoiture
      ..hasToiletteParentale = hasToiletteParentale
      ..hasSalon = hasSalon
      ..hasCourRecreation = hasCourRecreation
      ..maisonEnEtage = maisonEnEtage
      ..hasDepot = hasDepot
      ..garentieIdeale = garentieIdeale
      ..peuDeMenages = peuDeMenages
      ..bailleurAbsent = bailleurAbsent;
  }

  void reset() {
    province = "Sud-Kivu"; 
    ville = "Toutes"; 
    commune = "Toutes"; 
    quartier = "Toutes"; 
    avenue = "Toutes";
    villeSpecifique = null;
    communeSpecifique = null;
    quartierSpecifique = null;
    avenueSpecifique = null;
    maxPrice = null;
    nbChambres = null; // ✅ Réinitialisé ici
    hasCuisine = false; 
    hasEau = false; 
    hasElectricity = false;
    hasGarage = false; 
    isEnclos = false; 
    accessibiliteVoiture = false;
    hasToiletteParentale = false; 
    hasSalon = false;
    hasCourRecreation = false;
    maisonEnEtage = false;
    hasDepot = false;
    garentieIdeale = false; 
    peuDeMenages = false; 
    bailleurAbsent = false; 
  }
}
