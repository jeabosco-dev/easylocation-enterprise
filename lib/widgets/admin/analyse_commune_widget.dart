// lib/widgets/admin/analyse_commune_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyseCommuneWidget extends StatelessWidget {
  final String? provinceFiltre;
  final String? villeFiltre;
  final String? communeFiltre;

  const AnalyseCommuneWidget({
    super.key,
    this.provinceFiltre,
    this.villeFiltre,
    this.communeFiltre,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Construction de la requête avec filtres en cascade
    Query query = FirebaseFirestore.instance.collection('proprietes');

    if (provinceFiltre != null) {
      query = query.where('province', isEqualTo: provinceFiltre);
    }
    if (villeFiltre != null) {
      query = query.where('ville', isEqualTo: villeFiltre);
    }
    if (communeFiltre != null) {
      query = query.where('commune', isEqualTo: communeFiltre);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text("Aucune donnée pour cette zone.")),
            ),
          );
        }

        // 2. Agrégation des données (Vues par secteur)
        Map<String, int> statsMap = {};
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          
          // On choisit l'étiquette la plus précise selon le filtre actif
          String label = "Inconnu";
          if (communeFiltre != null) {
            label = data['referenceCourte'] ?? data['reference'] ?? 'Bien';
          } else if (villeFiltre != null) {
            label = data['commune'] ?? 'Autre';
          } else if (provinceFiltre != null) {
            label = data['ville'] ?? 'Autre';
          } else {
            label = data['province'] ?? 'Autre';
          }

          int views = (data['views'] ?? 0).toInt();
          statsMap[label] = (statsMap[label] ?? 0) + views;
        }

        // Tri pour le top
        var sortedEntries = statsMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        // On limite à 6 sections pour la lisibilité du camembert
        var topEntries = sortedEntries.take(6).toList();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDynamicHeader(),
                const SizedBox(height: 30),
                
                // Graphique
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: _buildChartSections(topEntries),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                
                const SizedBox(height: 25),
                const Text(
                  "Détails de l'audience", 
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
                const SizedBox(height: 10),
                
                // Légende
                ...topEntries.asMap().entries.map((e) {
                  return _buildLegend(
                    e.value.key, 
                    e.value.value, 
                    _getColor(e.key),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDynamicHeader() {
    String lieu = communeFiltre ?? villeFiltre ?? provinceFiltre ?? "Congo (RDC)";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Part d'Audience : $lieu", 
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          communeFiltre != null 
            ? "Comparaison des biens les plus vus dans cette commune"
            : "Répartition des vues par zone géographique", 
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildChartSections(List<MapEntry<String, int>> entries) {
    return entries.asMap().entries.map((e) {
      final index = e.key;
      final data = e.value;

      return PieChartSectionData(
        color: _getColor(index),
        value: data.value.toDouble(),
        title: '', // On cache le titre sur le graphe pour plus de propreté
        radius: 50,
      );
    }).toList();
  }

  Color _getColor(int index) {
    List<Color> colors = [
      Colors.indigo.shade400,
      Colors.blue.shade400,
      Colors.cyan.shade400,
      Colors.teal.shade400,
      Colors.orange.shade400,
      Colors.pink.shade400,
    ];
    return colors[index % colors.length];
  }

  Widget _buildLegend(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10, height: 10, 
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Text("$value vues", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
