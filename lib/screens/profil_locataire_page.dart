// lib/screens/profil_locataire_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// Importations des services et providers
import '../providers/user_profile_provider.dart';
import '../providers/contract_provider.dart';
import '../providers/wallet_provider.dart'; 
import '../services/config_service.dart';

// Importations des constantes globales
import '../constants/constants.dart';

// Importations des widgets
import '../widgets/section_alertes_widget.dart';
import '../widgets/section_recommandations_widget.dart';
import '../widgets/entete_profil_widget.dart'; 
import '../widgets/app_drawer.dart';
import '../widgets/wallet_status_card.dart';
import '../widgets/card_parrainage.dart'; 
import '../widgets/espace_partenaire_widget.dart'; // ✅ AJOUTÉ POUR LE B2B

// ✅ NOUVEAUX WIDGETS SERVICES
import '../widgets/mes_commandes_services_widget.dart';
import 'package:easylocation_mvp/widgets/services_carousel_widget.dart';

// Importations des pages
import 'package:easylocation_mvp/screens/maisons_publiees_page.dart';
import 'package:easylocation_mvp/screens/ma_location_page.dart';
import 'mes_favoris_page.dart';
import 'historique_locataire_page.dart';
import 'mes_factures_page.dart'; 

// IMPORT CORRIGÉ
import '../views/visites/decision_visite_page.dart'; 

class ProfilLocatairePage extends StatefulWidget {
  const ProfilLocatairePage({super.key});

  @override
  State<ProfilLocatairePage> createState() => _ProfilLocatairePageState();
}

class _ProfilLocatairePageState extends State<ProfilLocatairePage> {
  
  Future<void> _handleRefresh(BuildContext context, String uid) async {
    await context.read<UserProfileProvider>().loadUser(uid);
    final contractProv = context.read<ContractProvider>();
    final config = context.read<ConfigService>();
    
    await context.read<WalletProvider>().refreshAll(uid);
    await contractProv.listenToActiveContract(uid);
    
    if (contractProv.activeContract != null) {
      await contractProv.checkAndGenerateInvoice(uid, contractProv.activeContract, config);
    }
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

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final contractProv = context.read<ContractProvider>();
          final config = context.read<ConfigService>(); 

          context.read<WalletProvider>().listenToWallet(uid);
          await contractProv.listenToActiveContract(uid);
          
          if (contractProv.activeContract != null) {
            await contractProv.checkAndGenerateInvoice(uid, contractProv.activeContract, config);
          }
        });

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

                  const WalletStatusCard(),
                  const SizedBox(height: 15),
                  MesCommandesServicesWidget(userId: uid),
                  _buildDecisionBanner(uid),
                  
                  const SizedBox(height: 25),
                  _buildFakeSearchBar(context),
                  
                  const SizedBox(height: 25),
                  _buildActionGrid(context), 
                  
                  const SizedBox(height: 30),
                  _buildServiceHeader(),
                  const ServicesCarouselWidget(provenance: 'DASHBOARD_LOCATAIRE'),

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

  // --- ACTIONS RAPIDES (MODIFIÉ POUR LE B2B) ---
  Widget _buildActionGrid(BuildContext context) {
    final config = context.watch<ConfigService>();
    final double rewardValue = config.referralReferrerReward;

    return Column(
      children: [
        // LIGNE 1
        Row(
          children: [
            Expanded(
              child: _buildSmallActionCard(
                context,
                title: "Ma Location",
                icon: Icons.vpn_key_rounded,
                color: Colors.orange,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MaLocationPage())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallActionCard(
                context,
                title: "Gagner ${rewardValue.toStringAsFixed(0)}\$", 
                icon: Icons.card_giftcard_rounded,
                color: Colors.purple,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: const CardParrainage(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // LIGNE 2
        Row(
          children: [
            Expanded(
              child: _buildSmallActionCard(
                context,
                title: "Factures",
                icon: Icons.receipt_long_rounded,
                color: Colors.blue,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MesFacturesPage())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallActionCard(
                context,
                title: "Favoris",
                icon: Icons.favorite_rounded,
                color: Colors.pink,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MesFavorisPage())),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // LIGNE 3 (HISTORIQUE + PARTENAIRE)
        Row(
          children: [
            Expanded(
              child: _buildSmallActionCard(
                context,
                title: "Historique",
                icon: Icons.history_rounded,
                color: Colors.blueGrey,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const HistoriqueLocatairePage())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallActionCard(
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
          ],
        ),
      ],
    );
  }

  // --- HELPERS UI ---
  Widget _buildServiceHeader() {
    return const Padding(
      padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Nos services d'accompagnement", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          Text(
            "Besoin d'aide ou d'un service pour votre logement ?", 
            style: TextStyle(color: Colors.grey, fontSize: 13)
          ),
        ],
      ),
    );
  }

  Widget _buildRecommandationsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Pour vous", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MaisonsPublieesPage())),
          child: const Text("Voir tout", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSmallActionCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ✅ ENTIÈREMENT SÉCURISÉ AVEC TES CONSTANTES CONSTANTS.DART
  Widget _buildDecisionBanner(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.factures)
          .where('locataireId', isEqualTo: uid) 
          .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPaid) 
          .where(FactureFields.confirmationLocataire, isNull: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final factureDoc = snapshot.data!.docs.first;
        final data = factureDoc.data() as Map<String, dynamic>;
        
        final String propertyRef = data[FactureFields.refMaison] ?? data['houseId'] ?? "N/A";

        // =====================================================================
        // OPTION "SANS CLIC" (AUTOMATISATION) :
        // Pour activer l'ouverture automatique, décommente les lignes ci-dessous
        // =====================================================================
        /*
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DecisionVisitePage(
                factureId: factureDoc.id,
                propertyRef: propertyRef,
              ),
            ),
          );
        });
        */

        return Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.orange.shade50, 
            borderRadius: BorderRadius.circular(15), 
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.fact_check_rounded, color: Colors.orange, size: 30),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    const Text(
                      "Visite effectuée ?", 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ), 
                    const SizedBox(height: 4),
                    Text(
                      "Donnez votre verdict pour la propriété Réf: $propertyRef afin de débloquer vos clés.", 
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => DecisionVisitePage(
                      factureId: factureDoc.id, 
                      propertyRef: propertyRef,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange, 
                  foregroundColor: Colors.white, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Répondre"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFakeSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MaisonsPublieesPage())),
      child: Container(
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))], border: Border.all(color: Colors.grey.shade100)),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.pink, size: 28),
            const SizedBox(width: 15),
            const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Où voulez-vous loger ?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Text("Province • Ville • Commune • Budget", style: TextStyle(color: Colors.grey, fontSize: 12))]),
            const Spacer(),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)), child: const Icon(Icons.tune, size: 20, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}