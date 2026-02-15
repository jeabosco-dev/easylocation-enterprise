import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// Importations des widgets
import '../widgets/section_alertes_widget.dart';
import '../widgets/section_recommandations_widget.dart';
import '../widgets/entete_profil_widget.dart'; 
import '../widgets/app_drawer.dart';
// ✅ IMPORT DU BOUTON ADMIN
import 'package:easylocation_mvp/widgets/admin/bouton_liaison_admin_widget.dart';

// Importations des pages
import 'package:easylocation_mvp/screens/maisons_publiees_page.dart';
import 'mes_favoris_page.dart';
import 'historique_locataire_page.dart';
import 'mes_factures_page.dart'; 

import '../providers/user_profile_provider.dart';

class ProfilLocatairePage extends StatefulWidget {
  const ProfilLocatairePage({super.key});

  @override
  State<ProfilLocatairePage> createState() => _ProfilLocatairePageState();
}

class _ProfilLocatairePageState extends State<ProfilLocatairePage> {
  
  Future<void> _handleRefresh(BuildContext context, String uid) async {
    await context.read<UserProfileProvider>().loadUser(uid);
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUserFirebase = FirebaseAuth.instance.currentUser;

    if (currentUserFirebase == null) {
      return const Scaffold(body: Center(child: Text("Authentification requise...")));
    }

    return Selector<UserProfileProvider, String>(
      selector: (_, provider) => provider.userData?.uid ?? "",
      builder: (context, uid, child) {
        final provider = context.read<UserProfileProvider>();
        final userData = provider.userData;

        if (provider.isLoading || userData == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          drawer: const AppDrawer(),
          appBar: AppBar(
            title: const Text('Tableau de Bord', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
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
                  EnteteProfilWidget(
                    nom: userData.nom,
                    prenom: userData.prenom,
                    genre: userData.genre,
                    imageUrl: userData.imageUrl,
                    isVerified: userData.isVerified,
                    typeEspace: "Locataire",
                  ),
                  
                  // ✅ ZONE DE LIAISON ADMIN (Visible uniquement pour Jean-Bosco via son UID)
                  if (userData.uid == "evEq7oWkjVPrpYp3QOaXpUoM9U23" || userData.role.toLowerCase() == "super_admin") 
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: BoutonLiaisonAdminWidget(),
                    ),

                  const SizedBox(height: 25),

                  _buildFakeSearchBar(context),
                  
                  const SizedBox(height: 25),

                  _buildActionGrid(context),
                  
                  const SizedBox(height: 30),

                  SectionAlertesWidget(userId: uid),
                  const SizedBox(height: 30),

                  _buildRecommandationsHeader(context),
                  const SizedBox(height: 8),
                  SectionRecommandationsWidget(userId: uid),
                  
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

  Widget _buildFakeSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const MaisonsPublieesPage()),
      ),
      child: Container(
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.pink, size: 28),
            const SizedBox(width: 15),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Où voulez-vous loger ?",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  "Province • Ville • Commune • Budget",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(Icons.tune, size: 20, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommandationsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Pour vous", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const MaisonsPublieesPage()),
          ),
          child: const Text("Voir tout", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildSmallActionCard(
            context,
            title: "Favoris",
            icon: Icons.favorite_rounded,
            color: Colors.pink,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const MesFavorisPage()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSmallActionCard(
            context,
            title: "Factures",
            icon: Icons.receipt_long_rounded,
            color: Colors.blue,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const MesFacturesPage()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSmallActionCard(
            context,
            title: "Historique",
            icon: Icons.history_rounded,
            color: Colors.blueGrey,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const HistoriqueLocatairePage()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallActionCard(BuildContext context,
      {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              title, 
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
