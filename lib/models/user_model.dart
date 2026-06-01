// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';

class UserModel {
  final String uid;
  final String nom;
  final String postnom;
  final String prenom;
  final String genre;
  final String telephone;
  final String? email;
  final String imageUrl;

  // --- ADRESSE DÉTAILLÉE ---
  final String numeroMaison;
  final String avenue;
  final String quartier;
  final String commune;
  final String ville;     // ✅ Géré
  final String province;  // ✅ Géré
  final String pays;      // ✅ Géré

  final List<String> roles;
  final String activeRole;
  final String role; // Grade de sécurité (super_admin, locataire, etc.)
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ✅ ACCÈS BACKOFFICE SÉCURISÉ
  final String passwordBackoffice; // ✅ Aligné avec la base de données et UserFields

  // ✅ Pour la gestion d'adresse structurée (Map)
  final Map<String, dynamic>? adresseComplete; 

  // 🌟 NOUVEAUX CHAMPS COMPATIBILITÉ BACKOFFICE DIRECTIFS & RH 🌟
  final String? emailProfessionnel;
  final String? direction;

  // --- PARRAINAGE ---
  final String? referrerId; 

  // --- NOTIFICATIONS ---
  final String? fcmToken; 

  // --- CHAMPS POUR LE STAFF & RH ---
  final String staffStatus;         // Ex: '', 'pending', 'approved'
  final String requestedRole;       // Ex: 'comptable', 'logistique'
  final bool certification_conduite; 
  final String? date_signature;      

  // --- CHAMPS LOGISTIQUE & CADEAU ---
  final bool hasReceivedWelcomeGift; 
  final String? lastGiftId;          

  // --- CHAMP FINANCIER & FIDÉLITÉ ---
  final double walletBalance;        
  final int pointsLoyalty; // ✅ AJOUTÉ : Pour la gestion du cashback/points

  // ✅ Getters utiles
  String get phoneNumber => telephone;

  String get nomComplet => '$prenom $nom $postnom'.trim().toUpperCase();

  // 🌟 ALIAS DE COMPATIBILITÉ POUR LE BACKOFFICE WEB ADMIN 🌟
  String? get email_professionnel => emailProfessionnel;
  Map<String, dynamic>? get adresse_complete => adresseComplete;

  // ✅ GETTER INTELLIGENT : Centralise l'affichage de l'adresse avec préfixes
  String get fullAddress {
    List<String> parts = [
      if (numeroMaison.isNotEmpty) "N° $numeroMaison",
      if (avenue.isNotEmpty) "Av. $avenue",
      if (quartier.isNotEmpty) "Q. $quartier",
      if (commune.isNotEmpty) "C. $commune",
      if (ville.isNotEmpty) ville,
      if (province.isNotEmpty) province,
      if (pays.isNotEmpty) pays,
    ];

    // Sécurité : Si les champs racine sont vides, on tente de lire la Map adresseComplete
    if (parts.isEmpty && adresseComplete != null) {
      return adresseComplete!.values
          .where((v) => v != null && v.toString().trim().isNotEmpty)
          .join(", ");
    }

    return parts.isEmpty ? "Adresse non renseignée" : parts.join(", ");
  }

  UserModel({
    required this.uid,
    required this.nom,
    required this.postnom,
    required this.prenom,
    required this.genre,
    required this.telephone,
    this.email,
    this.imageUrl = '',
    required this.numeroMaison,
    required this.avenue,
    required this.quartier,
    required this.commune,
    this.ville = 'Bukavu',      // ✅ Valeur par défaut
    this.province = 'Sud-Kivu', // ✅ Valeur par défaut
    this.pays = 'RDC',           // ✅ Valeur par défaut
    required this.roles,
    required this.activeRole,
    this.role = 'locataire',
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
    this.passwordBackoffice = '', // ✅ Sécurisé par défaut
    this.adresseComplete, 
    this.emailProfessionnel,
    this.direction,
    this.referrerId,
    this.fcmToken,
    this.staffStatus = '',
    this.requestedRole = '',
    this.certification_conduite = false,
    this.date_signature,
    this.hasReceivedWelcomeGift = false, 
    this.lastGiftId,
    this.walletBalance = 0.0, 
    this.pointsLoyalty = 0, // ✅ AJOUTÉ
  });

