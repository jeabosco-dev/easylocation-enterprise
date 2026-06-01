// lib/screens/selection_role_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/screens/onboarding_page.dart';
import 'dart:developer';

// ✅ Importation requise pour résoudre l'erreur de compilation sur AuthWrapper
import 'package:easylocation_mvp/widgets/auth_wrapper.dart';

final ValueNotifier<bool> _isProcessing = ValueNotifier<bool>(false);

class SelectionRolePage extends StatelessWidget {
  const SelectionRolePage({super.key});

  /// Affiche une boîte de dialogue pour confirmer la déconnexion
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool isLoggingOut = false;
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text("Confirmation"),
              content: const Text("Voulez-vous vraiment vous déconnecter ?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Annuler"),
                ),
                TextButton(
                  onPressed: isLoggingOut
                      ? null
                      : () async {
                          setInnerState(() => isLoggingOut = true);
                          try {
                            final userProvider = Provider.of<UserProfileProvider>(context, listen: false);
                            await userProvider.signOut();
                            
                            if (!context.mounted) return;
                            
                            Navigator.of(dialogContext).pop();
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const OnboardingPage()),
                              (route) => false,
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  child: isLoggingOut 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text("Se déconnecter", style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<UserProfileProvider>(
      builder: (context, userProfileProvider, child) {
        
        final userData = userProfileProvider.userData;
        final String? imageUrl = userData?.imageUrl;

        final String displayName = (userData?.prenom != null && userData!.prenom.isNotEmpty)
            ? userData.prenom
            : (userData?.nom != null && userData!.nom.isNotEmpty)
                ? userData.nom
                : 'Utilisateur';

        /// ✅ LOGIQUE DE NAVIGATION ENTIÈREMENT SÉCURISÉE CONTRE LES FLUX ASYNCHRONES
        Future<void> _selectAndNavigate(String role) async {
          _isProcessing.value = true;
          try {
            log("🚀 Sélection du rôle et verrouillage Firestore : $role");
            
            // 1. On applique d'abord le rôle de façon atomique
            await userProfileProvider.setActiveRole(role); 

            if (!context.mounted) return;

            // 2. CORRECTION : On bascule IMMÉDIATEMENT sur un écran neutre (AuthWrapper) 
            // pour couper net les Streams et les Widgets de l'ancienne vue locataire/bailleur.
            // La pause de transition de 300ms s'effectue PENDANT que l'arbre est déjà propre.
            Navigator.of(context).pushAndRemoveUntil(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 300), // Synchronisé avec la pause visuelle
              ),
              (route) => false,
            );

            // 3. Laisse le moteur graphique respirer après la destruction complète de la structure de page précédente
            await Future.delayed(const Duration(milliseconds: 100));

          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur de configuration : ${e.toString()}')),
              );
            }
          } finally {
            _isProcessing.value = false;
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sélection du profil', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                onPressed: () => _showLogoutConfirmation(context),
                icon: const Icon(Icons.exit_to_app_rounded, color: Colors.blue), 
                tooltip: 'Déconnexion',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 10.0, 24.0, 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10), 

                if (imageUrl != null && imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    imageBuilder: (context, imageProvider) => CircleAvatar(
                      radius: 50,
                      backgroundImage: imageProvider,
                      backgroundColor: Colors.grey.shade200,
                    ),
                    placeholder: (context, url) => const CircleAvatar(
                      radius: 50,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => const CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50, color: Colors.grey),
                    ),
                  )
                else
                  Icon(
                    Icons.account_circle_outlined,
                    size: 100,
                    color: theme.colorScheme.primary,
                  ),

                const SizedBox(height: 20),
                
                Text(
                  'Bonjour $displayName !',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                const Text(
                  'Comment souhaitez-vous utiliser EasyLocation aujourd\'hui ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 35), 

                ValueListenableBuilder<bool>(
                  valueListenable: _isProcessing,
                  builder: (context, isLoading, child) {
                    if (isLoading) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 15),
                            Text("Initialisation de votre profil...", 
                                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blue)),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: [
                        _RoleCard(
                          title: 'Espace Locataire',
                          subtitle: 'Je cherche un logement',
                          icon: Icons.person_search_outlined, 
                          color: const Color(0xFF1E5D8F),
                          onTap: () => _selectAndNavigate('locataire'),
                        ),
                        const SizedBox(height: 16),
                        _RoleCard(
                          title: 'Espace Bailleur',
                          subtitle: 'Je gère mes biens immobiliers',
                          icon: Icons.real_estate_agent, 
                          color: const Color(0xFF8C387C),
                          onTap: () => _selectAndNavigate('bailleur'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}