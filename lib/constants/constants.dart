/// ✅ Rôles utilisateurs : définit les accès dans l'application
class UserRoles {
  static const String tenant = 'locataire';
  static const String landlord = 'bailleur';
  static const String ccv = 'agent_ccv'; 
  static const String admin = 'admin';
  static const List<String> all = [tenant, landlord, ccv, admin];
}

/// ✅ INDEXATION DES COLLECTIONS FIRESTORE (EasyLocation Enterprise)
class FirestoreCollections {
  // SOURCE UNIQUE : Fusion des profils et comptes terminée
  static const String utilisateurs = 'utilisateurs'; 
  
  static const String phoneIndex = 'phone_index'; 
  static const String landlords = 'bailleurs';
  static const String tenants = 'locataires';
  static const String properties = 'proprietes'; 
  static const String activityLog = 'journal_activites'; 
  static const String adminLogs = 'admin_logs'; 
  static const String appConfig = 'app_config'; 
  static const String factures = 'factures';
  static const String contrats = 'contrats'; 
  static const String wallets = 'wallets';
  static const String transactions = 'transactions';
  static const String promotions = 'promotions'; 
  
  // ✅ NOUVELLE COLLECTION POUR LES SERVICES (Nettoyage, Peinture, etc.)
  static const String services = 'services_commandes';
}

/// ✅ GESTION DES LOCALISATIONS (Villes & Provinces)
class AppLocations {
  // ✅ CONFIGURATION PRIORITAIRE : La ville par défaut de toute l'application
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

  /// ✅ Logique de comparaison sécurisée (Case Insensitive)
  static bool compareVille(String villeA, String villeB) {
    return villeA.trim().toLowerCase() == villeB.trim().toLowerCase();
  }

  static bool isCityMatch(String cityA, String cityB) => compareVille(cityA, cityB);
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

/// ✅ NOMS DES CHAMPS POUR LES SERVICES (Harmonisation EasyLocation)
class ServiceFields {
  static const String collectionName = 'services_commandes';
  
  // Statuts de la commande
  static const String statutPropose = 'PROPOSE';   // Créé, attend le choix du paiement
  static const String statutPaye = 'PAYE';         // Succès MaxiCash
  static const String statutCommande = 'COMMANDE'; // Manuel ou Cash (En attente)
  static const String statutAnnule = 'ANNULE';

  // Workflow
  static const String etapeConfirme = 'confirmé';
  static const String etapeAttenteCash = 'attente_cash';
  static const String etapePending = 'pending'; // Pour le paiement manuel
}

/// ✅ NOMS DES CHAMPS POUR LES FACTURES (Harmonisé EasyLocation Enterprise)
class FactureFields {
  static const String collectionName = 'factures';
  static const String totalUSD = 'totalUSD';
  static const String devise = 'devise';
  
  // --- Statuts de paiement (Grammaire unique) ---
  static const String paymentStatus = 'paymentStatus'; 
  static const String statusPending = 'pending';   // En attente de paiement/validation
  
  // ✅ ALIGNÉ : Valeur brute pour tout paiement encaissé (Manuel ou MaxiCash)
  static const String statusPaid = 'success';        
  static const String statusRejected = 'rejected'; // Rejeté ou Échec
  static const String statusCompleted = 'completed'; // Utilisé pour le dossier totalement clôturé

  // --- Workflow & Suivi Centralisé ---
  static const String etapeDossier = 'etapeDossier'; 
  static const String etapeNouveau = 'nouveau';
  
  // ✅ HARMONISATION : Ajusté en MAJUSCULES strictes
  static const String statusPaidEtape = 'PAYE';             // Alias explicite pour le statut payé
  static const String etapePaye = 'PAYE';                   // Débloque le dossier pour le terrain (Validation Admin / Webhook)
  static const String statusValideEtape = 'VALIDE';        // Statut brut validé
  static const String etapeValide = 'VALIDE';              // ✅ Ajouté pour corriger la compilation
  
  // ✅ ALIGNÉ : Injecté par l'Agent de terrain lors de la clôture physique sur AgentVisitesPage
  static const String etapeVisiteTerminee = 'visite_terminee'; 
  
