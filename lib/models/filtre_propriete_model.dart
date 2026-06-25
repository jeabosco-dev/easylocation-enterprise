// lib/models/filtre_propriete_model.dart

class FiltreProprieteModel {
  // Labels (pour l'affichage UI)
  String? province = "Sud-Kivu"; 
  String? ville = "Toutes";
  String? commune = "Toutes";
  String? quartier = "Toutes";
  String? avenue = "Toutes";

  // Clés normalisées (pour la recherche Firestore)
  String? provinceKey;
  String? villeKey;
  String? communeKey;
  String? quartierKey;
  String? avenueKey;

  String? villeSpecifique;
  String? communeSpecifique;
  String? quartierSpecifique;
  String? avenueSpecifique;

  // ✅ Recherche par code (ex: G2GMVL)
  String? queryReference; 

  // ✅ Type de bien initialisé à "Tous" pour correspondre à l'UI Admin
  String? typeBien = "Tous"; 
  double? maxPrice;
  int? nbChambres; 

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

  // --- LOGIQUE DE VÉRIFICATION ---

  bool _isFilled(String? value) {
    return value != null && value != "Toutes" && value != "Autre" && value.isNotEmpty;
  }

  /// Compte le nombre de filtres réellement modifiés par l'utilisateur
  int get activeFiltersCount {
    int count = 0;
    
    // ✅ Référence
    if (queryReference != null && queryReference!.trim().isNotEmpty) count++;

    // ✅ Localisation (Basé sur les clés pour plus de précision)
    if (provinceKey != null && provinceKey!.isNotEmpty) count++;
    if (villeKey != null && villeKey!.isNotEmpty) count++;
    if (communeKey != null && communeKey!.isNotEmpty) count++;
    if (quartierKey != null && quartierKey!.isNotEmpty) count++;
    if (avenueKey != null && avenueKey!.isNotEmpty) count++;
    
    // ✅ Type de bien
    if (typeBien != null && typeBien != "Tous") count++; 
    
    // ✅ Prix et Chambres
    if (maxPrice != null) count++;
    if (nbChambres != null) count++; 
    
    // ✅ Booléens (Commodités)
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

  // ✅ INDUSTRY BEST PRACTICES : Getters de statut
  
  bool get isEmpty => activeFiltersCount == 0;
  bool get isNotEmpty => activeFiltersCount > 0;
  bool get hasActiveFilters => isNotEmpty;

  // --- MÉTHODES UTILITAIRES ---

  FiltreProprieteModel copy() {
    return FiltreProprieteModel()
      ..province = province
      ..ville = ville
      ..commune = commune
      ..quartier = quartier
      ..avenue = avenue
      ..provinceKey = provinceKey
      ..villeKey = villeKey
      ..communeKey = communeKey
      ..quartierKey = quartierKey
      ..avenueKey = avenueKey
      ..villeSpecifique = villeSpecifique
      ..communeSpecifique = communeSpecifique
      ..quartierSpecifique = quartierSpecifique
      ..avenueSpecifique = avenueSpecifique
      ..queryReference = queryReference
      ..typeBien = typeBien 
      ..maxPrice = maxPrice
      ..nbChambres = nbChambres 
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
    provinceKey = null;
    villeKey = null;
    communeKey = null;
    quartierKey = null;
    avenueKey = null;
    villeSpecifique = null;
    communeSpecifique = null;
    quartierSpecifique = null;
    avenueSpecifique = null;
    queryReference = null; 
    typeBien = "Tous"; 
    maxPrice = null;
    nbChambres = null; 
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