// lib/web_public/referral_share_page.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Page Web publique affichée lorsqu'on clique sur un lien de parrainage sans avoir l'app
class WebPublicReferralPage extends StatefulWidget {
  final String? partnerId;
  final String? userId;

  const WebPublicReferralPage({
    super.key,
    this.partnerId,
    this.userId,
  });

  @override
  State<WebPublicReferralPage> createState() => _WebPublicReferralPageState();
}

class _WebPublicReferralPageState extends State<WebPublicReferralPage> {
  @override
  void initState() {
    super.initState();
    _saveReferrerInfo();
  }

  Future<void> _saveReferrerInfo() async {
    final codeToSave = widget.userId ?? widget.partnerId;
    if (codeToSave != null && codeToSave.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_referrer_id', codeToSave);
        debugPrint('✅ Parrain stocké avec succès sur le web : $codeToSave');
      } catch (e) {
        debugPrint('⚠️ Erreur lors de la sauvegarde du parrain : $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const playStoreUrl = "https://play.google.com/store/apps/details?id=com.easylocation.app";
    
    final bool hasReference = (widget.partnerId != null && widget.partnerId!.isNotEmpty) || 
                              (widget.userId != null && widget.userId!.isNotEmpty);

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