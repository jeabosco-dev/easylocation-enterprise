// lib/web_admin/gestion_contrats_module.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ✅ Imports corrigés avec les bons noms de fichiers
import '../widgets/admin/onglet_contrat_bailleurs.dart';
import '../widgets/admin/onglet_contrat_locataires.dart';

// Import du provider
import '../providers/contract_provider.dart';

class GestionContratsModule extends StatefulWidget {
  const GestionContratsModule({super.key});

  @override
  State<GestionContratsModule> createState() => _GestionContratsModuleState();
}

class _GestionContratsModuleState extends State<GestionContratsModule> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Chargement initial des données pour l'administration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContractProvider>().loadAllActiveContractsForAdmin();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header avec onglets institutionnels EasyLocation
        Material(
          elevation: 1,
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF1A5276),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF1A5276),
            indicatorWeight: 3,
            tabs: const [
              Tab(text: "PORTEFEUILLE BAILLEURS"),
              Tab(text: "AUDIT & CERTIFICATIONS"),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              // ✅ Les noms des classes correspondent maintenant aux fichiers widgets
              OngletContratBailleurs(), 
              OngletContratLocataires(),      
            ],
          ),
        ),
      ],
    );
  }
}