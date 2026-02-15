// lib/web_admin/logistique_demenagement_module.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 

class LogistiqueDemenagementModule extends StatelessWidget {
  const LogistiqueDemenagementModule({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Logistique & Déménagement", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.blueGrey.shade900,
          elevation: 2,
          bottom: const TabBar(
            indicatorColor: Colors.orange,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.card_giftcard), text: "CADEAUX"),
              Tab(icon: Icon(Icons.local_shipping), text: "DÉMÉNAGEMENT"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LogistiqueView(type: "cadeau"),
            _LogistiqueView(type: "transport"),
          ],
        ),
      ),
    );
  }
}

class _LogistiqueView extends StatefulWidget {
  final String type;
  const _LogistiqueView({required this.type});

  @override
  State<_LogistiqueView> createState() => _LogistiqueViewState();
}

class _LogistiqueViewState extends State<_LogistiqueView> {
  bool _showOnlyPending = true; 

  @override
  Widget build(BuildContext context) {
    return Column(
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
                _showOnlyPending ? "⏳ TRAVAIL EN COURS" : "📚 HISTORIQUE COMPLET",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800, fontSize: 13),
              ),
              Row(
                children: [
                  const Text("Masquer terminé", style: TextStyle(fontSize: 12, color: Colors.grey)),
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
          child: _LogistiqueList(type: widget.type, hideFinished: _showOnlyPending),
        ),
      ],
    );
  }
}

class _LogistiqueList extends StatelessWidget {
  final String type;
  final bool hideFinished;

  const _LogistiqueList({required this.type, required this.hideFinished});

  Future<void> _lancerAppel(String? telephone) async {
    if (telephone == null || telephone == "N/A" || telephone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: telephone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      debugPrint("Impossible de lancer l'appel: $e");
    }
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    final field = type == "cadeau" ? 'statutCadeau' : 'statutTransport';
    await FirebaseFirestore.instance.collection('factures').doc(docId).update({field: newStatus});
  }

  @override
  Widget build(BuildContext context) {
    final String statusField = type == "cadeau" ? 'statutCadeau' : 'statutTransport';
    
    // Requête simplifiée car l'index est maintenant présent
    Query query = FirebaseFirestore.instance.collection('factures');

    if (type == "cadeau") {
      query = query.where('cadeauId', isNotEqualTo: 'Aucun');
    } else {
      query = query.where('transportChoisi', isEqualTo: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('dateCreation', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Erreur de chargement : ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.orange));
        
        final allDocs = snapshot.data!.docs;
        final docs = hideFinished 
            ? allDocs.where((d) => (d.data() as Map<String, dynamic>)[statusField] != 'termine').toList()
            : allDocs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text("Aucune demande en attente", style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String currentStatus = data[statusField] ?? 'nouveau';

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(currentStatus),
                  child: Icon(type == "cadeau" ? Icons.card_giftcard : Icons.local_shipping, color: Colors.white, size: 20),
                ),
                title: Text(data['nomClient'] ?? "Client", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Logement: ${data['refMaison'] ?? 'N/A'} • ${currentStatus.toUpperCase()}"),
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
                        if (type == "cadeau") ...[
                          _infoLine(Icons.redeem, "Cadeau: ${data['cadeauId']}"),
                          if (data['cadeauTaille'] != null) _infoLine(Icons.straighten, "Taille: ${data['cadeauTaille']}"),
                        ],
                        const SizedBox(height: 20),
                        const Text("ACTIONS DE SUIVI :", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _statusBtn(doc.id, "nouveau", Colors.red.shade400, currentStatus == "nouveau"),
                            _statusBtn(doc.id, "en_cours", Colors.orange.shade400, currentStatus == "en_cours"),
                            _statusBtn(doc.id, "termine", Colors.green.shade400, currentStatus == "termine"),
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
        Text(text, style: TextStyle(color: color, fontWeight: color != null ? FontWeight.bold : FontWeight.normal, fontSize: 14))
      ]),
    );
  }

  Widget _statusBtn(String id, String status, Color color, bool isCurrent) {
    return Opacity(
      opacity: isCurrent ? 1.0 : 0.6,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color, 
          foregroundColor: Colors.white,
          elevation: isCurrent ? 4 : 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: () => _updateStatus(id, status),
        child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
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
