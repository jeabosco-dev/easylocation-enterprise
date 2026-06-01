// lib/services/espace_staff_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/user_model.dart';
import 'agent_dashboard_page.dart'; 
import '../constants/constants.dart';

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
        String userDirection = '';
        
        if (userModel != null) {
          final String statutMobile = userModel.staffStatus; 
          final String roleGlobal = userModel.role.toLowerCase().trim();                  
          final String roleActif = userModel.activeRole;           
          
          // Récupération et normalisation de la direction (Majuscules strictes)
          final dynamic rawDirection = userModel.toMap().containsKey('direction') 
              ? userModel.toMap()['direction'] 
              : AppDepartments.operations;
          
          userDirection = (rawDirection ?? '').toString().toUpperCase().trim();
          if (userDirection.isEmpty) {
            userDirection = AppDepartments.operations;
          }

          // ✅ ALIGNEMENT SÉCURISÉ : Plus aucun rôle ccv codé en dur.
          // L'accès est validé si le statut est approuvé, si l'utilisateur appartient à la Direction des Opérations, 
          // ou s'il possède le rôle ou privilège administrateur global.
          if (statutMobile == 'validated' || 
              statutMobile == 'approved' || 
              userDirection == AppDepartments.operations ||
              roleGlobal == UserRoles.admin ||
              userModel.roles.contains(UserRoles.admin)) {
            staffStatus = 'validated';
          } else if (statutMobile == 'pending') {
            staffStatus = 'pending';
          }

          // Le rôle de secours pour l'attribution devient admin pour le personnel du Back-office
          userRole = userModel.role.isNotEmpty ? userModel.role : UserRoles.admin;

          // Bascule l'activeRole du Provider si nécessaire
          if (staffStatus == 'validated' && roleActif != userRole) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              userProvider.setActiveRole(userRole);
            });
          }
        }

        // ✅ SI VALIDÉ : Aiguillage vers l'espace de travail correspondant
        if (staffStatus == 'validated') {
          return _getCorrectView(userRole, userDirection);
        }

        // ❌ SI NON VALIDÉ OU EN ATTENTE : Vue d'accès restreint
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
                  Text(
                    staffStatus == 'pending' ? "Candidature en cours" : "Accès restreint",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    staffStatus == 'pending'
                        ? "Votre demande d'accès au staff EasyLocation a bien été reçue et est en cours de traitement par l'administration."
                        : "Cet espace est réservé au personnel autorisé par l'administration d'EasyLocation. "
                          "Si vous êtes un employé, veuillez contacter la Direction Générale ou votre pôle RH pour activer votre affectation administrative.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
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

  // ✅ Aiguillage via constantes de départements centralisées
  Widget _getCorrectView(String role, String direction) {
    final String cleanRole = role.toLowerCase().trim();
    final String cleanDirection = direction.toUpperCase().trim();

    // 🖥️ Si c'est l'administrateur principal système (Root)
    if (cleanRole == UserRoles.admin && cleanDirection == AppDepartments.superAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text("Administration Globale"), backgroundColor: Colors.blueGrey.shade900, foregroundColor: Colors.white),
        body: _buildPlaceholderDashboard("Administration Globale (Root)"),
      );
    }

    // 💼 Gestion par Direction Métier FinTech
    if (cleanDirection == AppDepartments.finance) {
      return Scaffold(
        appBar: AppBar(title: const Text("Direction Financière"), backgroundColor: Colors.blueGrey.shade900, foregroundColor: Colors.white),
        body: _buildPlaceholderDashboard(AppDepartments.finance),
      );
    }

    // 🚀 Gestion de la Direction des Opérations Terrain (Anciennement CCV)
    if (cleanDirection == AppDepartments.operations) {
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
    }

    // Fallback par défaut vers le Dashboard Opérations Terrain (Sécurité de fluidité applicative)
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("EasyLocation Operations"),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
      ),
      body: const AgentDashboardPage(),
    );
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