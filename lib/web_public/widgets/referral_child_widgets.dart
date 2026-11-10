import 'package:flutter/material.dart';

/// ==========================================
/// 1. WIDGET ENFANT : En-tête / Logo
/// ==========================================
class ReferralHeader extends StatelessWidget {
  const ReferralHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E5D8F).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.card_giftcard_rounded, size: 72, color: Color(0xFF1E5D8F)),
        ),
        const SizedBox(height: 24),
        const Text(
          "Rejoignez EasyLocation !",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E5D8F)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// ==========================================
/// 2. WIDGET ENFANT : Carte d'état dynamique (Chargement vs Résultat)
/// ==========================================
class ReferralStatusCard extends StatelessWidget {
  final bool isLoadingName;
  final bool isSlowConnection;
  final String? referrerName;
  final String currentHint;

  const ReferralStatusCard({
    super.key,
    required this.isLoadingName,
    required this.isSlowConnection,
    required this.referrerName,
    required this.currentHint,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: isLoadingName
          ? Container(
              key: const ValueKey('loading_card'),
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF1E5D8F),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      currentHint,
                      key: ValueKey(currentHint),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isSlowConnection) ...[
                    const SizedBox(height: 10),
                    const Text(
                      "⚡ Connexion un peu lente... Vous pouvez quand même télécharger l'application ci-dessous !",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ]
                ],
              ),
            )
          : Container(
              key: const ValueKey('loaded_card'),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E5D8F).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E5D8F).withOpacity(0.2)),
              ),
              child: Text(
                referrerName != null
                    ? "🎁 Vous avez été invité(e) par $referrerName ! Téléchargez l'application pour activer votre bonus de bienvenue."
                    : "🎁 Vous avez été invité(e) à rejoindre EasyLocation ! Téléchargez l'application pour activer votre bonus de bienvenue.",
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1E5D8F),
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
    );
  }
}

/// ==========================================
/// 3. WIDGET ENFANT : Pied de page explicatif et bouton d'action
/// ==========================================
class ReferralFooter extends StatelessWidget {
  final VoidCallback onDownloadPressed;

  const ReferralFooter({
    super.key,
    required this.onDownloadPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          "Installez l'application mobile EasyLocation pour simplifier vos recherches de logements, trouver un bien ou gérer vos locations en toute sécurité.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.5, color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onDownloadPressed,
            icon: const Icon(Icons.get_app_rounded, size: 22),
            label: const Text("Cliquez ici pour télécharger l'application"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E5D8F),
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}