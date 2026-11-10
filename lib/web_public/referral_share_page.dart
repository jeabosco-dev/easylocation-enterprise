import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importation des widgets enfants depuis leur fichier dédié
import 'widgets/referral_child_widgets.dart';

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
  bool _isSlowConnection = false;
  
  // Animation des messages d'attente
  int _currentHintIndex = 0;
  Timer? _hintTimer;
  Timer? _slowTimeoutTimer;

  final List<String> _valueHints = [
    "Recherche du nom de votre parrain...",
    "EasyLocation : Trouvez facilement votre logement idéal.",
    "Consultez les photos et caractéristiques des biens.",
    "Comparez les offres avant de vous déplacer.",
    "Préparation de votre bonus de bienvenue..."
  ];

  /// Centralisation de la sélection et de la validation de l'identifiant de parrainage
  String? get _referralId {
    final userId = widget.userId?.trim();
    if (userId != null && userId.isNotEmpty) {
      return userId;
    }

    final partnerId = widget.partnerId?.trim();
    if (partnerId != null && partnerId.isNotEmpty) {
      return partnerId;
    }

    return null;
  }

  /// Centralisation de la détermination du type de parrain ('user' ou 'partner')
  String? get _referralType {
    final userId = widget.userId?.trim();
    if (userId != null && userId.isNotEmpty) {
      return 'user';
    }

    final partnerId = widget.partnerId?.trim();
    if (partnerId != null && partnerId.isNotEmpty) {
      return 'partner';
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _saveReferrerInfo();
    _startHintAnimation();
    _fetchReferrerDetails();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _slowTimeoutTimer?.cancel();
    super.dispose();
  }

  /// Fait défiler les messages d'accueil et gère le cas de connexion lente (8s max)
  void _startHintAnimation() {
    _hintTimer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (mounted && _isLoadingName) {
        setState(() {
          _currentHintIndex = (_currentHintIndex + 1) % _valueHints.length;
        });
      }
    });

    // Si après 8 secondes Firestore n'a pas répondu, on affiche un message rassurant sans tout bloquer
    _slowTimeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _isLoadingName) {
        setState(() {
          _isSlowConnection = true;
        });
      }
    });
  }

  /// Sauvegarde le parrain dans les SharedPreferences du navigateur
  Future<void> _saveReferrerInfo() async {
    final codeToSave = _referralId;
    final typeToSave = _referralType;
    
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

  /// Construit l'URL du Play Store en injectant le referrer pour la capture post-installation
  String _buildPlayStoreUrl() {
    final code = _referralId;
    final type = _referralType ?? 'partner';

    if (code == null || code.isEmpty) {
      const defaultUrl = "https://play.google.com/store/apps/details?id=com.easylocation.app";
      debugPrint('[REFERRAL_DIAGNOSTIC] URL Play Store générée : $defaultUrl');
      return defaultUrl;
    }

    final referrerQuery = Uri(
      queryParameters: {
        'ref_id': code,
        'ref_type': type,
      },
    ).query;

    final url = Uri.https(
      'play.google.com',
      '/store/apps/details',
      {
        'id': 'com.easylocation.app',
        'referrer': referrerQuery,
      },
    ).toString();

    debugPrint('[REFERRAL_DIAGNOSTIC] URL Play Store générée : $url');
    return url;
  }

  /// Récupère, gère la civilité (correction homme/femme) et masque le nom
  Future<void> _fetchReferrerDetails() async {
    try {
      final currentUserId = widget.userId?.trim();
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('utilisateurs')
            .doc(currentUserId)
            .get()
            .timeout(const Duration(seconds: 7));

        if (!mounted) return;

        if (docSnapshot.exists && docSnapshot.data() != null) {
          final data = docSnapshot.data()!;
          
          final String nom = data['nom'] ?? data['lastName'] ?? '';
          final String prenom = data['prenom'] ?? data['firstName'] ?? '';
          final String genreRaw = (data['genre'] ?? data['civilitie'] ?? data['sex'] ?? '').toString().toLowerCase().trim();

          String civilite = '';
          if (genreRaw == 'm' || genreRaw == 'homme' || genreRaw == 'male' || genreRaw.startsWith('h')) {
            civilite = 'M.';
          } else if (genreRaw == 'f' || genreRaw == 'femme' || genreRaw == 'female') {
            civilite = 'Mme';
          }

          if (prenom.isNotEmpty) {
            String maskedPrenom = prenom.length > 3 
                ? "${prenom.substring(0, 3)}${'*'.padLeft(prenom.length - 3, '*')}" 
                : prenom;
            
            String maskedNom = nom.isNotEmpty ? "${nom[0]}." : "";

            final buffer = StringBuffer();
            if (civilite.isNotEmpty) buffer.write('$civilite ');
            buffer.write('$maskedPrenom ');
            if (maskedNom.isNotEmpty) buffer.write(maskedNom);

            final maskedFullName = buffer.toString().trim();

            if (maskedFullName.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _referrerName = maskedFullName;
                  _isLoadingName = false;
                });
              }
              return;
            }
          }
        }
      } else {
        final currentPartnerId = widget.partnerId?.trim();
        if (currentPartnerId != null && currentPartnerId.isNotEmpty) {
          if (mounted) {
            setState(() {
              _referrerName = "Partenaire $currentPartnerId";
              _isLoadingName = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erreur ou délai dépassé pour le nom du parrain : $e');
    }

    if (mounted) {
      setState(() {
        _referrerName = null;
        _isLoadingName = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasReference = _referralId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("EasyLocation • Invitation"),
        backgroundColor: const Color(0xFF1E5D8F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 550),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Appel du Widget Enfant : En-tête / Logo
                const ReferralHeader(),
                const SizedBox(height: 16),

                // 2. Appel du Widget Enfant : Carte d'état dynamique
                if (hasReference)
                  ReferralStatusCard(
                    isLoadingName: _isLoadingName,
                    isSlowConnection: _isSlowConnection,
                    referrerName: _referrerName,
                    currentHint: _valueHints[_currentHintIndex],
                  ),

                const SizedBox(height: 28),

                // 3. Appel du Widget Enfant : Pied de page et bouton d'action
                ReferralFooter(
                  onDownloadPressed: () async {
                    final playStoreUrl = _buildPlayStoreUrl();
                    final uri = Uri.parse(playStoreUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}