// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String nom;
  final String postnom;
  final String prenom;
  final String genre;
  final String telephone;
  final String? email;
  final String imageUrl;
  final String numeroMaison;
  final String avenue;
  final String quartier;
  final String commune;
  final List<String> roles;
  final String activeRole;
  final String role; // Grade de sécurité (super_admin, locataire, etc.)
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // --- CHAMPS POUR LE STAFF & RH ---
  final String staffStatus;         // Ex: '', 'pending', 'approved'
  final String requestedRole;       // Ex: 'comptable', 'logistique'
  final bool certification_conduite; // Pour le code de conduite
  final String? date_signature;      // Pour le suivi RH

  // --- CHAMPS LOGISTIQUE & CADEAU (NOUVEAU) ---
  final bool hasReceivedWelcomeGift; // ✅ Verrou : true si a déjà reçu son kit unique
  final String? lastGiftId;          // ✅ Stocke l'ID du cadeau choisi (T-shirt, Chapeau, etc.)

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
    required this.roles,
    required this.activeRole,
    this.role = 'locataire',
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
    this.staffStatus = '',
    this.requestedRole = '',
    this.certification_conduite = false,
    this.date_signature,
    // Initialisation logistique
    this.hasReceivedWelcomeGift = false, 
    this.lastGiftId,
  });

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
    List<String>? roles,
    String? activeRole,
    String? role,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? staffStatus,
    String? requestedRole,
    bool? certification_conduite,
    String? date_signature,
    bool? hasReceivedWelcomeGift,
    String? lastGiftId,
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
      roles: roles ?? this.roles,
      activeRole: activeRole ?? this.activeRole,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      staffStatus: staffStatus ?? this.staffStatus,
      requestedRole: requestedRole ?? this.requestedRole,
      certification_conduite: certification_conduite ?? this.certification_conduite,
      date_signature: date_signature ?? this.date_signature,
      hasReceivedWelcomeGift: hasReceivedWelcomeGift ?? this.hasReceivedWelcomeGift,
      lastGiftId: lastGiftId ?? this.lastGiftId,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    List<String> rolesList = [];
    if (map['roles'] is List) {
      rolesList = List<String>.from(map['roles']);
    } else if (map['role'] != null) {
      rolesList = [map['role'].toString()];
    }
    if (rolesList.isEmpty) rolesList = ['locataire'];

    DateTime? parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date);
      return null;
    }

    final String extractedRole = map['role']?.toString() ?? rolesList.first;

    return UserModel(
      uid: id,
      nom: map['nom']?.toString() ?? '',
      postnom: map['postnom']?.toString() ?? '',
      prenom: map['prenom']?.toString() ?? '',
      genre: map['genre']?.toString() ?? '',
      telephone: map['telephone']?.toString() ?? '',
      email: map['email']?.toString(),
      imageUrl: map['imageUrl']?.toString() ?? '',
      numeroMaison: map['numeroMaison']?.toString() ?? '',
      avenue: map['avenue']?.toString() ?? '',
      quartier: map['quartier']?.toString() ?? '',
      commune: map['commune']?.toString() ?? '',
      roles: rolesList,
      role: extractedRole,
      activeRole: map['activeRole']?.toString() ?? extractedRole,
      isVerified: map['isVerified'] ?? false,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      staffStatus: map['staffStatus']?.toString() ?? '',
      requestedRole: map['requestedRole']?.toString() ?? '',
      certification_conduite: map['certification_conduite'] ?? false,
      date_signature: map['date_signature']?.toString(),
      // Lecture logistique
      hasReceivedWelcomeGift: map['hasReceivedWelcomeGift'] ?? false,
      lastGiftId: map['lastGiftId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nom': nom,
      'postnom': postnom,
      'prenom': prenom,
      'genre': genre,
      'telephone': telephone,
      'email': email,
      'imageUrl': imageUrl,
      'numeroMaison': numeroMaison,
      'avenue': avenue,
      'quartier': quartier,
      'commune': commune,
      'roles': roles,
      'activeRole': activeRole,
      'role': role,
      'isVerified': isVerified,
      'staffStatus': staffStatus,
      'requestedRole': requestedRole,
      'certification_conduite': certification_conduite,
      'date_signature': date_signature,
      // Écriture logistique
      'hasReceivedWelcomeGift': hasReceivedWelcomeGift,
      'lastGiftId': lastGiftId,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      // ✅ Correction : Utilise la date locale si disponible, sinon demande au serveur
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }
}
