// lib/services/referral_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Structure représentant les données d'un parrainage capturé via un lien profond
class ReferralData {
  final String type; // "partner" ou "user"
  final String id;   // L'ID du partenaire ou l'UID de l'utilisateur

  ReferralData({required this.type, required this.id});

  @override
  String toString() => 'ReferralData(type: $type, id: $id)';
}

class ReferralService {
  static const String _baseUrl = "https://easylocation-be28b.web.app/referral";

  static const String _pendingReferralTypeKey = 'pending_referral_type';
  static const String _pendingReferralIdKey = 'pending_referral_id';

  static String genererLienPartenaire(String partnerId) => "$_baseUrl?partner=$partnerId";
  static String genererLienUtilisateur(String uid) => "$_baseUrl?user=$uid";
  static String genererLienPourQRCode(String partnerCode) => genererLienPartenaire(partnerCode);

  static String genererMessagePartenaire(String partnerId, {String? partnerName}) {
    final String lien = genererLienPartenaire(partnerId);
    final String nomAffiche = (partnerName != null && partnerName.isNotEmpty) ? partnerName : "notre partenaire";
    return "🏠 *Bienvenue sur EasyLocation Enterprise*\n\nRejoignez la plateforme recommandée par $nomAffiche...\n\n👉 $lien";
  }

  static String genererMessageUtilisateur(String uid) {
    final String lien = genererLienUtilisateur(uid);
    return "🚀 *La fin des galères immobilières en RDC !*\n\n"
        "Salut ! J'utilise *EasyLocation Enterprise* pour chercher, louer ou gérer mes biens sans stress :\n\n"
        "🛑 *Fini les déplacements inutiles :* Tout se fait depuis l'app (photos et vidéos de visite virtuelle HD).\n"
        "💰 *Économies massives :* Frais de service réduits à 10-20% d'un seul mois de loyer (au lieu de 60 à 100% ailleurs !).\n"
        "🚗 *Transport offert :* Prise en charge gratuite par l'entreprise pour la visite finale du bien.\n"
        "🔍 *Transparence & Rapidité :* Fini les coûts cachés, trouvez ou louez un locataire qualifié en un temps record.\n\n"
        "Inscris-toi dès maintenant via mon lien exclusif pour profiter de l'expérience et de ton bonus de bienvenue :\n\n"
        "👉 $lien\n\n"
        "✨ *EasyLocation : Une autre manière moderne de vivre l'immobilier.*";
  }

  static Future<void> partagerLienPartenaire(String partnerId, {String? partnerName}) async {
    try {
      await Share.share(genererMessagePartenaire(partnerId, partnerName: partnerName), subject: "Invitation Partenaire");
    } catch (e) {
      debugPrint("❌ Erreur partage partenaire : $e");
    }
  }

  static Future<void> partagerLienUtilisateur(String uid) async {
    try {
      await Share.share(genererMessageUtilisateur(uid), subject: "Invitation EasyLocation");
    } catch (e) {
      debugPrint("❌ Erreur partage utilisateur : $e");
    }
  }

  static Future<void> partagerLien(String monCode) async {
    if (monCode.startsWith('PART-')) {
      await partagerLienPartenaire(monCode);
    } else {
      await partagerLienUtilisateur(monCode);
    }
  }