  static const String etapeAnnule = 'annule';                // ✅ Présent pour l'annulation de réservation
  static const String etapeCloture = 'cloture';
  static const String etapeRemboursementWallet = 'annule_et_rembourse_wallet';
  static const String statut = 'statut'; 
  
  // --- Statuts Finaux ---
  static const String statutFinal = 'statutFinal';
  static const String statutTermine = 'termine';
  static const String statutLitigeRegle = 'litige_regle_wallet';

  // --- Infos Client & Preuve ---
  static const String urlPreuve = 'urlPreuve';
  static const String dateCreation = 'dateCreation';
  static const String refMaison = 'refMaison';
  static const String nomClient = 'nomClient';
  static const String telClient = 'telClient'; 
  static const String province = 'province';
  static const String ville = 'ville';       
  static const String commune = 'commune';   
  static const String methodePaiement = 'methodePaiement';
  static const String cadeauChoisi = 'cadeauChoisi';
  static const String confirmationLocataire = 'confirmationLocataire';
  
  // --- Attributions Staff (Filtres & Traçabilité Enregistrement) ---
  // ✅ NETTOYÉ : agentId supprimé définitivement. Seul agentTerrainId gère le terrain.
  static const String agentTerrainId = 'agentTerrainId'; 
  static const String assignedAdminId = 'assignedAdminId'; // Aligné avec le champ de la propriété capturée
  
  // --- Audit Admin & Traçabilité Actions ---
  // ❌ adminValidator SUPPRIMÉ DÉFINITIVEMENT
  static const String adminRejector = 'adminRejector';
  static const String motifRejet = 'motifRejet';
  static const String dateActionAdmin = 'dateActionAdmin';
  static const String dateValidationAdmin = 'dateValidationAdmin';
  static const String dateCloture = 'dateCloture';
  static const String clotureParAdmin = 'clotureParAdmin';
  static const String dateLitigeRegle = 'dateLitigeRegle';
}

/// ✅ NOMS DES CHAMPS POUR LES CONTRATS (Harmonisé)
class ContratFields {
  static const String collectionName = 'contrats';
  
  // Identifiants & Noms
  static const String propertyId = 'propertyId';
  static const String factureId = 'factureId';
  static const String locataireId = 'locataireId';
  static const String locataireNom = 'locataireNom';
  static const String locataireTel = 'locataireTel';
  static const String bailleurId = 'bailleurId';
  static const String bailleurTel = 'telBailleur';
  static const String nomBailleur = 'nomBailleur';
  
  // ✅ NETTOYÉ : agentId supprimé. Seul agentTerrainId est conservé ici aussi pour le suivi terrain.
  static const String agentTerrainId = 'agentTerrainId'; 
  static const String referenceContrat = 'referenceContrat';
  static const String refMaison = 'refMaison';
  
  // Dates (Uniformisation FR/EN pour compatibilité)
  static const String dateDebut = 'dateDebut';     
  static const String dateDebutAlpha = 'startDate'; 
  static const String dateFin = 'endDate';            
  static const String prochainPaiement = 'prochainPaiement';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  
  // Financier
  static const String loyerMensuel = 'loyerMensuel';
  static const String nbMoisGarantie = 'nbMoisGarantie';
  static const String devise = 'devise';
  
  // Statuts (Valeurs & Champs)
  static const String statut = 'statut';             // actif, cloture, litige
  static const String status = 'status';             // active 
  static const String statusActive = 'active';
  static const String statutActif = 'actif';
  static const String statutPaiement = 'statutPaiement';
  static const String paiementPaye = 'paye';
}

/// ✅ NOMS DES CHAMPS FIRESTORE (Propriétés)
class FirestoreFields {
  static const String isVerified = 'isVerified'; 
  static const String verificationDate = 'dateCertification'; 
  static const String status = 'status'; 
  static const String imageUrls = 'imageUrls';
  static const String price = 'price';
  static const String typeBien = 'typeBien'; 
  static const String referenceCourte = 'referenceCourte';
  static const String isVisible = 'isVisible'; 
  static const String ville = 'ville'; 

