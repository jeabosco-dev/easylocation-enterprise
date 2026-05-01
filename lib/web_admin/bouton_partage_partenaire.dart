import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

class BoutonPartagePartenaire extends StatelessWidget {
  final String partnerId;
  final Map<String, dynamic> partnerData;

  const BoutonPartagePartenaire({
    super.key,
    required this.partnerId,
    required this.partnerData,
  });

  Future<void> _partager(BuildContext context) async {
    final String nom = partnerData['nom'] ?? 'Partenaire';
    final double commission = ((partnerData['commission_rate'] ?? 0.0) * 100);
    
    // --- CONSTRUCTION DU MESSAGE (INSPIRÉ DE VOTRE STYLE) ---
    String message = "🤝 *Bienvenue chez EasyLocation Enterprise !*\n\n"
        "Cher partenaire *$nom*,\n"
        "Votre compte partenaire B2B est désormais actif sur notre plateforme.\n\n"
        "🔑 *Vos accès sécurisés :*\n"
        "• ID Partenaire : `$partnerId`\n"
        "• Commission : *$commission%* par conversion.\n\n"
        "📲 *Prochaines étapes :*\n"
        "1. Utilisez cet ID pour lier votre compte dans l'application.\n"
        "2. Présentez votre QR Code personnel à vos clients.\n\n"
        "🖼️ *Lien direct vers votre QR Code :*\n"
        "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$partnerId\n\n"
        "🚀 *Ensemble, modernisons l'immobilier en Afrique !*";

    try {
      // Optionnel : Vous pouvez aussi incrémenter un compteur de partages si vous en créez un dans Firestore
      await FirebaseFirestore.instance
          .collection('partenaires')
          .doc(partnerId)
          .update({'last_shared_at': FieldValue.serverTimestamp()});

      // Lancement du partage
      await Share.share(message);
      
    } catch (e) {
      debugPrint("Erreur lors du partage partenaire: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // On utilise un format compact pour l'intégrer facilement dans un DataTable ou une Liste
    return IconButton(
      icon: const Icon(Icons.share, color: Colors.green, size: 22),
      onPressed: () => _partager(context),
      tooltip: "Partager les accès",
      splashRadius: 24,
    );
  }
}