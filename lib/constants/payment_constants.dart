import 'package:flutter/material.dart';

/// ✅ CONFIGURATION DES SERVICES DE PAIEMENT (EasyLocation Enterprise)
/// Centralisation des endpoints et identifiants pour les passerelles de paiement.

class MaxicashConfig {
  static const String merchantId = "6452863fb5004eafa3ce77e27fb55376";
  
  static const String gatewayUrl = "https://api-testbed.maxicashme.com/PayEntryPost";
  
  static const String successUrl = "https://easylocation-be28b.web.app/success";
  
  static const String cancelUrl = "https://easylocation-be28b.web.app/cancel";
}

/// Ajoutez ici d'autres configurations de paiement (ex: Stripe, Mobile Money)
/// si nécessaire pour une future extension.