  // --- Workflow Management & Traçabilité ---
  static const String processingStatus = 'processingStatus'; 
  static const String assignedAdminId = 'assignedAdminId';    
  static const String assignedAdminName = 'assignedAdminName'; 
  static const String lastUpdateBy = 'lastUpdateBy';         
  
  // ✅ AJOUTS TRAÇABILITÉ TEMPORELLE
  static const String createdAt = 'createdAt'; 
  static const String updatedAt = 'updatedAt';
  static const String takenAt = 'takenAt'; 
  static const String rejectedAt = 'rejectedAt'; 
  static const String rentedAt = 'rentedAt';

  // ✅ AJOUTS GESTION DE LA PRIORITÉ (BOOST)
  static const String hasPriorityRequest = 'hasPriorityRequest'; 
  static const String priorityStatus = 'priorityStatus';         
  static const String priorityRequestAt = 'priorityRequestAt';    

  // ✅ AJOUTS CARACTÉRISTIQUES TECHNIQUES & LOCATIVES
  static const String electricite = 'electricite';
  static const String eau = 'eau';
  static const String estLouee = 'estLouee';
  
  // ✅ GESTION DU CONTRAT
  static const String garantieMinimale = 'garantieMinimale'; 
}

/// ✅ LOGS D'AUDIT ADMIN
class AdminLogFields {
  static const String typeAction = 'typeAction';
  static const String adminName = 'adminName';
  static const String adminRole = 'adminRole';
  static const String factureId = 'factureId';
  static const String propertyId = 'propertyId';
  static const String propertyRef = 'propertyRef';
  static const String amount = 'amount';
  static const String dateAction = 'dateAction';
  static const String details = 'details';

  // --- Types d'actions (Valeurs) ---
  static const String actionRefusWallet = 'REFUS_ET_CREDIT_WALLET';
  static const String actionClotureForcee = 'CLOTURE_FORCEE_ADMIN';
  static const String actionClotureStandard = 'REMISE_CLES_ET_CLOTURE';
  
  // ✅ Ajoutée pour la réassignation d'agent
  static const String actionReassignation = 'REASSIGNATION_AGENT';
}

/// ✅ STATUTS DE VÉRIFICATION (Workflow Interne Staff)
class WorkflowStatus {
  static const String jachere = 'jachere'; 
  static const String ongoing = 'ongoing'; 
  static const String completed = 'completed';
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

/// ✅ CONFIGURATION MAXICASH (Production / Web-ready)
class MaxicashConfig {
  static const String merchantId = "6452863fb5004eafa3ce77e27fb55376"; 
  static const String gatewayUrl = "https://api-testbed.maxicashme.com/PayEntryPost";
  static const String successUrl = "https://easylocation-be28b.web.app/success";
  static const String cancelUrl = "https://easylocation-be28b.web.app/cancel";
}

/// ✅ GESTION DES CHEMINS DE STOCKAGE (Firebase Storage)
class StoragePaths {
  static const String propertiesRoot = 'proprietes';

  static String getPropertyImagePath(String bailleurId, String propertyId, String fileName) {
    return '$propertiesRoot/$bailleurId/$propertyId/$fileName.jpg';
  }

  static String getChambreImagePath(String bailleurId, String propertyId, String folder, String fileName) {
    return '$propertiesRoot/$bailleurId/$propertyId/$folder/$fileName';
  }
}

/// ✅ RÉGLAGES DE PERFORMANCE ET TIMEOUTS TECHNIQUES
class FirestoreConstants {
  static const Duration readWriteTimeout = Duration(seconds: 15);
  static const Duration getIndexTimeout = Duration(seconds: 8);
  static const Duration getUserTimeout = Duration(seconds: 10);
}

/// ✅ CONFIGURATION GÉNÉRALE DE L'APPLICATION
class AppConfig {
  static const int bookingLockDurationMinutes = 10;
  static int get bookingLockDurationMillis => bookingLockDurationMinutes * 60 * 1000;
  
  // ✅ Support technique (centralisé pour toute l'app)
  static const String supportWhatsApp = "+243XXXXXXXXX"; 
}