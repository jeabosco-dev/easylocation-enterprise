// lib/services/agent_visites_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:easylocation_mvp/constants/constants.dart'; 
import '../providers/user_profile_provider.dart';
import '../views/visites/decision_visite_page.dart';

class AgentVisitesPage extends StatefulWidget {
  const AgentVisitesPage({super.key});

  @override
  State<AgentVisitesPage> createState() => _AgentVisitesPageState();
}

class _AgentVisitesPageState extends State<AgentVisitesPage> {
  bool _isUpdating = false;

  /// Clôture de la rencontre et synchronisation immédiate de la facture
  Future<void> _terminerVisite({
    required String factureId,
    required String propertyRef,
    required String? propertyId,
  }) async {
    if (_isUpdating) return; 
    setState(() => _isUpdating = true);
    
    try {
      final agentId = context.read<UserProfileProvider>().userData?.uid;

      if (agentId == null || agentId.isEmpty) {
        throw Exception("Identifiant agent introuvable. Veuillez vous reconnecter.");
      }

      // Écriture exclusive dans la clé unifiée
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.factures)
          .doc(factureId)
          .update({
        FactureFields.etapeDossier: FactureFields.etapeVisiteTerminee, 
        FactureFields.agentTerrainId: agentId, 
        'dateFinEffective': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _proposerDecisionImmediate(propertyRef, propertyId, factureId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la clôture : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _passerAppel(String? telephone) async {
    if (telephone == null || telephone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Numéro de téléphone indisponible.")),
      );
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: telephone.trim());
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible de lancer l'appel vers $telephone")),
      );
    }
  }

  void _proposerDecisionImmediate(String propertyRef, String? propertyId, String factureId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Prendre la décision", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Le client souhaite-t-il valider ou refuser le logement $propertyRef immédiatement avec vous ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("PLUS TARD (SUR SON APP)", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
            onPressed: () {
              Navigator.pop(context); 
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DecisionVisitePage(
                    factureId: factureId,
                    propertyRef: propertyRef,
                    propertyId: propertyId, 
                    // 🎯 Nettoyage réussi : visiteId retiré d'ici pour s'aligner sur DecisionVisitePage
                  ),
                ),
              );
            },
            child: const Text("PASSER LE TÉLÉPHONE AU CLIENT", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserProfileProvider>().userData;
    final currentAgentId = userData?.uid;
    // Standardisation de la ville de l'agent en minuscules pour éviter les ratés de casse
    final agentVille = userData?.ville?.toLowerCase().trim() ?? '';

    if (currentAgentId == null || currentAgentId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Mes Missions Logistiques"),
          backgroundColor: Colors.blue.shade900,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Missions Logistiques"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        bottom: _isUpdating 
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(backgroundColor: Colors.orange),
              )
            : null,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🎯 OPTIMISATION REQUÊTE : Filtrage exclusif sur l'état de réussite de transaction
        stream: FirebaseFirestore.instance
            .collection(FirestoreCollections.factures)
            .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPaid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Erreur de synchronisation : ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Aucun dossier payé sur l'ensemble du réseau.",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          // 🛠️ FILTRAGE LOGISTIQUE EN LOCAL
          final depechesFiltrees = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            
            final String etape = (data[FactureFields.etapeDossier] ?? '').toString().toUpperCase().trim();
            final String assignedAgent = (data[FactureFields.agentTerrainId] ?? '').toString().trim();
            final String factureVille = (data['ville'] ?? data['villeClient'] ?? '').toString().toLowerCase().trim();

            // Règle 1 : État "PAYE"
            bool correspondEtape = (etape == 'PAYE');

            // Règle 2 : Zone géographique
            bool correspondVille = agentVille.isEmpty || factureVille.isEmpty || (factureVille == agentVille);

            // Règle 3 : Le dossier DOIT être spécifiquement assigné à cet agent.
            bool correspondAgent = (assignedAgent == currentAgentId);

            return correspondEtape && correspondVille && correspondAgent;
          }).toList();

          if (depechesFiltrees.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  "Aucun dossier payé à traiter pour votre secteur actuellement.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: depechesFiltrees.length,
            itemBuilder: (context, index) {
              var doc = depechesFiltrees[index];
              var data = doc.data() as Map<String, dynamic>;
              
              String factureId = doc.id;
              String propertyRef = data['refMaison'] ?? data['propertyRef'] ?? 'N/A';
              String? propertyId = data['propertyId'];
              String clientName = data['nomClient'] ?? data['clientName'] ?? 'Inconnu';
              String? clientPhone = data['telClient'] ?? data['clientPhone'];

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Réf : $propertyRef", 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0D47A1)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: const Text(
                              "PAYÉ",
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      
                      Text(
                        "Client : $clientName", 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 14),
                      
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.phone, color: Colors.blue),
                              label: const Text("APPELER"),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.blue),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _passerAppel(clientPhone),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                              label: const Text("VISITE TERMINÉE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _isUpdating 
                                  ? null 
                                  : () => _terminerVisite(
                                        factureId: factureId,
                                        propertyRef: propertyRef,
                                        propertyId: propertyId,
                                      ),
                            ),
                          ),
                        ],
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