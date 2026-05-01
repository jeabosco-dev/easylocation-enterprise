import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatsMoneyDashboard extends StatelessWidget {
  const StatsMoneyDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Analyse de la Masse Monétaire",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // StreamBuilder pour lire le document unique de stats (plus économique)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('metadata')
                .doc('global_finance')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              
              var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              double totalCirculation = (data['total_easy_credits'] ?? 0).toDouble();
              int totalUsersWithCredit = data['users_count'] ?? 0;

              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _buildStatCard(
                    "Masse Totale", 
                    "$totalCirculation \$", 
                    Icons.account_balance_wallet, 
                    Colors.blue
                  ),
                  _buildStatCard(
                    "Dette Virtuelle", 
                    "Risque: Moyen", 
                    Icons.warning_amber_rounded, 
                    Colors.orange
                  ),
                  _buildStatCard(
                    "Bénéficiaires", 
                    "$totalUsersWithCredit Comptes", 
                    Icons.people_alt_outlined, 
                    Colors.green
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 40),
          const Text(
            "Actions Recommandées",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const ListTile(
            leading: Icon(Icons.campaign, color: Colors.purple),
            title: Text("Lancer une campagne de 'Burn'"),
            subtitle: Text("Encourager l'utilisation des crédits dormants via une notification."),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}