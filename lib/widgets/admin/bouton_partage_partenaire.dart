// lib/widgets/admin/bouton_partage_partenaire.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class BoutonPartagePartenaire extends StatefulWidget {
  final String partnerId;
  final Map<String, dynamic> partnerData;

  const BoutonPartagePartenaire({
    super.key,
    required this.partnerId,
    required this.partnerData,
  });

  @override
  State<BoutonPartagePartenaire> createState() =>
      _BoutonPartagePartenaireState();
}

class _BoutonPartagePartenaireState
    extends State<BoutonPartagePartenaire> {
  bool _isSharing = false;

  Future<void> _partager(BuildContext context) async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      final String nom =
          widget.partnerData['nom']?.toString() ?? 'Partenaire';
      
      // ✅ Récupération du numéro (déjà normalisé au format +243...)
      final String? phone = widget.partnerData['telephone']?.toString();

      final double commission =
          ((widget.partnerData['commission_rate'] ?? 0.0) as num)
              .toDouble() *
              100;

      final String qrCode =
          "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${widget.partnerId}";

      final String message =
          """🤝 *Bienvenue chez EasyLocation Enterprise !*

Cher partenaire *$nom*,

Votre compte partenaire B2B est désormais actif.

🔑 *Vos accès*

• ID Partenaire : ${widget.partnerId}
• Commission : ${commission.toStringAsFixed(0)}%

📱 Votre QR Code :

$qrCode

Merci de faire confiance à EasyLocation Enterprise.
""";

      // Mise à jour Firestore
      await FirebaseFirestore.instance
          .collection('partenaires')
          .doc(widget.partnerId)
          .update({
        'last_shared_at': FieldValue.serverTimestamp(),
      });

      // ---------- WEB / DESKTOP (avec numéro pré-rempli si disponible) ----------
      if (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux) {
        
        // Si on a un téléphone, on l'ajoute à l'URL, sinon on laisse vide
        final String phoneParam = phone != null ? "&phone=${phone.replaceAll('+', '')}" : "";
        final Uri whatsapp = Uri.parse(
          "https://wa.me/?text=${Uri.encodeComponent(message)}$phoneParam",
        );

        if (await canLaunchUrl(whatsapp)) {
          await launchUrl(
            whatsapp,
            mode: LaunchMode.externalApplication,
          );
        } else {
          throw Exception("Impossible d'ouvrir WhatsApp.");
        }
      }

      // ---------- ANDROID / IOS ----------
      else {
        await Share.share(
          message,
          subject: 'Accès Partenaire EasyLocation',
        );
      }
    } catch (e) {
      debugPrint("Erreur partage partenaire : $e");

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Le partage a échoué.\n$e",
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: "Partager les accès",
      onPressed: _isSharing ? null : () => _partager(context),
      icon: _isSharing
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : const Icon(
              Icons.share,
              color: Colors.green,
              size: 22,
            ),
    );
  }
}