import 'package:flutter/material.dart';

class OngletAnalyticsPerf extends StatelessWidget {
  const OngletAnalyticsPerf({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard("Temps de réponse moyen API", "2.4s", Colors.green, Icons.api),
          _buildStatCard("Vitesse de chargement images", "5.8s", Colors.orange, Icons.image),
          _buildStatCard("Taux de succès Paiement", "94%", Colors.blue, Icons.payment),
          const SizedBox(height: 30),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "Détail de latence par page", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))
            ),
          ),
          const SizedBox(height: 15),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildPageMetric("Page Accueil", 1.2),
                  const Divider(),
                  _buildPageMetric("Tunnel de Paiement", 4.5),
                  const Divider(),
                  _buildPageMetric("Upload Document Logistique", 8.2),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        trailing: Text(
          value, 
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)
        ),
      ),
    );
  }

  Widget _buildPageMetric(String page, double speed) {
    bool isSlow = speed > 3.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(page, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text("${speed}s", style: TextStyle(color: isSlow ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (speed / 10).clamp(0.0, 1.0), 
            backgroundColor: Colors.grey.shade200,
            color: isSlow ? Colors.red : Colors.green,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
