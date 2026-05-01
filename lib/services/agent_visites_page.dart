// lib/services/agent_visites_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';

class AgentVisitesPage extends StatefulWidget {
  const AgentVisitesPage({super.key});

  @override
  State<AgentVisitesPage> createState() => _AgentVisitesPageState();
}

class _AgentVisitesPageState extends State<AgentVisitesPage> {
  bool _isUpdating = false;

  Future<void> _terminerVisite(String visiteId, String propertyRef, String clientId) async {
    setState(() => _isUpdating = true);
    
    try {
      await FirebaseFirestore.instance.collection('visites').doc(visiteId).update({
        'statut': 'terminee',
        'dateFinEffective': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Visite terminée pour $propertyRef. Notification envoyée.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentId = context.read<UserProfileProvider>().userData?.uid;

    return Scaffold(
      // ✅ Correction ici : appBar au lieu de app_bar
      appBar: AppBar(
        title: const Text("Mes Visites du Jour"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('visites')
            .where('agentId', isEqualTo: agentId)
            .where('statut', isEqualTo: 'programmee')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Aucune visite prévue pour le moment."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Réf : ${data['propertyRef'] ?? 'N/A'}", 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const Icon(Icons.timer_outlined, color: Colors.orange),
                        ],
                      ),
                      const Divider(),
                      Text("Client : ${data['clientName'] ?? 'Inconnu'}"),
                      Text("Heure : ${data['heureRdv'] ?? '--:--'}"),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text("MARQUER COMME TERMINÉE"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _isUpdating 
                            ? null 
                            : () => _terminerVisite(doc.id, data['propertyRef'], data['clientId']),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}