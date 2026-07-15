// lib/web_admin/admin_main_shell.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

// ✅ IMPORTATIONS DES MODULES (Tous situés dans lib/web_admin/)
import 'sidebar_menu.dart';
import 'admin_dashboard.dart';
import 'finance_module.dart';
import 'gestion_contrats_module.dart'; 
import 'marketing_module.dart';
import 'promo_management_page.dart'; 
import 'utilisateurs_page.dart'; 
import 'admin_staff_management.dart';
import 'operations_module.dart'; 
import 'biens_page.dart';            
import 'rh_page.dart';                
import 'logistique_cadeaux_module.dart'; 
import 'observatoire_module.dart';
import 'admin_settings_page.dart';
import 'rapports_audit_page.dart';
import 'services_module.dart'; 
import 'admin_add_partner_page.dart'; 
import 'gestion_signalements_module.dart'; 

// 🌟 NOUVEAU : Importation de ta page de profil autonome
import 'backoffice_profil_page.dart'; 

// ✅ IMPORTATION DU COMPOSANT CLIENTS (Nettoyé du dialogue inutile)
import '../widgets/admin/onglet_clients.dart'; 

class AdminMainShell extends StatefulWidget {
  const AdminMainShell({super.key});

  @override
  State<AdminMainShell> createState() => _AdminMainShellState();
}

