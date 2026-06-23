// lib/web_admin/marketing_module.dart
import 'package:flutter/material.dart';
import '../../widgets/admin/analyse_proprietes_widget.dart';
import '../../widgets/admin/analyse_commune_widget.dart';
import 'package:easylocation_mvp/services/location_service.dart';

class MarketingModule extends StatefulWidget {
  const MarketingModule({super.key});

  @override
  State<MarketingModule> createState() => _MarketingModuleState();
}

class _MarketingModuleState extends State<MarketingModule> {
  final LocationService _locService = LocationService();
  
  String? selectedProvince;
  String? selectedVille;
  String? selectedCommune;

  List<String> _provinces = []; 
  List<String> _villes = [];
  List<String> _communes = [];

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  Future<void> _loadProvinces() async {
    final provinces = await _locService.getProvinces();
    setState(() => _provinces = provinces);
  }

  Future<void> _updateFilters({String? province, String? ville}) async {
    if (province != null) {
      final villes = await _locService.getVilles(province);
      setState(() => _villes = villes);
    }
    if (province != null && ville != null) {
      final communes = await _locService.getCommunes(province, ville);
      setState(() => _communes = communes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderWithFilters(),
          const SizedBox(height: 32),
          
          const Text("Répartition de l'Audience", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          AnalyseCommuneWidget(
            provinceFiltre: selectedProvince,
            villeFiltre: selectedVille,
            communeFiltre: selectedCommune,
          ),
          
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 40),

          // --- GRILLE PERFORMANCE ---
          LayoutBuilder(builder: (context, constraints) {
            double cardWidth = constraints.maxWidth > 1100 ? (constraints.maxWidth / 2) - 20 : constraints.maxWidth;
            return Wrap(
              spacing: 20, runSpacing: 20,
              children: [
                _buildPerformanceCard(cardWidth, 'views', 'Top Visibilité', Colors.blueAccent),
                _buildPerformanceCard(cardWidth, 'favoriteCount', 'Top Coups de Cœur', Colors.pinkAccent),
                _buildPerformanceCard(cardWidth, 'shares', 'Top Viraux', Colors.orangeAccent),
                _buildPerformanceCard(cardWidth, 'rating', 'Top Qualité', Colors.purpleAccent),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderWithFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Tableau de Bord Marketing", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            _filterBox("Province", selectedProvince, _provinces, (val) {
              setState(() {
                selectedProvince = val;
                selectedVille = null;
                selectedCommune = null;
                _villes = []; 
                _communes = [];
              });
              _updateFilters(province: val);
            }),
            _filterBox("Ville", selectedVille, _villes, (val) {
              setState(() {
                selectedVille = val;
                selectedCommune = null;
                _communes = []; 
              });
              _updateFilters(province: selectedProvince, ville: val);
            }),
            _filterBox("Commune", selectedCommune, _communes, (val) {
              setState(() => selectedCommune = val);
            }),
            IconButton(
              onPressed: () => setState(() {
                selectedProvince = null; 
                selectedVille = null; 
                selectedCommune = null;
                _villes = [];
                _communes = [];
              }), 
              icon: const Icon(Icons.refresh, color: Colors.redAccent)
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterBox(String label, String? val, List<String> items, Function(String?) onChange) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
      child: DropdownButton<String>(
        value: val,
        hint: Text(label),
        items: [
          const DropdownMenuItem(value: null, child: Text("Toutes")),
          ...items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))),
        ],
        onChanged: onChange,
      ),
    );
  }

  Widget _buildPerformanceCard(double width, String critere, String titre, Color color) {
    return SizedBox(
      width: width,
      child: AnalyseProprietesWidget(
        // Utilisation de la ValueKey pour forcer la reconstruction et le rafraîchissement des données
        key: ValueKey('$selectedProvince-$selectedVille-$selectedCommune-$critere'),
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