// lib/web_admin/marketing_module.dart

import 'package:flutter/material.dart';
import '../../widgets/admin/analyse_proprietes_widget.dart';
import '../../widgets/admin/analyse_commune_widget.dart';
import '../../donnees/localisation_donnees.dart';

class MarketingModule extends StatefulWidget {
  const MarketingModule({super.key});

  @override
  State<MarketingModule> createState() => _MarketingModuleState();
}

class _MarketingModuleState extends State<MarketingModule> {
  // Variables d'état pour le filtrage triple
  String? selectedProvince;
  String? selectedVille;
  String? selectedCommune;

  @override
  Widget build(BuildContext context) {
    // 1. Extraction des Provinces
    List<String> provinces = provincesCongo.map((p) => p.nom).toList();
    
    // 2. Extraction des Villes (dépend de la province)
    List<String> villes = [];
    if (selectedProvince != null) {
      var provData = provincesCongo.firstWhere((p) => p.nom == selectedProvince);
      villes = provData.villes.keys.where((v) => v != 'Autre').toList();
    }

    // 3. Extraction des Communes (dépend de la ville)
    List<String> communes = [];
    if (selectedProvince != null && selectedVille != null) {
      var provData = provincesCongo.firstWhere((p) => p.nom == selectedProvince);
      var villeData = provData.villes[selectedVille];
      if (villeData != null) {
        communes = villeData.keys.where((c) => c != 'Autre').toList();
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- EN-TÊTE ET FILTRES DYNAMIQUES ---
          _buildHeaderWithFilters(provinces, villes, communes),
          
          const SizedBox(height: 32),
          
          // --- SECTION 1 : ANALYSE SECTORIELLE (CAMEMBERT) ---
          const Row(
            children: [
              Icon(Icons.pie_chart_outline, color: Colors.indigo),
              SizedBox(width: 10),
              Text(
                "Répartition de l'Audience",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Envoi des 3 filtres au Camembert
          AnalyseCommuneWidget(
            provinceFiltre: selectedProvince,
            villeFiltre: selectedVille,
            communeFiltre: selectedCommune,
          ),
          
          const SizedBox(height: 40),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 40),

          // --- SECTION 2 : PERFORMANCE INDIVIDUELLE (TOP 10) ---
          const Row(
            children: [
              Icon(Icons.trending_up, color: Color(0xFF1E293B)),
              SizedBox(width: 10),
              Text(
                "Performance Individuelle des Biens",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          LayoutBuilder(builder: (context, constraints) {
            double width = constraints.maxWidth;
            double cardWidth = width > 1100 ? (width / 2) - 20 : width;

            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                _buildPerformanceCard(cardWidth, 'views', 'Top Visibilité (Vues)', Colors.blueAccent),
                _buildPerformanceCard(cardWidth, 'favoriteCount', 'Top Coups de Cœur', Colors.pinkAccent),
                _buildPerformanceCard(cardWidth, 'shares', 'Top Viraux (Partages)', Colors.orangeAccent),
                _buildPerformanceCard(cardWidth, 'rating', 'Top Qualité (Notes)', Colors.purpleAccent),
              ],
            );
          }),
        ],
      ),
    );
  }

  // Widget pour construire l'en-tête et la barre de filtres
  Widget _buildHeaderWithFilters(List<String> provinces, List<String> villes, List<String> communes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tableau de Bord Marketing",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 20),
        
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Filtre Province
            _filterBox("Province", selectedProvince, provinces, (val) {
              setState(() {
                selectedProvince = val;
                selectedVille = null; // Reset cascade
                selectedCommune = null;
              });
            }),
            
            // Filtre Ville
            _filterBox("Ville", selectedVille, villes, (val) {
              setState(() {
                selectedVille = val;
                selectedCommune = null; // Reset cascade
              });
            }),
            
            // Filtre Commune
            _filterBox("Commune", selectedCommune, communes, (val) {
              setState(() {
                selectedCommune = val;
              });
            }),

            // Bouton Reset
            if (selectedProvince != null)
              IconButton(
                onPressed: () => setState(() {
                  selectedProvince = null;
                  selectedVille = null;
                  selectedCommune = null;
                }),
                icon: const Icon(Icons.refresh, color: Colors.redAccent),
                tooltip: "Réinitialiser les filtres",
              ),
          ],
        ),
      ],
    );
  }

  // Template pour chaque Dropdown de filtre
  Widget _filterBox(String label, String? currentVal, List<String> items, Function(String?) onChange) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentVal,
          hint: Text(label, style: const TextStyle(fontSize: 14)),
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          items: [
            DropdownMenuItem(value: null, child: Text("Toutes ($label)")),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: onChange,
        ),
      ),
    );
  }

  // Helper pour les cartes de performance avec le triple filtre
  Widget _buildPerformanceCard(double width, String critere, String titre, Color color) {
    return SizedBox(
      width: width,
      child: AnalyseProprietesWidget(
        critere: critere,
        titre: titre,
        themeColor: color,
        provinceFiltre: selectedProvince,
        villeFiltre: selectedVille,
        communeFiltre: selectedCommune,
      ),
    );
  }
}