class _AdminMainShellState extends State<AdminMainShell> {
  int _selectedIndex = 0;
  String _userRole = 'USER'; 
  String _userDirection = 'AUCUNE'; 
  String _userName = 'Chargement...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  // 🔐 CHARGEMENT DES DROITS DEPUIS FIRESTORE (Sécurité RBAC)
  Future<void> _loadAdminData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('utilisateurs')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _userRole = (data['role'] ?? 'USER').toString().toUpperCase();
            _userDirection = (data['direction'] ?? 'AUCUNE').toString().toUpperCase();
            _userName = data['prenom'] ?? 'Admin';
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Erreur RBAC : $e");
        setState(() => _isLoading = false);
      }
    }
  }

  // 🛠 GÉNÉRATION DYNAMIQUE DES ONGLETS (Filtrage strict 1-pour-1 par Direction)
  List<Map<String, dynamic>> _getAvailableTabs() {
    final List<Map<String, dynamic>> tabs = [];

    // 0️⃣ ONGLET ACCUEIL : Accessible par défaut à TOUS les utilisateurs connectés
    tabs.add({
      'label': 'Accueil', 
      'icon': Icons.dashboard, 
      'module': AdminDashboard(
        userName: _userName, 
        userDirection: _userDirection, 
        userRole: _userRole.toLowerCase(),
      )
    });

    // Évaluation des super-privilèges
    final bool hasFullAccess = _userRole == 'SUPER_ADMIN' || _userDirection == 'DIRECTION GÉNÉRALE';

    if (hasFullAccess) {
      // Injection de TOUS les modules sans restriction
      tabs.addAll([
        {'label': 'Catalogue Biens', 'icon': Icons.home_work, 'module': const BiensPage()},
        {'label': 'Finance', 'icon': Icons.account_balance_wallet, 'module': const FinanceModule()},
        {'label': 'Répertoire Contrats', 'icon': Icons.description_outlined, 'module': const GestionContratsModule()},
        {'label': 'Marketing', 'icon': Icons.analytics, 'module': const MarketingModule()},
        {'label': 'Promotions Globales', 'icon': Icons.auto_awesome, 'module': const PromoManagementPage()},
        {'label': 'Ajouter Partenaire', 'icon': Icons.handshake, 'module': AdminAddPartnerPage()},
        {'label': 'Rapports & Audit', 'icon': Icons.assessment_outlined, 'module': const RapportsAuditPage()},
        {'label': 'Opérations Terrain', 'icon': Icons.assignment_turned_in, 'module': const OperationsModule()},
        {'label': 'Logistique (Cadeaux)', 'icon': Icons.card_giftcard, 'module': const LogistiqueCadeauxModule()},
        {'label': 'Gestion Services', 'icon': Icons.miscellaneous_services, 'module': const ServicesModule()},
        {'label': 'Ressources Humaines', 'icon': Icons.badge, 'module': const RhPage()},
        {'label': 'Observatoire Tech', 'icon': Icons.remove_red_eye_rounded, 'module': const ObservatoireModule()},
        {'label': 'Paramètres Système', 'icon': Icons.settings, 'module': const AdminSettingsPage()},
        {'label': 'Management Équipe', 'icon': Icons.admin_panel_settings, 'module': const UtilisateursPage()},
        {'label': 'Base Clients', 'icon': Icons.people, 'module': const OngletClients()},
        {'label': 'Gestion Signalements', 'icon': Icons.report_problem, 'module': const GestionSignalementsModule()},
      ]);
    } else {
      // Distribution granulaire stricte basée uniquement sur la Direction de l'utilisateur
      switch (_userDirection) {
        case 'FINANCE': 
          tabs.add({'label': 'Finance', 'icon': Icons.account_balance_wallet, 'module': const FinanceModule()});
          tabs.add({'label': 'Rapports & Audit', 'icon': Icons.assessment_outlined, 'module': const RapportsAuditPage()});
          break;

        case 'RH': 
          tabs.add({'label': 'Ressources Humaines', 'icon': Icons.badge, 'module': const RhPage()});
          break;

        case 'DIRECTION PRODUIT & TECHNOLOGIE': 
          tabs.add({'label': 'Observatoire Tech', 'icon': Icons.remove_red_eye_rounded, 'module': const ObservatoireModule()});
          break;

        case 'MARKETING': 
          tabs.add({'label': 'Marketing', 'icon': Icons.analytics, 'module': const MarketingModule()});
          tabs.add({'label': 'Promotions Globales', 'icon': Icons.auto_awesome, 'module': const PromoManagementPage()});
          break;

        case 'OPERATIONS': 
          tabs.add({'label': 'Opérations Terrain', 'icon': Icons.assignment_turned_in, 'module': const OperationsModule()});
          tabs.add({'label': 'Répertoire Contrats', 'icon': Icons.description_outlined, 'module': const GestionContratsModule()});
          tabs.add({'label': 'Gestion Services', 'icon': Icons.miscellaneous_services, 'module': const ServicesModule()});
          // Ajout spécifique pour les opérations
          tabs.add({'label': 'Gestion Signalements', 'icon': Icons.report_problem, 'module': const GestionSignalementsModule()});
          break;

        case 'LOGISTIQUE': 
          tabs.add({'label': 'Logistique (Cadeaux)', 'icon': Icons.card_giftcard, 'module': const LogistiqueCadeauxModule()});
          tabs.add({'label': 'Gestion Services', 'icon': Icons.miscellaneous_services, 'module': const ServicesModule()});
          break;
          
        default:
          break;
      }
    }

    tabs.add({
      'label': 'Mon Profil',
      'icon': Icons.person_outline,
      'module': const BackofficeProfilPage(),
    });

    return tabs;
  }

  void _handleLogout(BuildContext context) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Déconnexion"),
        content: const Text("Voulez-vous vraiment quitter la session ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Déconnecter", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final availableTabs = _getAvailableTabs();
    
    if (_selectedIndex >= availableTabs.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      body: Row(
        children: [
          SidebarMenu(
            selectedIndex: _selectedIndex,
            availableTabs: availableTabs,
            onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
          ),
          
          const VerticalDivider(thickness: 1, width: 1),
          
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, availableTabs[_selectedIndex]['label'], availableTabs),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: KeyedSubtree(
                      key: ValueKey<int>(_selectedIndex),
                      child: availableTabs[_selectedIndex]['module'],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String title, List<Map<String, dynamic>> availableTabs) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white, 
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title, 
              style: const TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: Color(0xFF1E5D8F)
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(width: 15),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _userName, 
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "$_userDirection | $_userRole", 
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),

              InkWell(
                onTap: () {
                  final targetIndex = availableTabs.indexWhere((tab) => tab['label'] == 'Mon Profil');
                  if (targetIndex != -1) {
                    setState(() => _selectedIndex = targetIndex);
                  }
                },
                borderRadius: BorderRadius.circular(18),
                mouseCursor: SystemMouseCursors.click,
                child: const Tooltip(
                  message: "Voir mon profil professionnel",
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFF1E5D8F),
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                ),
              ),
              
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent), 
                onPressed: () => _handleLogout(context),
              ),
            ],
          )
        ],
      ),
    );
  }
}