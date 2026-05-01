// lib/services/referral_service.dart

import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';

class ReferralService {
  
  /// Base URL pour l'inscription (Deep Link)
  static const String _baseUrl = "https://easylocation-be28b.web.app/inscription";

  /// Génère le message de parrainage et ouvre le menu de partage
  /// [monCode] peut être l'UID (C2C) ou un ID Partenaire (B2B)
  static Future<void> partagerLien(String monCode) async {
    // 1. URL de destination avec le paramètre de référence
    final String lien = "$_baseUrl?ref=$monCode";
    
    // 2. Message formaté pour un impact maximum (Corrected & Professional)
    final String message = 
        "🏠 *Optimisez votre recherche immobilière avec EasyLocation Enterprise*\n\n"
        "Salut ! J'utilise cette application pour louer des maisons rapidement et en toute sécurité en RDC. "
        "Inscris-toi via mon lien pour bénéficier de leurs services et d'un bonus de bienvenue :\n\n"
        "👉 $lien\n\n"
        "🤝 *L'immobilier simplifié et sécurisé.*";

    try {
      await Share.share(
        message, 
        subject: "Invitation EasyLocation Enterprise"
      );
    } catch (e) {
      debugPrint("Erreur lors du partage : $e");
    }
  }

  /// Génère l'URL brute pour la création d'un QR Code physique
  /// Utile pour les agents "Hunters" qui installent des supports chez les partenaires
  static String genererLienPourQRCode(String partnerCode) {
    return "$_baseUrl?ref=$partnerCode";
  }

  /// Analyse l'URI (lorsque l'app est ouverte via un lien) pour extraire le code
  /// Identifie automatiquement s'il s'agit d'un partenaire (B2B) ou d'un utilisateur (C2C)
  static String? capturerCode(Uri uri) {
    try {
      String? code;
      
      // On vérifie 'ref' ou 'code'
      if (uri.queryParameters.containsKey('ref')) {
        code = uri.queryParameters['ref'];
      } else if (uri.queryParameters.containsKey('code')) {
        code = uri.queryParameters['code'];
      }

      if (code != null) {
        if (code.startsWith('PART-')) {
          debugPrint("🎯 Code Partenaire détecté : $code");
        } else {
          debugPrint("👤 Code Utilisateur détecté : $code");
        }
      }
      
      return code;
    } catch (e) {
      debugPrint("Erreur lors de la capture du code : $e");
    }
    return null;
  }
}