  static Future<Map<String, dynamic>?> getPartner(String partnerId) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('partenaires').doc(partnerId).get();
      if (docSnapshot.exists) return docSnapshot.data();
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('partenaires')
          .where('partnerId', isEqualTo: partnerId)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) return querySnapshot.docs.first.data();
    } catch (e) {
      debugPrint("❌ Erreur getPartner $partnerId : $e");
    }
    return null;
  }

  /// Analyse l'URI reçue à l'ouverture de l'application
  static ReferralData? capturerReferral(Uri uri) {
    debugPrint("🔍 [REFERRAL_SVC] Analyse de l'URI reçue : ${uri.toString()}");
    try {
      if (uri.queryParameters.containsKey('partner')) {
        final String partnerId = uri.queryParameters['partner']!;
        debugPrint("🎯 [REFERRAL_SVC] Code Partenaire B2B détecté dans l'URI : $partnerId");
        return ReferralData(type: 'partner', id: partnerId);
      } 
      
      if (uri.queryParameters.containsKey('user')) {
        final String userId = uri.queryParameters['user']!;
        debugPrint("👤 [REFERRAL_SVC] Code Utilisateur C2C détecté dans l'URI : $userId");
        return ReferralData(type: 'user', id: userId);
      }

      String? legacyCode;
      if (uri.queryParameters.containsKey('ref')) {
        legacyCode = uri.queryParameters['ref'];
      } else if (uri.queryParameters.containsKey('code')) {
        legacyCode = uri.queryParameters['code'];
      }

      if (legacyCode != null && legacyCode.isNotEmpty) {
        if (legacyCode.startsWith('PART-')) {
          debugPrint("🎯 [REFERRAL_SVC] Code Partenaire (Legacy) détecté : $legacyCode");
          return ReferralData(type: 'partner', id: legacyCode);
        } else {
          debugPrint("👤 [REFERRAL_SVC] Code Utilisateur (Legacy) détecté : $legacyCode");
          return ReferralData(type: 'user', id: legacyCode);
        }
      }
    } catch (e) {
      debugPrint("❌ [REFERRAL_SVC] Erreur lors de l'analyse de l'URI : $e");
    }
    debugPrint("⚠️ [REFERRAL_SVC] Aucun paramètre de parrainage trouvé dans cette URI.");
    return null;
  }

  static String? capturerCode(Uri uri) {
    final ReferralData? data = capturerReferral(uri);
    return data?.id;
  }

  /// Sauvegarde le parrainage en attente localement
  static Future<void> savePendingReferral(ReferralData referralData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingReferralTypeKey, referralData.type);
      await prefs.setString(_pendingReferralIdKey, referralData.id);
      debugPrint("💾 [REFERRAL_SVC] Parrainage sauvegardé localement -> Type: ${referralData.type}, ID: ${referralData.id}");

      if (referralData.type == 'partner') {
        try {
          final firestore = FirebaseFirestore.instance;
          final batch = firestore.batch();
          final partnerRef = firestore.collection('partenaires').doc(referralData.id);
          final scanRef = firestore.collection('partner_scans').doc();

          batch.update(partnerRef, {'scan_count': FieldValue.increment(1)});
          batch.set(scanRef, {
            'partnerId': referralData.id,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'qr',
            'platform': defaultTargetPlatform.name,
          });

          await batch.commit();
          debugPrint("📈 [REFERRAL_SVC] Scan partenaire enregistré dans Firestore : ${referralData.id}");
        } catch (e) {
          debugPrint("⚠️ [REFERRAL_SVC] Erreur batch Firestore partenaire : $e");
        }
      }
    } catch (e) {
      debugPrint("❌ [REFERRAL_SVC] Erreur sauvegarde SharedPreferences : $e");
    }
  }

  /// Récupère le parrainage en attente stocké localement
  static Future<ReferralData?> getPendingReferral() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? type = prefs.getString(_pendingReferralTypeKey);
      final String? id = prefs.getString(_pendingReferralIdKey);

      debugPrint("🔍 [REFERRAL_SVC] Lecture SharedPreferences getPendingReferral -> Type: $type, ID: $id");

      if (type != null && id != null) {
        return ReferralData(type: type, id: id);
      }
    } catch (e) {
      debugPrint("❌ [REFERRAL_SVC] Erreur lecture SharedPreferences getPendingReferral : $e");
    }
    debugPrint("⚠️ [REFERRAL_SVC] getPendingReferral : Aucune donnée trouvée en local.");
    return null;
  }

  /// Efface le parrainage en attente
  static Future<void> clearPendingReferral() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingReferralTypeKey);
      await prefs.remove(_pendingReferralIdKey);
      debugPrint("🧹 [REFERRAL_SVC] Parrainage en attente effacé des préférences locales.");
    } catch (e) {
      debugPrint("❌ [REFERRAL_SVC] Erreur clearPendingReferral : $e");
    }
  }
}