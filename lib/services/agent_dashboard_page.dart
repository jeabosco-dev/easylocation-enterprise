// lib/services/agent_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import 'agent_visites_page.dart';

class AgentDashboardPage extends StatelessWidget {
  final Function(int)? onTabChanged;

  const AgentDashboardPage({
    super.key,
    this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserProfileProvider>().userData;

    // 🛡️ SÉCURITÉ : Si le profil utilisateur est en cours de chargement
    if (userData == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)),
        ),
      );
    }

    // Dynamic city formatting for display (e.g., "bukavu" -> "Bukavu")
    String rawVille = userData.ville ?? 'RDC';
    String villeAffichee = rawVille.trim().isNotEmpty
        ? rawVille.trim()[0].toUpperCase() + rawVille.trim().substring(1).toLowerCase()
        : 'Opérations';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de bienvenue
          Text(
            "Bonjour, ${userData.prenom ?? 'Agent'}",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            "Tableau de bord des opérations - $villeAffichee", 
            style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500),
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
                  if (onTabChanged != null) {
                    onTabChanged!(1); 
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Accès via l'onglet Gestion des Clés en bas.")),
                    );
                  }
                },
              ),
              _buildToolCard(
                context,
                "Dossiers à traiter",
                Icons.assignment_turned_in_outlined,
                Colors.blue,
                () { 
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
                () { 
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Module État des lieux en cours de déploiement.")),
                  );
                },
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
      ),
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