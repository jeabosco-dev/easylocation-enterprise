import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/export_service.dart';

class OngletClients extends StatefulWidget {
  const OngletClients({super.key});

  @override
  State<OngletClients> createState() => _OngletClientsState();
}

class _OngletClientsState extends State<OngletClients> {
  String _searchQuery = "";

  // Fonction pour afficher la boîte de dialogue de confirmation
  void _showConfirmDialog(BuildContext context, String docId, bool currentBlockedStatus, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(currentBlockedStatus ? "Débloquer l'utilisateur" : "Bloquer l'utilisateur"),
          content: Text("Êtes-vous sûr de vouloir ${currentBlockedStatus ? 'débloquer' : 'bloquer'} l'accès pour $name ?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ANNULER", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('utilisateurs')
                    .doc(docId)
                    .update({'isBlocked': !currentBlockedStatus});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Statut de $name mis à jour"),
                    backgroundColor: currentBlockedStatus ? Colors.green : Colors.orange,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: currentBlockedStatus ? Colors.green : Colors.red,
              ),
              child: Text(currentBlockedStatus ? "DÉBLOQUER" : "BLOQUER"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('utilisateurs').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final allDocs = snapshot.data!.docs;
        
        final filteredDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nomComplet = "${data['prenom'] ?? ''} ${data['nom'] ?? ''}".toLowerCase();
          return nomComplet.contains(_searchQuery);
        }).toList();

        return Column(
          children: [
            _buildTopBar(filteredDocs),
            const SizedBox(height: 20),
            Expanded(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('UTILISATEUR', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('RÔLE', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('STATUT', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: filteredDocs.map((doc) => _buildDataRow(doc)).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(List<QueryDocumentSnapshot> docs) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: "Rechercher un client (Nom/Prénom)...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), 
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          ),
        ),
        const SizedBox(width: 20),
        ElevatedButton.icon(
          onPressed: () => ExportService.exportPropertiesToExcel(
            docs: docs,
            fileName: "Export_Clients_${DateFormat('dd_MM_yyyy').format(DateTime.now())}",
            sheetName: "Clients",
            headers: ['NOM', 'PRÉNOM', 'RÔLE', 'STATUT'],
            keys: ['nom', 'prenom', 'activeRole', 'isBlocked'],
          ),
          icon: const Icon(Icons.file_download),
          label: const Text("Exporter Excel"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700], 
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        )
      ],
    );
  }

  DataRow _buildDataRow(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bool isBlocked = data['isBlocked'] ?? false;
    final String fullName = "${data['prenom'] ?? ''} ${data['nom'] ?? ''}";
    
    return DataRow(cells: [
      DataCell(Text(fullName, style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text(data['activeRole'] ?? 'Client')),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isBlocked ? Colors.red[50] : Colors.green[50], 
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isBlocked ? "Bloqué" : "Actif", 
          style: TextStyle(
            color: isBlocked ? Colors.red : Colors.green, 
            fontSize: 12, 
            fontWeight: FontWeight.bold,
          ),
        ),
      )),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.visibility, color: Colors.blue), 
            onPressed: () { /* Détails utilisateur */ },
          ),
          IconButton(
            icon: Icon(
              isBlocked ? Icons.lock_open : Icons.block, 
              color: isBlocked ? Colors.orange : Colors.red,
            ),
            onPressed: () => _showConfirmDialog(context, doc.id, isBlocked, fullName),
            tooltip: isBlocked ? "Débloquer" : "Bloquer",
          ),
        ],
      )),
    ]);
  }
}
