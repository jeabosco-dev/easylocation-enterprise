import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  final String userName;
  final String userDirection;

  const AdminDashboard({super.key, required this.userName, required this.userDirection});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.dashboard_customize, size: 80, color: Color(0xFF1E5D8F)),
          const SizedBox(height: 20),
          Text("Tableau de Bord Global", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          Text("Bienvenue, $userName ($userDirection)", style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 40),
          // Ici, tu pourrais ajouter des petits graphiques ou des compteurs rapides
        ],
      ),
    );
  }
}
