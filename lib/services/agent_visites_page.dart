import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:easylocation_mvp/constants/all_constants.dart';
import '../providers/user_profile_provider.dart';
import '../views/visites/decision_visite_page.dart';

class AgentVisitesPage extends StatefulWidget {
  const AgentVisitesPage({super.key});

  @override
  State<AgentVisitesPage> createState() => _AgentVisitesPageState();
}

class _AgentVisitesPageState extends State<AgentVisitesPage> {
  bool _isUpdating = false;

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
            onPressed: () async {
              // 🎯 ACTION : On s'assure que confirmationLocataire est null pour que la bannière apparaisse chez le locataire
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.factures)
                  .doc(factureId)
                  .update({
                'confirmationLocataire': FieldValue.delete(),
              });
              
              if (mounted) Navigator.pop(context);
            },
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
    final agentVille = userData?.ville?.toLowerCase().trim() ?? '';

    if (currentAgentId == null || currentAgentId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Mes Missions Logistiques")),
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
        stream: FirebaseFirestore.instance
            .collection(FirestoreCollections.factures)
            .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPaid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Aucun dossier payé sur l'ensemble du réseau."));
          }

          final depechesFiltrees = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String etape = (data[FactureFields.etapeDossier] ?? '').toString().toUpperCase().trim();
            final String assignedAgent = (data[FactureFields.agentTerrainId] ?? '').toString().trim();
            final String factureVille = (data['ville'] ?? data['villeClient'] ?? '').toString().toLowerCase().trim();

            bool correspondEtape = (etape == 'PAYE');
            bool correspondVille = agentVille.isEmpty || factureVille.isEmpty || (factureVille == agentVille);
            bool correspondAgent = (assignedAgent == currentAgentId);

            return correspondEtape && correspondVille && correspondAgent;
          }).toList();

          if (depechesFiltrees.isEmpty) {
            return const Center(child: Text("Aucun dossier payé à traiter pour votre secteur."));
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
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Réf : $propertyRef", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const Text("PAYÉ", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(),
                      Text("Client : $clientName"),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: () => _passerAppel(clientPhone), child: const Text("APPELER"))),
                          const SizedBox(width: 10),
                          Expanded(child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                            onPressed: () => _terminerVisite(factureId: factureId, propertyRef: propertyRef, propertyId: propertyId),
                            child: const Text("VISITE TERMINÉE", style: TextStyle(color: Colors.white)),
                          )),
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