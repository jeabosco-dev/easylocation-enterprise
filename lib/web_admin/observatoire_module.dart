import 'package:flutter/material.dart';
import '../widgets/admin/onglet_urgent.dart'; 
import '../widgets/admin/onglet_analytics_perf.dart';

class ObservatoireModule extends StatefulWidget {
  const ObservatoireModule({super.key});

  @override
  State<ObservatoireModule> createState() => _ObservatoireModuleState();
}

class _ObservatoireModuleState extends State<ObservatoireModule> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
              "Observatoire Produit & Technologie",
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
                tabs: const [
                  Tab(icon: Icon(Icons.bolt, color: Colors.red), text: "Alertes Urgentes"),
                  Tab(icon: Icon(Icons.speed), text: "Analytics & Performance"),
                ],
              ),
            ),
            
            const SizedBox(height: 25),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  OngletUrgent(),           // Flux direct Firestore
                  OngletAnalyticsPerf(),    // Monitoring Performance
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
