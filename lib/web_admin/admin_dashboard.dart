// lib/web_admin/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatelessWidget {
  final String userName;
  final String userDirection;
  final String userRole; // 💡 AJOUT : Permet d'adapter l'affichage selon le rôle (ex: operations, super_admin)

  const AdminDashboard({
    super.key, 
    required this.userName, 
    required this.userDirection,
    required this.userRole, // 💡 Requis au constructeur
  });

  @override
  Widget build(BuildContext context) {
    // Vérifications rapides des rôles pour l'affichage conditionnel
    final bool isSuperAdmin = userRole == 'super_admin';
    final bool isOperations = userRole == 'operations';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER D'ACCUEIL ---
          Row(
            children: [
              const Icon(Icons.dashboard_customize, size: 40, color: Color(0xFF1E293B)),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOperations ? "Espace Opérations Terrain" : "Tableau de Bord Global", 
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)
                  ),
                  Text(
                    "Bienvenue, $userName — Rôle : ${userRole.toUpperCase()} ($userDirection)", 
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
              // 📊 KPI COMPTABLE / ADMIN : Uniquement pour le super_admin ou la finance
              if (isSuperAdmin || userRole == 'comptable') 
                _buildRefundNotificationCard(),
              
              // 🏃‍♂️ KPI OPÉRATIONS : Uniquement pour le pôle opérations ou super_admin
              if (isSuperAdmin || isOperations)
                _buildOperationsDossiersCard(),

              // Compteur générique global
              _buildActiveUsersCard(),
            ],
          ),

          const SizedBox(height: 40),
          
          // --- ZONE DE CONTENU PRINCIPALE ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 20),
                Text(
                  isOperations 
                    ? "Suivi opérationnel EasyLocation — Contrôle des attributions et validation terrain."
                    : "Prêt pour l'analyse des données EasyLocation Enterprise",
                  style: const TextStyle(color: Colors.grey, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET : COMPTEUR DES DOSSIERS DE LOCATION POUR LES OPÉRATIONS ---
  Widget _buildOperationsDossiersCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('factures')
          .where('etapeDossier', isEqualTo: 'nouveau')
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }

        return _buildStatCard(
          title: "DOSSIERS NOUVEAUX",
          value: count > 0 ? "$count à traiter" : "À jour",
          icon: Icons.assignment_late_outlined,
          color: count > 0 ? Colors.orange : Colors.green,
          badgeCount: count,
        );
      },
    );
  }

  // --- WIDGET : COMPTEUR DES DEMANDES DE REMBOURSEMENT (FINANCE) ---
  Widget _buildRefundNotificationCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('refund_requests')
          .where('status', isEqualTo: 'en_attente')
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }

        return _buildStatCard(
          title: "REMBOURSEMENTS",
          value: count > 0 ? "$count en attente" : "Aucune demande", // ✅ CORRIGÉ : C'est bien un String textuel maintenant !
          icon: Icons.payments_outlined,
          color: count > 0 ? Colors.red : Colors.blueGrey,
          badgeCount: count,
        );
      },
    );
  }

  // --- WIDGET : UTILISATEURS ACTIFS EN TEMPS RÉEL ---
  Widget _buildActiveUsersCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('utilisateurs')
          .where('statut', isEqualTo: 'actif')
          .snapshots(),
      builder: (context, snapshot) {
        String displayValue = "Chargement...";
        if (snapshot.hasData) {
          displayValue = "${snapshot.data!.docs.length} membres";
        }
        return _buildStatCard(
          title: "UTILISATEURS ACTIFS",
          value: displayValue,
          icon: Icons.people_alt_outlined,
          color: Colors.blue,
        );
      },
    );
  }

  // --- FACTORY DESIGN COMPACT POUR LES CARTES ---
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required MaterialColor color, 
    int badgeCount = 0,
  }) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: badgeCount > 0 ? color.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeCount > 0 ? color.withOpacity(0.3) : Colors.grey.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
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
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold, 
                    color: badgeCount > 0 ? color.shade900 : Colors.black87
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}