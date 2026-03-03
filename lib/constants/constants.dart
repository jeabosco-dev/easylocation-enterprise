// lib/core/constants.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Rôles utilisateurs
class UserRoles {
  static const String tenant = 'locataire';
  static const String landlord = 'bailleur';
  static const String ccv = 'agent_ccv'; 
  static const String admin = 'admin';
  static const List<String> all = [tenant, landlord, ccv, admin];
}

// ✅ Indexation des Collections Firestore
class FirestoreCollections {
  static const String utilisateurs = 'utilisateurs'; 
  static const String userProfiles = 'user_profiles';
  static const String phoneIndex = 'phone_index'; 
  static const String landlords = 'bailleurs';
  static const String tenants = 'locataires';
  static const String properties = 'proprietes'; 
  static const String activityLog = 'journal_activites'; 
  static const String demandesVisites = 'demandes_visites';
  static const String appConfig = 'app_config'; 
  static const String factures = 'factures'; // Ajouté pour la finance
}

// ✅ NOMS DES CHAMPS POUR LES FACTURES (Finance & Logistique)
class FactureFields {
  static const String collectionName = 'factures';
  static const String totalUSD = 'totalUSD';
  static const String paymentStatus = 'paymentStatus'; // 'pending', 'completed', 'rejected'
  static const String statut = 'statut';               // Utilisé pour le flux logistique
  static const String urlPreuve = 'urlPreuve';
  static const String dateCreation = 'dateCreation';
  static const String refMaison = 'refMaison';
  static const String nomClient = 'nomClient';
  
  // 🔥 CORRECTION ICI : Doit correspondre à la clé dans ton document Firestore "utilisateurs"
  static const String telClient = 'telephone'; 
  
  static const String motifRejet = 'motifRejet';
  static const String province = 'province';
  static const String adminValidator = 'adminValidator';
}

// ✅ NOMS DES CHAMPS FIRESTORE (Propriétés)
class FirestoreFields {
  static const String isVerified = 'isVerified';       // Le booléen de certification
  static const String verificationDate = 'dateCertification'; // Date de validation
  static const String status = 'status';              // Statut (disponible, rented, etc.)
  static const String imageUrls = 'imageUrls';
  static const String price = 'price';
}

// ✅ STATUTS DE VÉRIFICATION (Logique métier)
class VerificationStatus {
  static const String enCours = 'en_cours'; 
  static const String verifie = 'verifie';   
}

// ✅ STATUTS DE PROPRIÉTÉ
class PropertyStatus {
  static const String disponible = 'disponible'; 
  static const String booking = 'booking';   
  static const String reserved = 'reserved'; 
  static const String rented = 'rented';     

  static const List<String> all = [disponible, booking, reserved, rented];

  static String getLabel(String status) {
    switch (status) {
      case disponible: return 'DISPONIBLE';
      case booking: return 'RESERVATION EN COURS';
      case reserved: return 'DÉJÀ RÉSERVÉE';
      case rented: return 'DÉJÀ LOUÉE';
      default: return 'INCONNU';
    }
  }
}

// ✅ CONFIGURATION MAXICASH
class MaxicashConfig {
  static const String merchantId = "6452863fb5004eafa3ce77e27fb55376"; 
  static const String gatewayUrl = "https://api-testbed.maxicashme.com/PayEntryPost";
  static const String successUrl = "easylocation://success";
  static const String cancelUrl = "easylocation://cancel";
}

// ✅ Gestion des chemins de stockage (Storage)
class StoragePaths {
  static const String propertiesRoot = 'proprietes';

  // Pour l'image principale et les images spécifiques
  static String getPropertyImagePath(String bailleurId, String propertyId, String fileName) {
    return '$propertiesRoot/$bailleurId/$propertyId/$fileName.jpg';
  }

  // Pour les images des chambres
  static String getChambreImagePath(String bailleurId, String propertyId, String folder, String fileName) {
    return '$propertiesRoot/$bailleurId/$propertyId/$folder/$fileName';
  }
}

// ✅ Réglages de performance
class FirestoreConstants {
  static const Duration readWriteTimeout = Duration(seconds: 15);
  static const Duration getIndexTimeout = Duration(seconds: 8);
  static const Duration getUserTimeout = Duration(seconds: 10);
}