  // ✅ Utilisé pour les exports Excel ou services tiers
  Map<String, String> toServiceMap() {
    return {
      'nom_complet': nomComplet,
      'telephone': telephone,
      'email': email ?? '',
      'adresse': fullAddress,
      'role': activeRole,
      'genre': genre,
      'solde': "${walletBalance.toStringAsFixed(2)} USD",
      'points': pointsLoyalty.toString(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? nom,
    String? postnom,
    String? prenom,
    String? genre,
    String? telephone,
    String? email,
    String? imageUrl,
    String? numeroMaison,
    String? avenue,
    String? quartier,
    String? commune,
    String? ville,
    String? province,
    String? pays,
    List<String>? roles,
    String? activeRole,
    String? role,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? passwordBackoffice, 
    Map<String, dynamic>? adresseComplete,
    String? emailProfessionnel,
    String? direction,
    String? referrerId,
    String? fcmToken,
    String? staffStatus,
    String? requestedRole,
    bool? certification_conduite,
    String? date_signature,
    bool? hasReceivedWelcomeGift,
    String? lastGiftId,
    double? walletBalance,
    int? pointsLoyalty, 
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      nom: nom ?? this.nom,
      postnom: postnom ?? this.postnom,
      prenom: prenom ?? this.prenom,
      genre: genre ?? this.genre,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      imageUrl: imageUrl ?? this.imageUrl,
      numeroMaison: numeroMaison ?? this.numeroMaison,
      avenue: avenue ?? this.avenue,
      quartier: quartier ?? this.quartier,
      commune: commune ?? this.commune,
      ville: ville ?? this.ville,
      province: province ?? this.province,
      pays: pays ?? this.pays,
      roles: roles ?? this.roles,
      activeRole: activeRole ?? this.activeRole,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      passwordBackoffice: passwordBackoffice ?? this.passwordBackoffice, 
      adresseComplete: adresseComplete ?? this.adresseComplete,
      emailProfessionnel: emailProfessionnel ?? this.emailProfessionnel,
      direction: direction ?? this.direction,
      referrerId: referrerId ?? this.referrerId,
      fcmToken: fcmToken ?? this.fcmToken,
      staffStatus: staffStatus ?? this.staffStatus,
      requestedRole: requestedRole ?? this.requestedRole,
      certification_conduite: certification_conduite ?? this.certification_conduite,
      date_signature: date_signature ?? this.date_signature,
      hasReceivedWelcomeGift: hasReceivedWelcomeGift ?? this.hasReceivedWelcomeGift,
      lastGiftId: lastGiftId ?? this.lastGiftId,
      walletBalance: walletBalance ?? this.walletBalance,
      pointsLoyalty: pointsLoyalty ?? this.pointsLoyalty, 
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    List<String> rolesList = [];
    if (map['roles'] is List) {
      rolesList = List<String>.from(map['roles']);
    } else if (map[UserFields.role] != null) {
      rolesList = [map[UserFields.role].toString()];
    }
    if (rolesList.isEmpty) rolesList = ['locataire'];

    DateTime? parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date);
      return null;
    }

    final String extractedRole = map[UserFields.role]?.toString() ?? rolesList.first;

    return UserModel(
      uid: id,
      nom: map['nom']?.toString() ?? '',
      postnom: map['postnom']?.toString() ?? '',
      prenom: map[UserFields.prenom]?.toString() ?? '', 
      genre: map['genre']?.toString() ?? '',
      telephone: map['telephone']?.toString() ?? '',
      email: map['email']?.toString(),
      imageUrl: map['imageUrl']?.toString() ?? '',
      numeroMaison: map['numeroMaison']?.toString() ?? '',
      avenue: map['avenue']?.toString() ?? '',
      quartier: map['quartier']?.toString() ?? '',
      commune: map['commune']?.toString() ?? '',
      ville: map['ville']?.toString() ?? 'Bukavu',
      province: map['province']?.toString() ?? 'Sud-Kivu',
      pays: map['pays']?.toString() ?? 'RDC',
      roles: rolesList,
      role: extractedRole,
      activeRole: map['activeRole']?.toString() ?? extractedRole,
      isVerified: map['isVerified'] ?? false,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      passwordBackoffice: map[UserFields.passwordBackoffice]?.toString() ?? '', 
      adresseComplete: map['adresseComplete'] is Map 
          ? Map<String, dynamic>.from(map['adresseComplete']) 
          : null,
      emailProfessionnel: map['email_professionnel']?.toString(), // ✅ Lecture Firestore
      direction: map['direction']?.toString(),                   // ✅ Lecture Firestore
      referrerId: map['referrerId']?.toString(),
      fcmToken: map['fcmToken']?.toString(),
      staffStatus: map['staffStatus']?.toString() ?? '',
      requestedRole: map['requestedRole']?.toString() ?? '',
      certification_conduite: map['certification_conduite'] ?? false,
      date_signature: map['date_signature']?.toString(),
      hasReceivedWelcomeGift: map['hasReceivedWelcomeGift'] ?? false,
      lastGiftId: map['lastGiftId']?.toString(),
      walletBalance: (map['walletBalance'] ?? 0.0).toDouble(),
      pointsLoyalty: (map['pointsLoyalty'] ?? 0).toInt(), 
    );
  }

  Map<String, dynamic> toMap() {
    return {
      UserFields.uid: uid, 
      'nom': nom,
      'postnom': postnom,
      UserFields.prenom: prenom, 
      'genre': genre,
      'telephone': telephone,
      'email': email,
      'imageUrl': imageUrl,
      'numeroMaison': numeroMaison,
      'avenue': avenue,
      'quartier': quartier,
      'commune': commune,
      'ville': ville,
      'province': province,
      'pays': pays,
      'roles': roles,
      'activeRole': activeRole,
      UserFields.role: role, 
      'isVerified': isVerified,
      UserFields.passwordBackoffice: passwordBackoffice, 
      'adresseComplete': adresseComplete, 
      'email_professionnel': emailProfessionnel, // ✅ Écriture Firestore
      'direction': direction,                   // ✅ Écriture Firestore
      'referrerId': referrerId,
      'fcmToken': fcmToken,
      'staffStatus': staffStatus,
      'requestedRole': requestedRole,
      'certification_conduite': certification_conduite,
      'date_signature': date_signature,
      'hasReceivedWelcomeGift': hasReceivedWelcomeGift,
      'lastGiftId': lastGiftId,
      'walletBalance': walletBalance,
      'pointsLoyalty': pointsLoyalty, 
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }
}