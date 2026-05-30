// lib/services/espace_staff_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/user_model.dart';
import 'agent_dashboard_page.dart'; 

class EspaceStaffPage extends StatefulWidget {
  const EspaceStaffPage({super.key});

  @override
  State<EspaceStaffPage> createState() => _EspaceStaffPageState();
}

class _EspaceStaffPageState extends State<EspaceStaffPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, userProvider, child) {
        final UserModel? userModel = userProvider.userData;
        
        String staffStatus = '';
        String userRole = '';
        
        if (userModel != null) {
          final String statutMobile = userModel.staffStatus; 
          final String roleGlobal = userModel.role;                 
          final String roleActif = userModel.activeRole;           

          // ✅ Alignement sur tes données Firestore
          if (statutMobile == 'validated' || 
              statutMobile == 'approved' || 
              roleGlobal == 'operations' || 
              roleGlobal == 'certificateur' || 
              roleGlobal == 'staff' ||
              roleGlobal == 'super_admin') {
            staffStatus = 'validated';
          } else if (statutMobile == 'pending') {
            staffStatus = 'pending';
          }

          userRole = roleGlobal.isNotEmpty ? roleGlobal : 'operations';

          // Bascule l'activeRole du Provider si nécessaire
          if (staffStatus == 'validated' && roleActif != userRole) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              userProvider.setActiveRole(userRole);
            });
          }
        }

        // ✅ SI VALIDÉ : On affiche directement l'espace de travail correspondant au rôle
        if (staffStatus == 'validated') {
          return _getCorrectView(userRole);
        }

        // ❌ SI NON VALIDÉ : Vue d'accès restreint propre
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text("Espace Collaborateur"),
            backgroundColor: Colors.blueGrey.shade900,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 100, color: Colors.blueGrey.shade300),
                  const SizedBox(height: 30),
                  const Text(
                    "Accès restreint",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Cet espace est réservé au personnel autorisé par l'administration d'EasyLocation. "
                    "Si vous êtes un employé, veuillez contacter votre Super-Admin pour qu'il procède à votre affectation directe.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Retour à l'accueil"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Aiguillage vers les tableaux de bord métiers harmonisés
  Widget _getCorrectView(String role) {
    switch (role) {
      case 'super_admin':
        return Scaffold(
          appBar: AppBar(title: const Text("Administration Globale"), backgroundColor: Colors.blueGrey.shade900, foregroundColor: Colors.white),
          body: _buildPlaceholderDashboard("Administration Globale"),
        );
      case 'operations':
      case 'certificateur':
        // ✅ AJOUT D'UN SCAFFOLD ICI : Fournit la structure et la surface Material requise pour le Dashboard Agent
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: const Text("EasyLocation Operations"),
            backgroundColor: Colors.blueGrey.shade900,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: const AgentDashboardPage(),
        );
      case 'comptable':
        return Scaffold(
          appBar: AppBar(title: const Text("Direction Financière"), backgroundColor: Colors.blueGrey.shade900, foregroundColor: Colors.white),
          body: _buildPlaceholderDashboard("Direction Financière"),
        );
      default:
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(title: const Text("EasyLocation Operations"), backgroundColor: Colors.blueGrey.shade900, foregroundColor: Colors.white),
          body: const AgentDashboardPage(),
        );
    }
  }

  Widget _buildPlaceholderDashboard(String departementName) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock, size: 70, color: Colors.blueGrey),
            const SizedBox(height: 20),
            Text(
              "Espace $departementName",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Ce module métier est optimisé pour l'affichage console Web et grand écran. Les fonctionnalités mobiles d'appoint seront disponibles dans la prochaine mise à jour.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}