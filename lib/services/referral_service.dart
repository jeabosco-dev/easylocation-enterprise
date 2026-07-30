// lib/services/referral_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Structure représentant les données d'un parrainage capturé via un lien profond (Deep Link)
class ReferralData {
  final String type; // "partner" ou "user"
  final String id;   // L'ID du partenaire ou l'UID de l'utilisateur

  ReferralData({required this.type, required this.id});

  @override
  String toString() => 'ReferralData(type: $type, id: $id)';
}

class ReferralService {
  /// Base URL pour le parrainage (Deep Link) harmonisée sur /referral
  static const String _baseUrl = "https://easylocation-be28b.web.app/referral";

  // Clés pour le stockage local du parrainage en attente
  static const String _pendingReferralTypeKey = 'pending_referral_type';
  static const String _pendingReferralIdKey = 'pending_referral_id';

  // ==========================================
  // 1. GÉNÉRATION DES LIENS
  // ==========================================

  /// Génère l'URL pour un partenaire B2B (ex: /referral?partner=PART-EGLISE-KADUTU)
  static String genererLienPartenaire(String partnerId) {
    return "$_baseUrl?partner=$partnerId";
  }

  /// Génère l'URL pour un utilisateur C2C (ex: /referral?user=UID123456)
  static String genererLienUtilisateur(String uid) {
    return "$_baseUrl?user=$uid";
  }

  /// Rétrocompatibilité / Générateur pour QR Code physique (pointe vers le partenaire)
  static String genererLienPourQRCode(String partnerCode) {
    return genererLienPartenaire(partnerCode);
  }

  // ==========================================
  // 2. GÉNÉRATION DES MESSAGES DE PARTAGE
  // ==========================================

  /// Génère un message formaté professionnel pour un partenaire B2B
  static String genererMessagePartenaire(String partnerId, {String? partnerName}) {
    final String lien = genererLienPartenaire(partnerId);
    final String nomAffiche = (partnerName != null && partnerName.isNotEmpty) ? partnerName : "notre partenaire";

    return "🏠 *Bienvenue sur EasyLocation Enterprise*\n\n"
        "Rejoignez la plateforme recommandée par $nomAffiche pour trouver ou publier "
        "vos biens immobiliers en toute sécurité en RDC.\n\n"
        "Inscrivez-vous via notre lien exclusif :\n\n"
        "👉 $lien\n\n"
        "🤝 *L'immobilier simplifié et sécurisé.*";
  }

  /// Génère un message formaté professionnel pour un utilisateur C2C
  static String genererMessageUtilisateur(String uid) {
    final String lien = genererLienUtilisateur(uid);

    return "🏠 *Optimisez votre recherche immobilière avec EasyLocation Enterprise*\n\n"
        "Salut ! J'utilise cette application pour louer des maisons rapidement et en toute sécurité en RDC. "
        "Inscris-toi via mon lien pour bénéficier de leurs services et d'un bonus de bienvenue :\n\n"
        "👉 $lien\n\n"
        "🤝 *L'immobilier simplifié et sécurisé.*";
  }

  // ==========================================
  // 3. ACTIONS DE PARTAGE (SHARE)
  // ==========================================

  /// Partage un lien partenaire via le share_plus
  static Future<void> partagerLienPartenaire(String partnerId, {String? partnerName}) async {
    final String message = genererMessagePartenaire(partnerId, partnerName: partnerName);
    try {
      await Share.share(
        message,
        subject: "Invitation Partenaire EasyLocation Enterprise",
      );
    } catch (e) {
      debugPrint("Erreur lors du partage du lien partenaire : $e");
    }
  }

  /// Partage un lien utilisateur via le share_plus
  static Future<void> partagerLienUtilisateur(String uid) async {
    final String message = genererMessageUtilisateur(uid);
    try {
      await Share.share(
        message,
        subject: "Invitation EasyLocation Enterprise",
      );
    } catch (e) {
      debugPrint("Erreur lors du partage du lien utilisateur : $e");
    }
  }

  /// Méthode globale de partage (pour rétrocompatibilité)
  static Future<void> partagerLien(String monCode) async {
    if (monCode.startsWith('PART-')) {
      await partagerLienPartenaire(monCode);
    } else {
      await partagerLienUtilisateur(monCode);
    }
  }

  // ==========================================
  // 4. GESTION DES PARTENAIRES (B2B)
  // ==========================================

  /// Récupère les informations d'un partenaire depuis Firestore
  static Future<Map<String, dynamic>?> getPartner(String partnerId) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('partenaires')
          .doc(partnerId)
          .get();

