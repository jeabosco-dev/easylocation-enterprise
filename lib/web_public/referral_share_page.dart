// lib/web_public/referral_share_page.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Page Web publique affichée lorsqu'on clique sur un lien de parrainage sans avoir l'app
class WebPublicReferralPage extends StatelessWidget {
  final String? partnerId;
  final String? userId;

  const WebPublicReferralPage({
    super.key,
    this.partnerId,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    const playStoreUrl = "https://play.google.com/store/apps/details?id=com.easylocation.app";
    
    final bool hasReference = (partnerId != null && partnerId!.isNotEmpty) || (userId != null && userId!.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text("EasyLocation - Parrainage"),
        backgroundColor: const Color(0xFF1E5D8F),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.card_giftcard_rounded, size: 80, color: Color(0xFF1E5D8F)),
              const SizedBox(height: 20),
              const Text(
                "Rejoignez EasyLocation !",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              if (hasReference)
                const Text(
                  "Vous avez été invité(e) à rejoindre la plateforme par un proche ou un partenaire.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 30),
              const Text(
                "Installez l'application mobile EasyLocation pour profiter de tous nos services, simplifier vos recherches de biens ou gérer vos locations.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(playStoreUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text("Télécharger l'application (Play Store)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E5D8F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}