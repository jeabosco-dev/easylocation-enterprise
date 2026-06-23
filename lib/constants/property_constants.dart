/// ✅ GESTION DES LOCALISATIONS (Villes & Provinces)
class AppLocations {
  static const String defaultCity = 'Bukavu';
  static const List<String> villesDisponibles = [
    'Bukavu', 
    'Goma', 
    'Kinshasa', 
    'Lubumbashi', 
    'Kindu', 
    'Uvira', 
    'Kisangani',
  ];
  
  static bool compareVille(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();
  static bool isCityMatch(String cityA, String cityB) => compareVille(cityA, cityB);
}

/// ✅ SERVICES DISPONIBLES
class AppServices {
  static const List<String> liste = [
    "Location", 
    "Boost", 
    "Chasseur", 
    "Pack Déménagement", 
    "Pack Peinture", 
    "Pack Sérénité", 
    "EasyCredit"
  ];
}

/// ✅ BÉNÉFICIAIRES POUR LES PROMOTIONS
class AppBeneficiaires {
  static const String tous = 'tous';
  static const String locataire = 'locataire';
  static const String bailleur = 'bailleur';
  static const String partenaire = 'partenaire';
  static const String prestataire = 'prestataire';

  static const List<String> liste = [
    tous,
    locataire,
    bailleur,
    partenaire,
    prestataire,
  ];
}

/// ✅ TYPES DE BIENS (Centralisé pour Formulaires & Filtres)
class PropertyTypes {
  static const String maison = 'Maison Résidentielle';
  static const String appartement = 'Appartement';
  static const String studio = 'Studio / Chambrette';
  static const String commercial = 'Espace Commercial';
  static const String bureau = 'Bureau / Siège Social';
  static const String entrepot = 'Entrepôt / Dépôt';
  static const String terrain = 'Terrain';

  // Liste unique servant de source de vérité
  static const List<String> all = [
    maison,
    appartement,
    studio,
    commercial,
    bureau,
    entrepot,
    terrain,
  ];

  static String getShortLabel(String? type) {
    if (type == null) return "LOGEMENT";
    switch (type) {
      case maison: return "MAISON";
      case appartement: return "APPART.";
      case studio: return "STUDIO";
      case commercial: return "COMMERCIAL";
      case bureau: return "BUREAU";
      case entrepot: return "DÉPÔT";
      case terrain: return "TERRAIN";
      default: return type.toUpperCase();
    }
  }
}

/// ✅ STATUTS DE PROPRIÉTÉ (Visibilité Publique & Workflow)
class PropertyStatus {
  static const String disponible = 'disponible'; 
  static const String booking = 'booking';        
  static const String enAttentePaiement = 'en_attente_paiement'; 
  static const String remiseCles = 'remise_cles';
  static const String reserved = 'reserved'; 
  static const String rented = 'rented'; 
  static const String rejected = 'rejected'; 
  static const String archive = 'archive';    

  static const List<String> all = [
    disponible, booking, enAttentePaiement, remiseCles, reserved, rented, rejected, archive
  ];

  static String getLabel(String status) {
    switch (status) {
      case disponible: return 'DISPONIBLE';
      case booking: return 'RESERVATION EN COURS';
      case enAttentePaiement: return 'ATTENTE VALIDATION PAIEMENT';
      case remiseCles: return 'ATTENTE REMISE DES CLÉS';
      case reserved: return 'DÉJÀ RÉSERVÉE';
      case rented: return 'DÉJÀ LOUÉE';
      case rejected: return 'REJETÉE / NON CONFORME';
      case archive: return 'ARCHIVÉE';
      default: return 'STATUT INCONNU';
    }
  }
}