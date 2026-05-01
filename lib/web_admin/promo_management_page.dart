// lib/web_admin/promo_management_page.dart

import 'package:flutter/material.dart';

// Imports des widgets existants
import '../widgets/admin/form_promo_classique.dart';
import '../widgets/admin/form_promo_premier_arrive.dart';
import '../widgets/admin/form_crowd_discount.dart'; 
import '../widgets/admin/stats_money_dashboard.dart'; 
// ✅ On utilise la page de gestion complète avec recherche et actions
import 'admin_manage_partners_page.dart'; 
import '../widgets/admin/admin_withdrawals_panel.dart'; 

class PromoManagementPage extends StatelessWidget {
  const PromoManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6, 
      child: Scaffold(
        appBar: AppBar(
          title: const Text("EasyLocation - Console Marketing"),
          elevation: 2,
          // ✅ Couleur supprimée pour éviter l'embrouille visuelle
          bottom: const TabBar(
            isScrollable: true, 
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.confirmation_number_outlined), text: "Code Classique"),
              Tab(icon: Icon(Icons.speed_outlined), text: "Premier Arrivé (FOMO)"),
              Tab(icon: Icon(Icons.groups_outlined), text: "Challenge Communautaire"),
              Tab(icon: Icon(Icons.analytics_outlined), text: "Masse Monétaire"),
              // Onglet 5 : Gestion, Recherche et Cycle de vie (Suspendre/Archiver)
              Tab(icon: Icon(Icons.handshake_outlined), text: "Gestion Partenaires"),
              Tab(icon: Icon(Icons.payments_outlined), text: "Validation Retraits"),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            key: const PageStorageKey('promo_tabs'),
            children: [
              const FormPromoClassique(),
              const FormPromoPremierArrive(),
              const FormCrowdDiscount(),
              const StatsMoneyDashboard(), 

              // ✅ Appel de la page avec barre de recherche intégrée
              AdminManagePartnersPage(),

              const AdminWithdrawalsPanel(),
            ],
          ),
        ),
      ),
    );
  }
}