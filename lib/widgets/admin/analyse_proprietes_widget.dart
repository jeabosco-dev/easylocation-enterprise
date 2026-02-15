// lib/widgets/admin/analyse_proprietes_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/export_service.dart';

class AnalyseProprietesWidget extends StatelessWidget {
  final String critere; 
  final String titre;
  final Color themeColor;
  final String? provinceFiltre; // ✅ Ajout Province
  final String? villeFiltre;    // ✅ Déjà présent
  final String? communeFiltre;  // ✅ Ajout Commune

  const AnalyseProprietesWidget({
    super.key,
    required this.critere,
    required this.titre,
    this.themeColor = Colors.blueAccent,
    this.provinceFiltre,
    this.villeFiltre,
    this.communeFiltre,
  });

  // ✅ Gestion de l'export avec les filtres géographiques
  void _handleExport(List<QueryDocumentSnapshot> docs) {
    ExportService.exportPropertiesToExcel(
      docs: docs,
      fileName: "Rapport_Top_${critere}_${villeFiltre ?? 'Global'}",
      sheetName: "Analyses",
      headers: ['REFERENCE', 'PROVINCE', 'VILLE', 'COMMUNE', 'VALEUR ($critere)'],
      keys: ['referenceCourte', 'province', 'ville', 'commune', critere], 
    );
  }

  @override
  Widget build(BuildContext context) {
    String fieldToSort = critere == 'rating' ? 'totalRating' : critere;
    bool isDateCritere = critere.toLowerCase().contains('boost') || critere.toLowerCase().contains('date');
    
    // ✅ Construction dynamique de la requête TRIPLE FILTRE
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

    // Application du tri
    query = query.orderBy(fieldToSort, descending: !isDateCritere).limit(10);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 200, child: Center(child: LinearProgressIndicator()));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20), 
              child: Center(child: Text("Aucune donnée pour cette zone.")),
            ),
          );
        }

        final allDocs = snapshot.data!.docs;
        final top5Docs = allDocs.take(5).toList();
        
        // Calcul de la valeur max pour les barres de progression
        double maxValue = 1.0;
        if (top5Docs.isNotEmpty) {
          final firstData = top5Docs.first.data() as Map<String, dynamic>;
          maxValue = _getVal(firstData, critere);
          if (maxValue <= 0) maxValue = 1.0;
        }

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
                _buildHeader(allDocs),
                const SizedBox(height: 25),
                if (!isDateCritere) _buildBarChart(top5Docs) else _buildDateInfoBanner(),
                const SizedBox(height: 25),
                const Text("Détails du classement", 
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 10),
                ...top5Docs.map((doc) => _buildPropertyItem(doc, maxValue, isDateCritere)).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  double _getVal(Map<String, dynamic> data, String key) {
    if (key == 'rating') {
      double total = (data['totalRating'] ?? 0).toDouble();
      int count = (data['ratingCount'] ?? 0).toInt();
      return count > 0 ? total / count : 0.0;
    }
    return (data[key] ?? 0).toDouble();
  }

  Widget _buildHeader(List<QueryDocumentSnapshot> docs) {
    String subTitle = "Données globales";
    if (communeFiltre != null) {
      subTitle = "Secteur : $communeFiltre ($villeFiltre)";
    } else if (villeFiltre != null) {
      subTitle = "Ville : $villeFiltre";
    } else if (provinceFiltre != null) {
      subTitle = "Province : $provinceFiltre";
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              Text(
                subTitle, 
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.file_download, color: Colors.green),
          onPressed: () => _handleExport(docs),
        )
      ],
    );
  }

  Widget _buildBarChart(List<QueryDocumentSnapshot> docs) {
    return SizedBox(
      height: 80,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: docs.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: _getVal(e.value.data() as Map<String, dynamic>, critere),
                  color: themeColor,
                  width: 14,
                  borderRadius: BorderRadius.circular(4),
                )
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPropertyItem(QueryDocumentSnapshot doc, double max, bool isDate) {
    final data = doc.data() as Map<String, dynamic>;
    
    String ref = data['referenceCourte'] ?? data['reference'] ?? 'BIEN';
    String zone = data['commune'] ?? data['ville'] ?? 'Inconnu';
    
    double val = _getVal(data, critere);
    String displayValue = critere == 'rating' ? "${val.toStringAsFixed(1)} ⭐" : val.toInt().toString();
    
    if (isDate && data[critere] is Timestamp) {
      DateTime dt = (data[critere] as Timestamp).toDate();
      displayValue = "${dt.day}/${dt.month}";
    }

    double progress = (max > 0) ? (val / max).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text("$ref • $zone", 
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              ),
              Text(displayValue, style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: themeColor.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(themeColor),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(10),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
      child: const Text("Trié par date de publication ou boost récent", 
        style: TextStyle(fontSize: 11, color: Colors.blue)),
    );
  }
}
