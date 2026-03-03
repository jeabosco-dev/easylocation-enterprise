import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

// ✅ IMPORTATIONS DES MODULES (Tous situés dans lib/web_admin/)
import 'sidebar_menu.dart';
import 'admin_dashboard.dart';
import 'finance_module.dart';
import 'marketing_module.dart';
import 'utilisateurs_page.dart'; 
import 'admin_staff_management.dart';
import 'operations_module.dart'; 
import 'biens_page.dart';         
import 'rh_page.dart';           
import 'logistique_demenagement_module.dart';
import 'observatoire_module.dart';
import 'admin_settings_page.dart'; // ✅ Nouvel import ajouté pour la gestion des taux

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

  // 🛠 GÉNÉRATION DYNAMIQUE DES ONGLETS SELON LES DROITS
  List<Map<String, dynamic>> _getAvailableTabs() {
    final List<Map<String, dynamic>> tabs = [
      {
        'label': 'Accueil', 
        'icon': Icons.dashboard, 
        'module': AdminDashboard(userName: _userName, userDirection: _userDirection)
      },
    ];

    // 🏠 Accès Catalogue des Biens
    if (_userRole == 'SUPER_ADMIN' || _userDirection == 'LOGISTIQUE' || _userDirection == 'DIRECTION GÉNÉRALE') {
      tabs.add({'label': 'Catalogue Biens', 'icon': Icons.home_work, 'module': const BiensPage()});
    }

    // 💰 Accès Finance
    if (_userRole == 'SUPER_ADMIN' || _userDirection == 'FINANCE' || _userDirection == 'DIRECTION GÉNÉRALE') {
      tabs.add({'label': 'Finance', 'icon': Icons.account_balance_wallet, 'module': const FinanceModule()});
    }

    // 📈 Accès Marketing
    if (_userRole == 'SUPER_ADMIN' || _userDirection == 'MARKETING' || _userDirection == 'DIRECTION GÉNÉRALE') {
      tabs.add({'label': 'Marketing', 'icon': Icons.analytics, 'module': const MarketingModule()});
    }

    // 🛠 Accès Opérations Terrain
    if (_userRole == 'SUPER_ADMIN' || _userDirection == 'LOGISTIQUE' || _userDirection == 'DIRECTION GÉNÉRALE') {
      tabs.add({'label': 'Opérations Terrain', 'icon': Icons.assignment_turned_in, 'module': const OperationsModule()});
    }

    // 🚚 Accès Logistique & Déménagement
    if (_userRole == 'SUPER_ADMIN' || _userDirection == 'LOGISTIQUE' || _userDirection == 'DIRECTION GÉNÉRALE') {
      tabs.add({
        'label': 'Logistique & Dém.', 
        'icon': Icons.local_shipping, 
        'module': const LogistiqueDemenagementModule()
      });
    }

    // 👥 Accès RH
    if (_userRole == 'SUPER_ADMIN' || _userDirection == 'RH' || _userDirection == 'DIRECTION GÉNÉRALE') {
      tabs.add({'label': 'Ressources Humaines', 'icon': Icons.badge, 'module': const RhPage()});
    }

    // 🌐 Accès Observatoire Tech
    if (_userRole == 'SUPER_ADMIN' || 
        _userDirection == 'DIRECTION GÉNÉRALE' || 
        _userDirection == 'DIRECTION PRODUIT & TECHNOLOGIE') {
      tabs.add({
        'label': 'Observatoire Tech', 
        'icon': Icons.remove_red_eye_rounded, 
        'module': const ObservatoireModule()
      });
    }

    // ✅ NOUVEAU : Paramètres Système (Taux de change USD/CDF et Commissions)
    // Réservé exclusivement au Super Admin et à la Direction Générale
    if (_userRole == 'SUPER_ADMIN' || _userDirection == 'DIRECTION GÉNÉRALE') {
      tabs.add({
        'label': 'Paramètres Système', 
        'icon': Icons.settings, 
        'module': const AdminSettingsPage() 
      });
    }

    // 🔐 Accès Gestion Équipe & Utilisateurs (SUPER_ADMIN seulement)
    if (_userRole == 'SUPER_ADMIN') {
      tabs.add({'label': 'Gestion Équipe', 'icon': Icons.verified_user_sharp, 'module': const AdminStaffManagement()});
      tabs.add({'label': 'Utilisateurs', 'icon': Icons.people, 'module': const UtilisateursPage()});
    }

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
    
    // Sécurité au cas où l'index sélectionné n'existe plus après un changement de rôle
    if (_selectedIndex >= availableTabs.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      body: Row(
        children: [
          // ✅ COMPOSANT SIDEBAR (Utilise la liste dynamique disponible)
          SidebarMenu(
            selectedIndex: _selectedIndex,
            availableTabs: availableTabs,
            onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
          ),
          
          const VerticalDivider(thickness: 1, width: 1),
          
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, availableTabs[_selectedIndex]['label']),
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

  Widget _buildTopBar(BuildContext context, String title) {
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
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E5D8F))),
          Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("$_userDirection | $_userRole", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              const SizedBox(width: 15),
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