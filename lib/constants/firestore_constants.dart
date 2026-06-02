/// ✅ INDEXATION DES COLLECTIONS FIRESTORE (EasyLocation Enterprise)
class FirestoreCollections {
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
  static const String services = 'services_commandes';
}

/// ✅ NOMS DES CHAMPS POUR LES SERVICES
class ServiceFields {
  static const String collectionName = 'services_commandes';
  static const String statutPropose = 'PROPOSE';
  static const String statutPaye = 'PAYE';
  static const String statutCommande = 'COMMANDE';
  static const String statutAnnule = 'ANNULE';
  static const String etapeConfirme = 'confirmé';
  static const String etapeAttenteCash = 'attente_cash';
  static const String etapePending = 'pending';
}

/// ✅ NOMS DES CHAMPS POUR LES FACTURES
class FactureFields {
  static const String collectionName = 'factures';
  static const String clientId = 'clientId';
  static const String totalUSD = 'totalUSD';
  static const String totalCDF = 'totalCDF';
  static const String devise = 'devise';
  static const String paymentStatus = 'paymentStatus';
  static const String statusPending = 'pending';
  static const String statusPaid = 'success';
  static const String statusRejected = 'rejected';
  static const String statusCompleted = 'completed';
  static const String etapeDossier = 'etapeDossier';
  static const String etapeNouveau = 'nouveau';
  static const String statusPaidEtape = 'PAYE';
  static const String etapePaye = 'PAYE';
  static const String statusValideEtape = 'VALIDE';
  static const String etapeValide = 'VALIDE';
  static const String etapeVisiteTerminee = 'visite_terminee';
  static const String etapeAnnule = 'annule';
  static const String etapeCloture = 'cloture';
  static const String etapeRemboursementWallet = 'annule_et_rembourse_wallet';
  static const String statut = 'statut';
  static const String statutFinal = 'statutFinal';
  static const String statutTermine = 'termine';
  static const String statutLitigeRegle = 'litige_regle_wallet';
  static const String urlPreuve = 'urlPreuve';
  static const String dateCreation = 'dateCreation';
  static const String refMaison = 'refMaison';
  static const String nomClient = 'nomClient';
  static const String telClient = 'telClient';
  static const String nomBailleur = 'nomBailleur';
  static const String telBailleur = 'telBailleur';
  static const String province = 'province';
  static const String ville = 'ville';
  static const String commune = 'commune';
  static const String methodePaiement = 'methodePaiement';
  static const String cadeauChoisi = 'cadeauChoisi';
  static const String confirmationLocataire = 'confirmationLocataire';
  static const String agentTerrainId = 'agentTerrainId';
  static const String assignedAdminId = 'assignedAdminId';
  static const String adminRejector = 'adminRejector';
  static const String motifRejet = 'motifRejet';
  static const String dateActionAdmin = 'dateActionAdmin';
  static const String dateValidationAdmin = 'dateValidationAdmin';
  static const String dateCloture = 'dateCloture';
  static const String clotureParAdmin = 'clotureParAdmin';
  static const String dateLitigeRegle = 'dateLitigeRegle';

  // --- CHAMPS AJOUTÉS POUR CORRIGER LES ERREURS ---
  static const String id = 'id';
  static const String propertyId = 'propertyId';
  static const String bailleurId = 'bailleurId';
  static const String ownerId = 'ownerId';
  static const String status = 'status';
  static const String reservedAt = 'reservedAt';
  static const String lastLocataireId = 'lastLocataireId';
  static const String updatedAt = 'updatedAt';
  static const String loyer = 'loyer';
  static const String nbMoisGarantie = 'nbMoisGarantie';
  static const String nomOffre = 'nomOffre';
  static const String comLocatairePercent = 'comLocatairePercent';
  static const String comBailleurPercent = 'comBailleurPercent';
  static const String tauxApplique = 'tauxApplique';
  static const String montantWallet = 'montantWallet';
  static const String montantExterne = 'montantExterne';
  static const String montantCashback = 'montantCashback';
  static const String commissionSgaLocataire = 'commissionSgaLocataire';
  static const String commissionSgaBailleur = 'commissionSgaBailleur';
  static const String cadeauId = 'cadeauId';
  static const String cadeauTaille = 'cadeauTaille';
  static const String cadeauStyle = 'cadeauStyle';
  static const String villeSpecifique = 'villeSpecifique';
  static const String communeSpecifique = 'communeSpecifique';
  static const String dateExpiration = 'dateExpiration';
  static const String statutCadeau = 'statutCadeau';
  // ------------------------------------------------
}

/// ✅ NOMS DES CHAMPS POUR LES CONTRATS
class ContratFields {
  static const String collectionName = 'contrats';
  static const String propertyId = 'propertyId';
  static const String factureId = 'factureId';
  static const String locataireId = 'locataireId';
  static const String locataireNom = 'locataireNom';
  static const String locataireTel = 'locataireTel';
  static const String bailleurId = 'bailleurId';
  static const String bailleurTel = 'telBailleur';
  static const String nomBailleur = 'nomBailleur';
  static const String agentTerrainId = 'agentTerrainId';
  static const String referenceContrat = 'referenceContrat';
  static const String refMaison = 'refMaison';
  static const String dateDebut = 'dateDebut';
  static const String dateDebutAlpha = 'startDate';
  static const String dateFin = 'endDate';
  static const String prochainPaiement = 'prochainPaiement';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String loyerMensuel = 'loyerMensuel';
  static const String nbMoisGarantie = 'nbMoisGarantie';
  static const String devise = 'devise';
  static const String statut = 'statut';
  static const String status = 'status';
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
  static const String processingStatus = 'processingStatus';
  static const String assignedAdminId = 'assignedAdminId';
  static const String assignedAdminName = 'assignedAdminName';
  static const String lastUpdateBy = 'lastUpdateBy';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String takenAt = 'takenAt';
  static const String rejectedAt = 'rejectedAt';
  static const String rentedAt = 'rentedAt';
  static const String hasPriorityRequest = 'hasPriorityRequest';
  static const String priorityStatus = 'priorityStatus';
  static const String priorityRequestAt = 'priorityRequestAt';
  static const String electricite = 'electricite';
  static const String eau = 'eau';
  static const String estLouee = 'estLouee';
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
  static const String actionRefusWallet = 'REFUS_ET_CREDIT_WALLET';
  static const String actionClotureForcee = 'CLOTURE_FORCEE_ADMIN';
  static const String actionClotureStandard = 'REMISE_CLES_ET_CLOTURE';
  static const String actionReassignation = 'REASSIGNATION_AGENT';
}

/// ✅ STATUTS DE VÉRIFICATION
class WorkflowStatus {
  static const String jachere = 'jachere';
  static const String ongoing = 'ongoing';
  static const String completed = 'completed';
}