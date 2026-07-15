import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// Importez vos pages nécessaires ici
import 'package:easylocation_mvp/screens/selection_role_page.dart';
import '../screens/profil_bailleur_page.dart';
import '../screens/profil_locataire_page.dart';
import '../screens/formulaire_de_mise_en_publication_page.dart';
import '../screens/onboarding_page.dart';
import '../providers/user_profile_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/verrou_code_conduite.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _checkIfFormWasInProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('form_in_progress') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!authSnapshot.hasData) return const OnboardingPage();

        return Selector<UserProfileProvider, String>(
          selector: (_, provider) => "${provider.userData?.uid ?? ''}-${provider.userData?.activeRole ?? ''}",
          builder: (context, combinedKey, child) {
            final profileProvider = context.read<UserProfileProvider>();
            final walletProvider = context.read<WalletProvider>();

            if (profileProvider.userData == null) {
              if (!profileProvider.isLoading) {
                scheduleMicrotask(() {
                  // Capture sécurisée du UID
                  final user = authSnapshot.data;
                  
                  if (user != null) {
                    final uid = user.uid;
                    debugPrint("AuthWrapper: Initialisation des services pour UID : $uid");
                    
                    profileProvider.loadUser(uid);
                    profileProvider.syncFCMToken(uid);
                    walletProvider.listenToWallet(uid);
                  } else {
                    debugPrint("AuthWrapper: Erreur, UID est null malgré la présence du snapshot.");
                  }
                });
              }
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 15),
                      Text("Chargement de votre profil EasyLocation...", 
                        style: TextStyle(fontWeight: FontWeight.w500)
                      ),
                    ],
                  ),
                ),
              );
            }

            final user = profileProvider.userData!;

            // Gestion staff
            List<String> rolesStaff = ['operations', 'tech_support', 'certificateur', 'logistique', 'admin', 'super_admin'];
            if (rolesStaff.contains(user.activeRole.toLowerCase())) {
              if (user.certification_conduite != true) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  VerrouCodeConduite.afficherEngagement(context, user.uid);
                });
              }
            }

            if (user.activeRole.isEmpty) return const SelectionRolePage();

            return FutureBuilder<bool>(
              future: _checkIfFormWasInProgress(),
              builder: (context, snapshot) {
                final formInProgress = snapshot.data ?? false;
                final String activeRole = user.activeRole.toLowerCase().trim();
                final List<dynamic> roles = user.roles ?? [];

                if (activeRole == 'bailleur') {
                  return formInProgress ? const FormulaireDeMiseEnPublicationPage() : const ProfilBailleurPage();
                }
                if (activeRole == 'locataire') return const ProfilLocatairePage();

                final bool estBailleur = roles.contains('bailleur');
                final bool estLocataire = roles.contains('locataire');

                if (estBailleur && estLocataire) return const SelectionRolePage();
                if (estBailleur) return formInProgress ? const FormulaireDeMiseEnPublicationPage() : const ProfilBailleurPage();
                if (estLocataire) return const ProfilLocatairePage();

                return const SelectionRolePage();
              },
            );
          },
        );
      },
    );
  }
}