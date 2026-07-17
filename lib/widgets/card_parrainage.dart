// lib/widgets/card_parrainage.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart'; 
import '../providers/user_profile_provider.dart';
import '../services/referral_service.dart';
import '../services/config_service.dart';

class CardParrainage extends StatelessWidget {
  const CardParrainage({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. On récupère la configuration dynamique
    final config = context.watch<ConfigService>();
    
    // 2. On récupère les données de l'utilisateur pour l'UID
    final userProvider = context.watch<UserProfileProvider>();
    final String? monUid = userProvider.userData?.uid;

    // SÉCURITÉ : Si le module est désactivé ou pas d'utilisateur connecté
    if (!config.isReferralActive || monUid == null || monUid.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: Colors.blue[50],
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.card_giftcard, color: Colors.blue, size: 28),
                ),
              ),
              title: Text(
                "Gagnez jusqu'à ${config.referralReferrerReward.toStringAsFixed(0)}\$ de bonus",
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16, 
                  color: Colors.blue
                ),
              ),
              subtitle: const Text(
                "Invitez un ami ou un partenaire à rejoindre l'aventure.",
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Bouton 1 : Partage Digital (WhatsApp, etc.)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ReferralService.partagerLien(monUid),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text("PARTAGER"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Bouton 2 : QR Code Physique (Pour le terrain)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showQRCodeDialog(context, monUid),
                    icon: const Icon(Icons.qr_code),
                    label: const Text("MON QR"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Affiche une boîte de dialogue avec le QR Code pour un scan immédiat
  void _showQRCodeDialog(BuildContext context, String code) {
    final String link = ReferralService.genererLienPourQRCode(code);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Scan Rapide", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Faites scanner ce code à votre contact pour l'enregistrer instantanément.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: link,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.blue),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              code,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("FERMER"),
          ),
        ],
      ),
    );
  }
}