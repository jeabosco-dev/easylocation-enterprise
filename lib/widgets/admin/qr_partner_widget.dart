import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrPartnerWidget extends StatelessWidget {
  final String partnerId;
  final String partnerName;

  const QrPartnerWidget({
    super.key,
    required this.partnerId,
    required this.partnerName,
  });

  @override
  Widget build(BuildContext context) {
    final String referralUrl = "https://easylocation.app/referral?partner=$partnerId";

    return AlertDialog(
      title: const Text("QR Code Partenaire", textAlign: TextAlign.center),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              partnerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(partnerId, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: QrImageView(
                data: referralUrl,
                version: QrVersions.auto,
                size: 200.0,
                padding: const EdgeInsets.all(0),
                // --- AJOUT DU LOGO AU CENTRE ---
                embeddedImage: const AssetImage('assets/images/logo.png'),
                embeddedImageStyle: QrEmbeddedImageStyle(
                  size: const Size(40, 40), // Taille du logo au centre
                ),
              ),
            ),
            const SizedBox(height: 15),
            SelectableText(
              referralUrl,
              style: const TextStyle(fontSize: 10, color: Colors.blueAccent),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("FERMER"),
        ),
      ],
    );
  }
}