import 'package:flutter/material.dart';
import '../widgets/admin/onglet_performance.dart';
import '../widgets/admin/onglet_zones.dart';
import '../widgets/admin/onglet_conduite.dart'; // Import ajouté

class RhPage extends StatefulWidget {
  const RhPage({super.key});

  @override
  State<RhPage> createState() => _RhPageState();
}

class _RhPageState extends State<RhPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Le controller gère bien les 3 onglets
    _tabController = TabController(length: 3, vsync: this);
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
              "Direction Ressources Humaines & Social",
              style: TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.bold, 
                color: Color(0xFF1E293B)
              ),
            ),
            const SizedBox(height: 20),
            
            // Barre de navigation des onglets
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05), 
                    blurRadius: 10
                  )
                ],
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF1E293B),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF1E293B),
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.speed), text: "Performance"),
                  Tab(icon: Icon(Icons.map), text: "Zones d'Action"),
                  Tab(icon: Icon(Icons.verified_user_outlined), text: "Code de Conduite"),
                ],
              ),
            ),
            
            const SizedBox(height: 25),
            
            // Contenu des onglets
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const OngletPerformance(), 
                  const OngletZones(), 
                  const OngletConduite(), // Onglet éthique et confidentialité
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
