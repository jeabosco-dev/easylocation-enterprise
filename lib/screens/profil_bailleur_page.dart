// lib/screens/profil_bailleur_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// Importations des pages
import 'package:easylocation_mvp/screens/formulaire_de_mise_en_publication_page.dart';
import 'package:easylocation_mvp/screens/maisons_publiees_page.dart';
import 'package:easylocation_mvp/screens/gestion_proprietes_page.dart';
import 'package:easylocation_mvp/screens/mes_locataires_page.dart';
import 'package:easylocation_mvp/screens/suivi_locations_bailleur_page.dart';

// Importations des composants et services
import '../widgets/app_drawer.dart';
import '../widgets/entete_profil_widget.dart';
import '../widgets/activites_recentes_bailleur_widget.dart';
import '../widgets/wallet_status_card.dart';
import '../providers/user_profile_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/config_service.dart';
import '../models/user_model.dart';
import '../widgets/card_parrainage.dart';
import '../widgets/espace_partenaire_widget.dart';

// Importations des constantes globales
import 'package:easylocation_mvp/constants/all_constants.dart';

// NOUVEAUX WIDGETS SERVICES
import '../widgets/mes_commandes_services_widget.dart';
import 'package:easylocation_mvp/widgets/services_carousel_widget.dart';

class ProfilBailleurPage extends StatefulWidget {
  const ProfilBailleurPage({super.key});

  @override
  State<ProfilBailleurPage> createState() => _ProfilBailleurPageState();
}

class _ProfilBailleurPageState extends State<ProfilBailleurPage> {
  Future<void> _handleRefresh(BuildContext context, String uid) async {
    // Utilisation de .read pour ne pas écouter les changements durant le refresh
    await context.read<UserProfileProvider>().loadUser(uid);
    await context.read<WalletProvider>().refreshAll(uid);
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUserFirebase = FirebaseAuth.instance.currentUser;

    if (currentUserFirebase == null) {
      return const Scaffold(
        body: Center(child: Text("Authentification requise...")),
      );
    }

    return Consumer<UserProfileProvider>(
      builder: (context, userProfile, child) {
        final UserModel? userData = userProfile.userData;
        final bool isLoading = userProfile.isLoading;

        if (isLoading || userData == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final String uid = userData.uid;

        // Note : Le listener du Wallet est maintenant géré uniquement dans AuthWrapper.

        return Scaffold(
          backgroundColor: Colors.grey[50],
          drawer: const AppDrawer(),
          appBar: AppBar(
            title: const Text('Tableau de Bord',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            centerTitle: true,
          ),
          body: RefreshIndicator(
            onRefresh: () => _handleRefresh(context, uid),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. ENTÊTE
                  EnteteProfilWidget(
                    nom: userData.nom,
                    prenom: userData.prenom,
                    genre: userData.genre,
                    imageUrl: userData.imageUrl,
                    isVerified: userData.isVerified,
                    typeEspace: "Bailleur",
                  ),

                  // 2. WALLET
                  const WalletStatusCard(),
                  const SizedBox(height: 15),

                  // 3. COMMANDES SERVICES
                  MesCommandesServicesWidget(userId: uid),

                  const SizedBox(height: 25),

                  // 4. BOUTONS D'ACTION PRINCIPAUX
                  _buildMainLargeButtons(context),

                  const SizedBox(height: 25),

                  // 5. GRILLE D'ACTIONS SECONDAIRES
                  _buildActionGrid(context),

                  const SizedBox(height: 30),

                  // 6. SERVICES MAINTENANCE
                  const Padding(
                    padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Services de maintenance",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("Préparez vos maisons pour les futurs locataires",
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  const ServicesCarouselWidget(provenance: 'PROFIL_BAILLEUR'),

                  const SizedBox(height: 30),

                  // 7. ACTIVITÉS RÉCENTES
                  ActivitesRecentesBailleurWidget(bailleurId: uid),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- UI HELPERS ---

  Widget _buildMainLargeButtons(BuildContext context) {
    return Column(
      children: [
        _buildFullWidthButton(
          context,
          label: "Ajouter une Propriété",
          icon: Icons.add_home_rounded,
          isPrimary: true,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const FormulaireDeMiseEnPublicationPage()),
          ),
        ),
        const SizedBox(height: 12),
        _buildFullWidthButton(
          context,
          label: "Explorer EasyLocation",
          icon: Icons.explore_rounded,
          isPrimary: false,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const MaisonsPublieesPage()),
          ),
        ),
      ],
    );
  }

  Widget _buildFullWidthButton(BuildContext context,
      {required String label, required IconData icon, required bool isPrimary, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    final config = context.watch<ConfigService>();
    final double rewardValue = config.referralReferrerReward;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSmallCard(
                context,
                title: "Mes Propriétés",
                icon: Icons.house_siding_rounded,
                color: Colors.blue,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const GestionProprietesPage()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallCard(
                context,
                title: "Suivi Rapports",
                icon: Icons.assignment_outlined,
                color: Colors.orange,
                badgeCount: 0,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SuiviLocationsBailleurPage()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSmallCard(
                context,
                title: "Mes Locataires",
                icon: Icons.people_alt_rounded,
                color: Colors.indigo,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const MesLocatairesPage()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallCard(
                context,
                title: "Gagner ${rewardValue.toStringAsFixed(0)}\$",
                icon: Icons.card_giftcard_rounded,
                color: Colors.purple,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: const CardParrainage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSmallCard(
                context,
                title: "Partenariat",
                icon: Icons.handshake_rounded,
                color: Colors.teal,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const EspacePartenaireWidget(),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()), 
          ],
        ),
      ],
    );
  }

  Widget _buildSmallCard(BuildContext context,
      {required String title, required IconData icon, required Color color, int badgeCount = 0, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Badge(
              label: badgeCount > 0 ? Text(badgeCount.toString()) : null,
              isLabelVisible: badgeCount > 0,
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}