// lib/services/agent_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import 'agent_visites_page.dart'; // Assurez-vous que le chemin est correct

class AgentDashboardPage extends StatelessWidget {
  const AgentDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserProfileProvider>().userData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de bienvenue
        Text(
          "Bonjour, ${userData?.prenom ?? 'Agent'}",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const Text(
          "Tableau de bord des opérations - Bukavu", 
          style: TextStyle(color: Colors.blueGrey),
        ),
        const SizedBox(height: 30),

        // Grille d'outils
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          children: [
            _buildToolCard(
              context,
              "Remise des clés",
              Icons.vpn_key_outlined,
              Colors.orange,
              () { 
                /* Ici, vous pouvez naviguer vers votre onglet_remise_cles 
                   ou la section admin correspondante 
                */ 
              },
            ),
            _buildToolCard(
              context,
              "Visites du jour",
              Icons.calendar_today_outlined,
              Colors.blue,
              () { 
                // ✅ Connexion à la nouvelle page de gestion des visites
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AgentVisitesPage()),
                );
              },
            ),
            _buildToolCard(
              context,
              "États des lieux",
              Icons.assignment_outlined,
              Colors.green,
              () { /* Logique futurs états des lieux */ },
            ),
            _buildToolCard(
              context,
              "Support Admin",
              Icons.headset_mic_outlined,
              Colors.redAccent,
              () { /* Chat interne / Support */ },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              title, 
              textAlign: TextAlign.center, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}