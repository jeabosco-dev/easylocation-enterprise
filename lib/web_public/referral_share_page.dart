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
    final typeToSave = widget.userId != null ? 'user' : (widget.partnerId != null ? 'partner' : null);
    
    if (codeToSave != null && codeToSave.isNotEmpty && typeToSave != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_referral_id', codeToSave);
        await prefs.setString('pending_referral_type', typeToSave);
        debugPrint('✅ Parrain stocké avec succès sur le web : $codeToSave (Type: $typeToSave)');
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "🎁 Vous avez été invité(e) par ${widget.userId ?? widget.partnerId} ! Téléchargez l'application pour activer votre bonus de bienvenue.",
                    style: const TextStyle(fontSize: 15, color: Color(0xFF1E5D8F), fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
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