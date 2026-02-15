// lib/screens/profil_bailleur_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // ✅ AJOUT

import 'package:easylocation_mvp/screens/formulaire_de_mise_en_publication_page.dart';
import 'package:easylocation_mvp/screens/maisons_publiees_page.dart';
import 'package:easylocation_mvp/screens/gestion_proprietes_page.dart';
import 'gestion_demandes_bailleur_page.dart';

import '../widgets/app_drawer.dart';
import '../widgets/entete_profil_widget.dart'; 
import '../widgets/activites_recentes_bailleur_widget.dart';
import '../providers/user_profile_provider.dart';
import '../models/user_model.dart';

class ProfilBailleurPage extends StatefulWidget {
  const ProfilBailleurPage({super.key});

  @override
  State<ProfilBailleurPage> createState() => _ProfilBailleurPageState();
}

class _ProfilBailleurPageState extends State<ProfilBailleurPage> {

  // ✅ FONCTION MISE À JOUR POUR UTILISER LES NAMED ROUTES DU MAIN.DART
  void _ouvrirScanner(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Scannez le QR Code"),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                
                // Vérification du format attendu (contient la signature de notre URL)
                if (code != null && code.contains('verify?ref=')) {
                  
                  // 1. Fermer le scanner (le BottomSheet)
                  Navigator.pop(context);

                  // 2. Extraire les paramètres de l'URL
                  Uri uri = Uri.parse(code);
                  String ref = uri.queryParameters['ref'] ?? '';
                  String client = uri.queryParameters['client'] ?? '';

                  // 3. Naviguer vers la page de vérification via le système de routes du Main
                  Navigator.pushNamed(
                    context, 
                    '/verification-reservation',
                    arguments: {
                      'refMaison': ref,
                      'clientId': client,
                    },
                  );
                  break; // Sortir de la boucle une fois détecté
                }
              }
            },
          ),
        ),
      ),
    );
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

        return Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(
            title: const Text('Tableau de Bord', style: TextStyle(fontWeight: FontWeight.bold)),
            elevation: 0,
            centerTitle: true,
          ),
          // ✅ BOUTON FLOTTANT DE SCAN CONFIGURÉ
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _ouvrirScanner(context),
            label: const Text("Scanner Facture"),
            icon: const Icon(Icons.qr_code_scanner),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          body: RefreshIndicator(
            onRefresh: () => userProfile.loadUser(uid),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EnteteProfilWidget(
                    nom: userData.nom,
                    prenom: userData.prenom,
                    genre: userData.genre,
                    imageUrl: userData.imageUrl,
                    isVerified: userData.isVerified,
                    typeEspace: "Bailleur",
                  ),
                  const SizedBox(height: 25),

                  if (pendingCount > 0) _buildAlertsSection(context, pendingCount),
                  if (pendingCount > 0) const SizedBox(height: 20),

                  _buildMainActions(context),
                  const SizedBox(height: 15),
                  
                  _buildActionGrid(context, pendingCount),
                  const SizedBox(height: 30),

                  ActivitesRecentesBailleurWidget(bailleurId: uid),
                  
                  const SizedBox(height: 100), // Espace supplémentaire pour ne pas cacher le bouton de scan
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- UI Helpers ---

  Widget _buildAlertsSection(BuildContext context, int count) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const GestionDemandesBailleurPage()),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange.shade200),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.orange),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                "Vous avez $count demande(s) de visite en attente !",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActions(BuildContext context) {
    return Column(
      children: [
        _buildLargeButton(
          context,
          label: "Ajouter une Propriété",
          icon: Icons.add_home,
          isPrimary: true,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const FormulaireDeMiseEnPublicationPage()),
          ),
        ),
        const SizedBox(height: 12),
        _buildLargeButton(
          context,
          label: "Explorer EasyLocation",
          icon: Icons.explore_outlined,
          isPrimary: false,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const MaisonsPublieesPage()),
          ),
        ),
      ],
    );
  }

  Widget _buildLargeButton(BuildContext context,
      {required String label, required IconData icon, required bool isPrimary, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
    );
  }

  Widget _buildActionGrid(BuildContext context, int count) {
    return Row(
      children: [
        Expanded(
          child: _buildSmallActionCard(
            context,
            title: "Mes Propriétés",
            icon: Icons.house_siding,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const GestionProprietesPage()),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildSmallActionCard(
            context,
            title: "Demandes",
            icon: Icons.assignment_outlined,
            badgeCount: count,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const GestionDemandesBailleurPage()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallActionCard(BuildContext context,
      {required String title, required IconData icon, int badgeCount = 0, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Badge(
              label: badgeCount > 0 ? Text(badgeCount.toString()) : null,
              isLabelVisible: badgeCount > 0,
              child: Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
