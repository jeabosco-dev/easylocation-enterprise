import 'package:flutter/material.dart';
import '../widgets/admin/onglet_equipe.dart'; 
import '../widgets/admin/onglet_performance.dart';
import '../widgets/admin/onglet_zones.dart';
import '../widgets/admin/onglet_audit_financier.dart';

class UtilisateursPage extends StatefulWidget {
  const UtilisateursPage({super.key});

  @override
  State<UtilisateursPage> createState() => _UtilisateursPageState();
}

class _UtilisateursPageState extends State<UtilisateursPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Nous passons à 4 onglets principaux pour la gestion complète
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Management & Performance Équipe",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 20),
            
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF1E5D8F),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF1E5D8F),
                isScrollable: true,
                tabs: const [
                  Tab(icon: Icon(Icons.admin_panel_settings), text: "Accès Équipe"),
                  Tab(icon: Icon(Icons.insights), text: "Performance"),
                  Tab(icon: Icon(Icons.map), text: "Zones Terrain"),
                  Tab(icon: Icon(Icons.monetization_on), text: "Audit"),
                ],
              ),
            ),
            
            const SizedBox(height: 25),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  OngletEquipe(),       // Gestion des rôles et statuts
                  OngletPerformance(),  // Classement des recrues
                  OngletZones(),        // Attribution des quartiers (NOUVEAU)
                  OngletAuditFinancier(), // Suivi financier
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