      if (docSnapshot.exists) {
        return docSnapshot.data();
      } else {
        // Tentative de recherche par champ si l'ID du document est différent de l'attribut du code
        final querySnapshot = await FirebaseFirestore.instance
            .collection('partenaires')
            .where('partnerId', isEqualTo: partnerId)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          return querySnapshot.docs.first.data();
        }
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération du partenaire $partnerId : $e");
    }
    return null;
  }

  // ==========================================
  // 5. CAPTURE ET ANALYSE DES LIENS
  // ==========================================

  /// Analyse l'URI reçue à l'ouverture de l'application et retourne un objet typé ReferralData
  static ReferralData? capturerReferral(Uri uri) {
    try {
      // 1. Analyse prioritaire de la nouvelle structure claire
      if (uri.queryParameters.containsKey('partner')) {
        final String partnerId = uri.queryParameters['partner']!;
        debugPrint("🎯 Code Partenaire B2B détecté : $partnerId");
        return ReferralData(type: 'partner', id: partnerId);
      } 
      
      if (uri.queryParameters.containsKey('user')) {
        final String userId = uri.queryParameters['user']!;
        debugPrint("👤 Code Utilisateur C2C détecté : $userId");
        return ReferralData(type: 'user', id: userId);
      }

      // 2. Rétrocompatibilité avec l'ancienne structure '?ref=' ou '?code='
      String? legacyCode;
      if (uri.queryParameters.containsKey('ref')) {
        legacyCode = uri.queryParameters['ref'];
      } else if (uri.queryParameters.containsKey('code')) {
        legacyCode = uri.queryParameters['code'];
      }

      if (legacyCode != null && legacyCode.isNotEmpty) {
        if (legacyCode.startsWith('PART-')) {
          debugPrint("🎯 [Legacy] Code Partenaire détecté : $legacyCode");
          return ReferralData(type: 'partner', id: legacyCode);
        } else {
          debugPrint("👤 [Legacy] Code Utilisateur détecté : $legacyCode");
          return ReferralData(type: 'user', id: legacyCode);
        }
      }
    } catch (e) {
      debugPrint("Erreur lors de l'analyse du lien de parrainage : $e");
    }
    return null;
  }

  /// Rétrocompatibilité avec l'ancienne méthode `capturerCode`
  static String? capturerCode(Uri uri) {
    final ReferralData? data = capturerReferral(uri);
    return data?.id;
  }

  // ==========================================
  // 6. SAUVEGARDE TEMPORAIRE DU PARRAINAGE
  // ==========================================

  /// Sauvegarde le parrainage en attente localement (avant l'inscription/connexion effective de l'utilisateur)
  static Future<void> savePendingReferral(ReferralData referralData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingReferralTypeKey, referralData.type);
      await prefs.setString(_pendingReferralIdKey, referralData.id);

      // Si c'est un partenaire B2B, on enregistre les statistiques via un WriteBatch atomique (Phase 8 & Phase 9)
      if (referralData.type == 'partner') {
        try {
          final firestore = FirebaseFirestore.instance;
          final batch = firestore.batch();

          final partnerRef = firestore.collection('partenaires').doc(referralData.id);
          final scanRef = firestore.collection('partner_scans').doc();

          // PHASE 8 : Incrémentation du compteur global de scans
          batch.update(partnerRef, {
            'scan_count': FieldValue.increment(1),
          });

          // PHASE 9 : Enregistrement de l'historique détaillé
          batch.set(scanRef, {
            'partnerId': referralData.id,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'qr',
            'platform': defaultTargetPlatform.name,
          });

          await batch.commit();
          debugPrint("📈 Scan et historique enregistrés avec succès pour le partenaire : ${referralData.id}");
        } catch (e) {
          debugPrint("⚠️ Impossible d'enregistrer les statistiques Firestore (Batch) : $e");
        }
      }

      debugPrint("💾 Parrainage sauvegardé : ${referralData.toString()}");
    } catch (e) {
      debugPrint("Erreur lors de la sauvegarde du parrainage en attente : $e");
    }
  }

  /// Récupère le parrainage en attente stocké localement
  static Future<ReferralData?> getPendingReferral() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? type = prefs.getString(_pendingReferralTypeKey);
      final String? id = prefs.getString(_pendingReferralIdKey);

      if (type != null && id != null) {
        return ReferralData(type: type, id: id);
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération du parrainage en attente : $e");
    }
    return null;
  }

  /// Efface le parrainage en attente une fois qu'il a été traité / lié au compte utilisateur
  static Future<void> clearPendingReferral() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingReferralTypeKey);
      await prefs.remove(_pendingReferralIdKey);
      debugPrint("🧹 Parrainage en attente effacé des préférences locales.");
    } catch (e) {
      debugPrint("Erreur lors de la suppression du parrainage en attente : $e");
    }
  }
}