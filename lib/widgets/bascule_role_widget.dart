// lib/widgets/bascule_role_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/main.dart';
// Remplace 'your_path' par le chemin réel de ton fichier de constantes
import 'package:easylocation_mvp/constants/constants.dart';

class BasculeRoleWidget extends StatefulWidget {
  const BasculeRoleWidget({super.key});

  @override
  State<BasculeRoleWidget> createState() => _BasculeRoleWidgetState();
}

class _BasculeRoleWidgetState extends State<BasculeRoleWidget> {
  bool _isSwitching = false;

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<UserProfileProvider>();
    final userData = profileProvider.userData;

    // Si pas de données ou un seul rôle, on n'affiche rien
    if (userData == null || userData.roles.length < 2) {
      return const SizedBox.shrink();
    }

    // Utilisation de la constante pour la comparaison
    final bool estActuellementLocataire = userData.activeRole == UserRoles.tenant;
    
    // On définit la couleur de la destination (ce qu'on va DEVENIR)
    final Color couleurCible = estActuellementLocataire 
        ? const Color(0xFF8C387C) // Vers Bailleur (Violet)
        : const Color(0xFF1E5D8F); // Vers Locataire (Bleu)

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSwitching ? null : () => _handleSwitch(profileProvider, estActuellementLocataire),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _isSwitching ? couleurCible.withOpacity(0.2) : couleurCible.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: couleurCible.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  estActuellementLocataire ? Icons.real_estate_agent : Icons.person_pin,
                  color: couleurCible,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    estActuellementLocataire ? "Passer en Mode Bailleur" : "Passer en Mode Locataire",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: couleurCible,
                    ),
                  ),
                ),
                if (_isSwitching)
                  SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: couleurCible),
                  )
                else
                  Icon(Icons.sync, color: couleurCible.withOpacity(0.5), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSwitch(UserProfileProvider provider, bool estLocataireActuellement) async {
    if (_isSwitching) return;

    setState(() => _isSwitching = true);
    
    // Utilisation des constantes pour définir le nouveau rôle
    final nouveauRole = estLocataireActuellement ? UserRoles.landlord : UserRoles.tenant;
    
    try {
      // 1. Mise à jour du rôle dans le Provider et Firestore
      await provider.setActiveRole(nouveauRole);
      
      if (!mounted) return;

      // 2. ÉTAPE CRUCIALE : On ferme le Drawer s'il est ouvert
      if (Navigator.canPop(context)) {
        Navigator.pop(context); 
      }

      // 3. Navigation vers AuthWrapper en nettoyant toute la pile
      await Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(), 
          transitionsBuilder: (context, anim, secAnim, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSwitching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors du changement de rôle : $e")),
        );
      }
    }
  }
}
