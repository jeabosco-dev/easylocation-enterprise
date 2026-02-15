// lib/widgets/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../screens/A_propos_de_nous_page.dart';
import '../screens/Aide_Et_Support_Page.dart';
import '../screens/onboarding_page.dart';
import 'package:easylocation_mvp/services/espace_staff_page.dart';
import 'delete_account_dialog.dart';
import '../providers/user_profile_provider.dart';
import '../screens/modification_profil_page.dart';
import 'bouton_signaler_abus.dart';
import 'bascule_role_widget.dart'; 

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // --- LOGIQUE DE DÉCONNEXION ---
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
                            await Provider.of<UserProfileProvider>(context, listen: false).signOut();
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

  void _showDeleteAccountDialog(BuildContext context) {
    final userProfile = Provider.of<UserProfileProvider>(context, listen: false);
    final roles = userProfile.userData?.roles ?? ['Utilisateur'];
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => DeleteAccountDialog(userRole: roles.join(', ')),
    );
  }

  void _openWhatsApp(BuildContext context) async {
    const whatsappNumber = '+243972129520';
    final url = Uri.parse('https://wa.me/$whatsappNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Consumer<UserProfileProvider>(
        builder: (context, userProfile, child) {
          final userData = userProfile.userData;

          if (userData == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Identité affichée
          String identiteAffichee = userData.prenom.trim().isNotEmpty 
              ? userData.prenom 
              : (userData.nom.trim().isNotEmpty ? userData.nom : 'Utilisateur');

          final String displayRoles = userData.roles.map((r) => r[0].toUpperCase() + r.substring(1)).join(' & ');

          return ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              // --- HEADER PERSONNALISÉ ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 50, left: 16, bottom: 20, right: 16),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PHOTO DE PROFIL
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      child: ClipOval(
                        child: userData.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: userData.imageUrl,
                                width: 72, height: 72, fit: BoxFit.cover,
                                placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                                errorWidget: (context, url, error) => const Icon(Icons.person, size: 40, color: Colors.grey),
                              )
                            : const Icon(Icons.person, size: 40, color: Colors.grey),
                      ),
                    ),
                    
                    const SizedBox(height: 15),

                    // NOM DE L'UTILISATEUR
                    Text(
                      identiteAffichee,
                      style: const TextStyle(
                        fontSize: 19, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white
                      ),
                    ),

                    const SizedBox(height: 4),

                    // EMAIL OU TÉLÉPHONE
                    Text(
                      userData.email ?? userData.telephone,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),

                    const SizedBox(height: 12),

                    // BADGE DES RÔLES
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        displayRoles,
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ WIDGET DE BASCULE COMPACT
              const BasculeRoleWidget(),

              const Divider(),

              // NAVIGATION
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier Mon profil'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ModificationProfilPage(role: userData.activeRole),
                  ));
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('À Propos de nous'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AProposDeNousPage()));
                },
              ),

              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Aide & Support'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AideSupportPage()));
                },
              ),
              
              const BoutonSignalerAbus(),

              ListTile(
                leading: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                title: const Text('Chatter avec EasyLocation', style: TextStyle(color: Colors.green)),
                onTap: () => _openWhatsApp(context),
              ),
              
              const Divider(),

              // --- NOUVELLE SECTION STAFF (DISCRÈTE) ---
              ListTile(
                leading: const Icon(Icons.business_center_outlined, color: Colors.blueGrey),
                title: const Text('Travailler avec nous'),
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EspaceStaffPage()),
                  );
                },
              ),

              const Divider(),

              // ACTIONS COMPTE
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Se déconnecter', style: TextStyle(color: Colors.red)),
                onTap: () => _showLogoutConfirmation(context),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                title: const Text('Supprimer mon compte', style: TextStyle(color: Colors.red)),
                onTap: () => _showDeleteAccountDialog(context),
              ),
            ],
          );
        },
      ),
    );
  }
}
