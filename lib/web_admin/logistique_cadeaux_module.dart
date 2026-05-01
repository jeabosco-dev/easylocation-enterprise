// lib/web_admin/logistique_cadeaux_module.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:easylocation_mvp/constants/constants.dart'; 

class LogistiqueCadeauxModule extends StatefulWidget {
  const LogistiqueCadeauxModule({super.key});

  @override
  State<LogistiqueCadeauxModule> createState() => _LogistiqueCadeauxModuleState();
}

class _LogistiqueCadeauxModuleState extends State<LogistiqueCadeauxModule> {
  bool _showOnlyPending = true; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Logistique : Cadeaux de Bienvenue", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey.shade900,
        elevation: 2,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showOnlyPending ? "⏳ LIVRAISONS À FAIRE" : "📚 HISTORIQUE COMPLET",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800, fontSize: 13),
                ),
                Row(
                  children: [
                    const Text("Masquer livré", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Switch(
                      value: _showOnlyPending,
                      onChanged: (val) => setState(() => _showOnlyPending = val),
                      activeColor: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _CadeauxList(hideFinished: _showOnlyPending),
          ),
        ],
      ),
    );
  }
}

class _CadeauxList extends StatelessWidget {
  final bool hideFinished;

  const _CadeauxList({required this.hideFinished});

  Future<void> _lancerAppel(String? telephone) async {
    if (telephone == null || telephone == "N/A" || telephone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: telephone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Impossible de lancer l'appel: $e");
    }
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance.collection('factures').doc(docId).update({'statutCadeau': newStatus});
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('factures');

    // Filtre : Uniquement les factures payées qui ont un cadeau
    query = query.where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPaid)
                 .where('cadeauId', isNotEqualTo: 'Aucun');

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('dateCreation', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Erreur: ${snapshot.error}"));
        }

        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.orange));
        
        var docs = snapshot.data!.docs;
        
        // Filtrage en mémoire pour le statut "termine"
        if (hideFinished) {
          docs = docs.where((d) => (d.data() as Map<String, dynamic>)['statutCadeau'] != 'termine').toList();
        }

        if (docs.isEmpty) {
          return Center(child: Text("Aucun cadeau à livrer", style: TextStyle(color: Colors.grey.shade600)));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String currentStatus = data['statutCadeau'] ?? 'nouveau';

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(currentStatus),
                  child: const Icon(Icons.card_giftcard, color: Colors.white, size: 20),
                ),
                title: Text(data['nomClient'] ?? "Client", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Réf: ${data['refMaison'] ?? 'N/A'} • ${currentStatus.toUpperCase()}"),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        _infoLine(Icons.person, "Locataire: ${data['nomClient']}"),
                        InkWell(
                          onTap: () => _lancerAppel(data['telClient']),
                          child: _infoLine(Icons.phone, data['telClient'] ?? "N/A", color: Colors.blue.shade700),
                        ),
                        _infoLine(Icons.redeem, "Article: ${data['cadeauId']}"),
                        if (data['cadeauTaille'] != null) 
                          _infoLine(Icons.straighten, "Taille/Détail: ${data['cadeauTaille']}"),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _statusBtn(doc.id, "nouveau", Colors.red.shade400, currentStatus == "nouveau", Icons.fiber_new),
                            _statusBtn(doc.id, "en_cours", Colors.orange.shade400, currentStatus == "en_cours", Icons.sync),
                            _statusBtn(doc.id, "termine", Colors.green.shade400, currentStatus == "termine", Icons.check_circle),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoLine(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: color ?? Colors.blueGrey.shade400), 
        const SizedBox(width: 12), 
        Text(text, style: TextStyle(color: color, fontSize: 14))
      ]),
    );
  }

  Widget _statusBtn(String id, String status, Color color, bool isCurrent, IconData icon) {
    return Opacity(
      opacity: isCurrent ? 1.0 : 0.5,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color, 
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: () => _updateStatus(id, status),
        icon: Icon(icon, size: 14),
        label: Text(status == "en_cours" ? "EN COURS" : status.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "termine": return Colors.green.shade400;
      case "en_cours": return Colors.orange.shade400;
      default: return Colors.red.shade400;
    }
  }
}