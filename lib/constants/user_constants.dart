/// ✅ Rôles utilisateurs : définit les accès de base dans l'application (Clients & Admin)
class UserRoles {
  static const String tenant = 'locataire';
  static const String landlord = 'bailleur';
  static const String admin = 'admin';
  static const List<String> all = [tenant, landlord, admin];
}

/// ✅ STRUCTURE DES DÉPARTEMENTS ET DIRECTIONS (EasyLocation Enterprise)
/// Alignement strict sur la gouvernance et le contrôle d'accès RBAC (Web Admin)
class AppDepartments {
  static const String superAdmin = 'SUPER_ADMIN'; 
  static const String directionGenerale = 'DIRECTION GÉNÉRALE'; 
  static const String finance = 'FINANCE'; 
  static const String rh = 'RH'; 
  static const String produitTech = 'DIRECTION PRODUIT & TECHNOLOGIE'; 
  static const String marketing = 'MARKETING'; 
  static const String operations = 'OPERATIONS'; 
  static const String logistique = 'LOGISTIQUE'; 

  static const List<String> allDirections = [
    directionGenerale,
    finance,
    rh,
    produitTech,
    marketing,
    operations,
    logistique,
  ];

  /// Renvoie un libellé propre et professionnel selon l'identifiant de la direction
  static String getLabel(String directionOrRole) {
    switch (directionOrRole.toUpperCase().trim()) {
      case superAdmin:
        return 'Super Administrateur System';
      case directionGenerale:
        return 'Direction Générale (DG)';
      case finance:
        return 'Direction Administrative & Financière (DAF)';
      case rh:
        return 'Ressources Humaines (DRH)';
      case produitTech:
        return 'Direction Produit & Technologie';
      case marketing:
        return 'Direction Marketing & Commerciale';
      case operations:
        return 'Direction des Opérations Terrain (CVV)';
      case logistique:
        return 'Direction Logistique & Approvisionnements';
      default:
        return 'UTILISATEUR STANDARD';
    }
  }
}

// ✅ CENTRALISATION DES CLÉS FIRESTORE POUR LES UTILISATEURS
class UserFields {
  static const String uid = 'uid';
  static const String prenom = 'prenom';
  static const String role = 'role';
  static const String direction = 'direction';
  static const String passwordBackoffice = 'password_backoffice'; 
}