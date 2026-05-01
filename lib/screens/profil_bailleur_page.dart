// lib/screens/profil_bailleur_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// Importations des pages
import 'package:easylocation_mvp/screens/formulaire_de_mise_en_publication_page.dart';
import 'package:easylocation_mvp/screens/maisons_publiees_page.dart';
import 'package:easylocation_mvp/screens/gestion_proprietes_page.dart';
import 'package:easylocation_mvp/screens/mes_locataires_page.dart';
import 'package:easylocation_mvp/screens/gestion_demandes_bailleur_page.dart';

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
        final int pendingCount = userProfile.pendingRequestsCount;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<WalletProvider>().listenToWallet(uid);
          }
        });

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

                  // 4. ALERTES
                  if (pendingCount > 0) ...[
                    const SizedBox(height: 15),
                    _buildAlertsSection(context, pendingCount),
                  ],

                  const SizedBox(height: 25),

                  // 5. BOUTONS D'ACTION PRINCIPAUX (RÉTABLIS)
                  _buildMainLargeButtons(context),

                  const SizedBox(height: 25),

                  // 6. GRILLE D'ACTIONS SECONDAIRES (3 LIGNES)
                  _buildActionGrid(context, pendingCount),

                  const SizedBox(height: 30),

                  // 7. SERVICES MAINTENANCE
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

                  // 8. ACTIVITÉS
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

  Widget _buildAlertsSection(BuildContext context, int count) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const GestionDemandesBailleurPage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.orange),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                "Vous avez $count demande(s) en attente !",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.orange),
          ],
        ),
      ),
    );
  }

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

  Widget _buildActionGrid(BuildContext context, int count) {
    final config = context.watch<ConfigService>();
    final double rewardValue = config.referralReferrerReward;

    return Column(
      children: [
        // LIGNE 1 : Mes Propriétés | Demandes
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
                title: "Demandes",
                icon: Icons.assignment_outlined,
                color: Colors.orange,
                badgeCount: count,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const GestionDemandesBailleurPage()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // LIGNE 2 : Mes Locataires | Gagner X$
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

        // LIGNE 3 : Partenariat (1ère colonne)
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
            const Expanded(child: SizedBox()), // Colonne vide pour maintenir l'alignement
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