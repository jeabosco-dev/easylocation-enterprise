import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OngletPerformance extends StatefulWidget {
  const OngletPerformance({super.key});

  @override
  State<OngletPerformance> createState() => _OngletPerformanceState();
}

class _OngletPerformanceState extends State<OngletPerformance> {
  // ✅ HARMONISÉ avec OngletEquipe
  final List<String> _equipeRoles = [
    'super_admin', 'comptable', 'rh', 'tech_support', 
    'marketing', 'operations', 'certificateur', 'logistique'
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 25),
          Expanded(
            child: _buildPerformanceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Classement Performance", 
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        Text("Nombre de biens immobiliers recrutés par agent", 
          style: TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPerformanceList() {
    return StreamBuilder<QuerySnapshot>(
      // On récupère les membres de l'équipe (ceux définis dans OngletEquipe)
      stream: FirebaseFirestore.instance
          .collection('utilisateurs')
          .where('role', whereIn: _equipeRoles)
          .snapshots(),
      builder: (context, teamSnapshot) {
        if (teamSnapshot.hasError) return const Center(child: Text("Erreur de chargement"));
        if (!teamSnapshot.hasData) return const Center(child: CircularProgressIndicator());

        final agents = teamSnapshot.data!.docs;

        // On écoute la collection 'proprietes' (ton parc immobilier)
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('proprietes').snapshots(),
          builder: (context, propSnapshot) {
            if (!propSnapshot.hasData) return const Center(child: CircularProgressIndicator());

            final allProperties = propSnapshot.data!.docs;

            // Calcul des scores
            List<Map<String, dynamic>> performanceData = agents.map((agentDoc) {
              final agentData = agentDoc.data() as Map<String, dynamic>;
              final String agentUid = agentDoc.id;
              
              // On compte les biens recrutés par cet UID
              final int score = allProperties.where((p) {
                final pData = p.data() as Map<String, dynamic>;
                // Vérifie si l'ID de l'agent est stocké dans 'agent_uid' ou 'createur_id'
                return pData['agent_uid'] == agentUid || pData['createur_id'] == agentUid;
              }).length;

              return {
                'name': "${agentData['prenom'] ?? ''} ${agentData['nom'] ?? ''}",
                'role': agentData['role'] ?? 'agent',
                'score': score,
                'statut': agentData['statut'] ?? 'actif',
              };
            }).toList();

            // Tri descendant (Le meilleur en premier)
            performanceData.sort((a, b) => b['score'].compareTo(a['score']));

            return ListView.builder(
              itemCount: performanceData.length,
              itemBuilder: (context, index) {
                final item = performanceData[index];
                // Calcul du ratio pour la barre de progression (max = 1er du classement)
                final double progress = performanceData[0]['score'] > 0 
                    ? item['score'] / performanceData[0]['score'] 
                    : 0;

                return _buildPerformanceCard(item, index + 1, progress);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPerformanceCard(Map<String, dynamic> item, int rank, double progress) {
    Color rankColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey.shade400 : Colors.blueGrey.shade100);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rankColor,
          child: Text("$rank", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['role'].toString().toUpperCase(), style: const TextStyle(fontSize: 10)),
            const SizedBox(height: 5),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[100],
              color: progress > 0.7 ? Colors.green : Colors.blue,
              minHeight: 4,
            ),
          ],
        ),
        trailing: Text("${item['score']}\nBIENS", 
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        ),
      ),
    );
  }
}
