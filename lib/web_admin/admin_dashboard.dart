// lib/web_admin/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatelessWidget {
  final String userName;
  final String userDirection;

  const AdminDashboard({
    super.key, 
    required this.userName, 
    required this.userDirection
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER D'ACCUEIL ---
          Row(
            children: [
              const Icon(Icons.dashboard_customize, size: 40, color: Color(0xFF1E5D8F)),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tableau de Bord Global", 
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)
                  ),
                  Text(
                    "Bienvenue, $userName ($userDirection)", 
                    style: const TextStyle(fontSize: 16, color: Colors.grey)
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 40),

          // --- SECTION DES COMPTEURS RAPIDES (KPIs) ---
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              // Widget de notification pour les remboursements
              _buildRefundNotificationCard(),
              
              // Vous pourrez ajouter d'autres compteurs ici plus tard (ex: Nouvelles annonces)
              _buildSimpleStatCard(
                "Utilisateurs Actifs", 
                "Chargement...", 
                Icons.people, 
                Colors.blue
              ),
            ],
          ),

          const SizedBox(height: 40),
          
          // Zone de contenu principale (Graphiques ou derniers messages)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: [
                Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
                SizedBox(height: 20),
                Text(
                  "Prêt pour l'analyse des données EasyLocation Enterprise",
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET : CARTE DE NOTIFICATION DYNAMIQUE ---
  Widget _buildRefundNotificationCard() {
    return StreamBuilder<QuerySnapshot>(
      // On écoute uniquement les demandes en attente
      stream: FirebaseFirestore.instance
          .collection('refund_requests')
          .where('status', isEqualTo: 'en_attente')
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }

        return Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: count > 0 ? Colors.red.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: count > 0 ? Colors.red.shade200 : Colors.grey.shade200,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: count > 0 ? Colors.red : Colors.grey.shade200,
                    child: Icon(
                      Icons.payments_outlined, 
                      color: count > 0 ? Colors.white : Colors.grey
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "REMBOURSEMENTS",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    Text(
                      count > 0 ? "$count en attente" : "Aucune demande",
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: count > 0 ? Colors.red.shade700 : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget générique pour d'autres stats
  Widget _buildSimpleStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}