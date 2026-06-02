// lib/widgets/admin/onglet_clients.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import 'package:easylocation_mvp/models/user_model.dart'; 
import '../../../services/export_service.dart';

class OngletClients extends StatefulWidget {
  const OngletClients({super.key});

  @override
  State<OngletClients> createState() => _OngletClientsState();
}

class _OngletClientsState extends State<OngletClients> {
  String _searchQuery = "";

  // ✅ Fiche détaillée utilisant le UserModel sécurisé
  void _showUserDetails(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                Text("Fiche Client Détaillée", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                const Divider(),
                
                _buildInfoSection(Icons.person, "Identité", user.nomComplet),
                _buildInfoSection(Icons.phone, "Téléphone", user.telephone),
                _buildInfoSection(Icons.email, "Email", user.email ?? "Non renseigné"),
                _buildInfoSection(Icons.location_on, "Adresse Complète", user.fullAddress),
                _buildInfoSection(Icons.account_balance_wallet, "Solde Portefeuille", "${user.walletBalance.toStringAsFixed(2)} USD"),
                _buildInfoSection(Icons.person_add, "ID Parrain", user.referrerId ?? "Aucun"),
                _buildInfoSection(Icons.security, "Rôle Actuel", user.activeRole.toUpperCase()),
                _buildInfoSection(Icons.calendar_today, "Membre depuis", user.createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(user.createdAt!) : "Inconnue"),

                const SizedBox(height: 30),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white), child: const Text("FERMER"))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoSection(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[700], size: 24),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.blue[900],
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue[900],
            tabs: const [
              Tab(icon: Icon(Icons.people_alt), text: "ACTIFS"),
              Tab(icon: Icon(Icons.archive), text: "ARCHIVES"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildClientList(isBlockedList: false), 
                _buildClientList(isBlockedList: true), 
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientList({required bool isBlockedList}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(FirestoreCollections.utilisateurs).where('isBlocked', isEqualTo: isBlockedList).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // ✅ Conversion & Typage
        final allUsers = snapshot.data!.docs.map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

        // ✅ Filtrage multi-critères (Identité complète + Email + Commune + Rôle)
        final filteredUsers = allUsers.where((u) {
          final query = _searchQuery.toLowerCase();
          final identity = "${u.prenom} ${u.nom} ${u.postnom}".toLowerCase();
          final email = (u.email ?? "").toLowerCase();
          
          return identity.contains(query) || 
                 email.contains(query) ||
                 u.telephone.contains(query) ||
                 u.commune.toLowerCase().contains(query) || 
                 u.activeRole.toLowerCase().contains(query);
        }).toList();

        final totalBailleurs = filteredUsers.where((u) => u.activeRole.toLowerCase() == 'bailleur').length;
        final totalLocataires = filteredUsers.where((u) => u.activeRole.toLowerCase() == 'locataire').length;

        return Column(
          children: [
            const SizedBox(height: 10),
            _buildStatsHeader(filteredUsers.length, totalBailleurs, totalLocataires),
            const SizedBox(height: 10),
            _buildTopBar(filteredUsers, isBlockedList),
            const SizedBox(height: 10),
            Expanded(
              child: Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      columnSpacing: 15,
                      headingRowHeight: 45,
                      columns: const [
                        DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('UTILISATEUR', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('RÔLE', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: filteredUsers.asMap().entries.map((entry) => _buildDataRow(entry.value, entry.key + 1, isBlockedList)).toList(),
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

  Widget _buildStatsHeader(int total, int bailleurs, int locataires) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statCard("Total", total.toString(), Colors.blue),
        _statCard("Bailleurs", bailleurs.toString(), Colors.purple),
        _statCard("Locataires", locataires.toString(), Colors.orange),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildTopBar(List<UserModel> users, bool isBlocked) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Rechercher (Nom, Email, Rôle)...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: () async {
              final snapshot = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.utilisateurs)
                  .where('isBlocked', isEqualTo: isBlocked)
                  .get();

              ExportService.exportPropertiesToExcel(
                docs: snapshot.docs,
                fileName: "Liste_Clients_EasyLocation",
                sheetName: "Clients",
                headers: [
                  'NOM COMPLET', 
                  'TÉLÉPHONE', 
                  'EMAIL', 
                  'RÔLE', 
                  'SOLDE (USD)', 
                  'N°', 
                  'AVENUE', 
                  'QUARTIER', 
                  'COMMUNE', 
                  'VILLE', 
                  'PROVINCE', 
                  'PAYS'
                ],
                keys: [
                  'nom', // Le service peut aussi utiliser un getter si configuré
                  'telephone', 
                  'email', 
                  'activeRole', 
                  'walletBalance', 
                  'numeroMaison', 
                  'avenue', 
                  'quartier', 
                  'commune', 
                  'ville', 
                  'province', 
                  'pays'
                ],
              );
            },
            icon: const Icon(Icons.file_download),
            style: IconButton.styleFrom(backgroundColor: Colors.green[700]),
          )
        ],
      ),
    );
  }

  DataRow _buildDataRow(UserModel user, int index, bool isBlocked) {
    return DataRow(cells: [
      DataCell(Text('$index', style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
      DataCell(
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          // ✅ Identité Complète
          Text(user.nomComplet, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          // ✅ Contact complet (Tél | Email)
          Text("${user.telephone} | ${user.email ?? 'Pas d\'email'}", 
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(5)),
        child: Text(user.activeRole.toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.blue[900], fontWeight: FontWeight.bold)),
      )),
      DataCell(Row(
        children: [
          IconButton(icon: const Icon(Icons.visibility, color: Colors.blue, size: 20), onPressed: () => _showUserDetails(context, user)),
          IconButton(
            icon: Icon(isBlocked ? Icons.settings_backup_restore : Icons.block, color: isBlocked ? Colors.green : Colors.orange, size: 20),
            onPressed: () => _showConfirmDialog(context, user.uid, isBlocked, user.nom),
          ),
        ],
      )),
    ]);
  }

  void _showConfirmDialog(BuildContext context, String docId, bool currentBlockedStatus, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentBlockedStatus ? "Débloquer" : "Bloquer"),
        content: Text("Changer le statut de $name ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection(FirestoreCollections.utilisateurs).doc(docId).update({'isBlocked': !currentBlockedStatus});
              Navigator.pop(context);
            },
            child: const Text("CONFIRMER"),
          ),
        ],
      ),
    );
  }
}