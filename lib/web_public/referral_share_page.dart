// lib/web_public/referral_share_page.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String? _referrerName;
  bool _isLoadingName = true;

  @override
  void initState() {
    super.initState();
    _saveReferrerInfo();
    _fetchReferrerDetails();
  }

  /// Sauvegarde le parrain dans les SharedPreferences du navigateur
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

  /// Récupère le nom, prénom, et civilité depuis Firestore si c'est un utilisateur (userId)
  Future<void> _fetchReferrerDetails() async {
    try {
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        // CORRECTION : On pointe vers la collection 'utilisateurs'
        final docSnapshot = await FirebaseFirestore.instance
            .collection('utilisateurs')
            .doc(widget.userId)
            .get();

        if (docSnapshot.exists && docSnapshot.data() != null) {
          final data = docSnapshot.data()!;
          
          // Récupération des champs selon votre structure Firestore exacte
          final String nom = data['nom'] ?? data['lastName'] ?? '';
          final String prenom = data['prenom'] ?? data['firstName'] ?? '';
          final String genre = (data['genre'] ?? data['civilitie'] ?? data['sex'] ?? '').toString().toLowerCase();

          // Détermination de la civilité basée sur "Homme" / "Femme"
          String civilite = '';
          if (genre.contains('homme') || genre.contains('m') || genre == 'male') {
            civilite = 'M.';
          } else if (genre.contains('femme') || genre.contains('f') || genre == 'female') {
            civilite = 'Mme';
          }

          // Assemblage complet : Civilité + Prénom + Postnom + Nom (Nom en majuscules)
          final buffer = StringBuffer();
          if (civilite.isNotEmpty) buffer.write('$civilite ');
          if (prenom.isNotEmpty) buffer.write('$prenom ');
          if (nom.isNotEmpty) buffer.write(nom.toUpperCase());

          final fullName = buffer.toString().trim();

          if (fullName.isNotEmpty) {
            setState(() {
              _referrerName = fullName;
              _isLoadingName = false;
            });
            return;
          }
        }
      } else if (widget.partnerId != null && widget.partnerId!.isNotEmpty) {
        setState(() {
          _referrerName = "Partenaire ${widget.partnerId}";
          _isLoadingName = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la récupération du nom du parrain : $e');
    }

    // Fallback par défaut si non trouvé ou erreur
    setState(() {
      _referrerName = widget.userId ?? widget.partnerId;
      _isLoadingName = false;
    });
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
                  child: _isLoadingName
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          "🎁 Vous avez été invité(e) par ${_referrerName ?? 'un(e) ami(e)'} ! Téléchargez l'application pour activer votre bonus de bienvenue.",
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