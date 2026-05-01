// lib/web_admin/admin_manage_partners_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import du nouveau widget de partage et du service d'export
import 'package:easylocation_mvp/widgets/admin/bouton_partage_partenaire.dart';
import 'package:easylocation_mvp/services/export_service.dart';

class AdminManagePartnersPage extends StatefulWidget {
  const AdminManagePartnersPage({super.key});

  @override
  _AdminManagePartnersPageState createState() => _AdminManagePartnersPageState();
}

class _AdminManagePartnersPageState extends State<AdminManagePartnersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion Partenaires EasyLocation"),
        actions: [
          // ✅ BOUTON D'EXPORT EXCEL GLOBAL
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: "Exporter tous les partenaires vers Excel",
            onPressed: () async {
              // 1. Récupérer l'ensemble des partenaires
              final snapshot = await FirebaseFirestore.instance
                  .collection('partenaires')
                  .orderBy('created_at', descending: true)
                  .get();

              if (snapshot.docs.isNotEmpty) {
                // 2. Lancer l'export via le service
                await ExportService.exportPartnersToExcel(docs: snapshot.docs);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Rapport Excel généré avec succès !"))
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Aucune donnée à exporter."))
                  );
                }
              }
            },
          ),
          const SizedBox(width: 10),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.check_circle), text: "Actifs"),
            Tab(icon: Icon(Icons.pause_circle), text: "Suspendus"),
            Tab(icon: Icon(Icons.archive), text: "Archivés"),
          ],
        ),
      ),
      body: Column(
        children: [
          // BARRE DE RECHERCHE
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Rechercher un partenaire par nom...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        }) 
                      : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
                constraints: const BoxConstraints(maxWidth: 800),
              ),
            ),
          ),
          
          // LISTE DES PARTENAIRES
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPartnerList('active'),
                _buildPartnerList('suspended'),
                _buildPartnerList('archived'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerList(String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('partenaires')
          .where('status', isEqualTo: statusFilter)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Erreur de chargement"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs.where((doc) {
          String nom = (doc['nom'] ?? "").toString().toLowerCase();
          return nom.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return Center(child: Text("Aucun partenaire trouvé dans '$statusFilter'"));
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var p = docs[index];
                var data = p.data() as Map<String, dynamic>;
                String docId = p.id;
                double commission = (data['commission_rate'] ?? 0.0) * 100;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(statusFilter),
                      child: Text(data['nom'] != null ? data['nom'][0].toUpperCase() : "?"),
                    ),
                    title: Text(data['nom'] ?? "Sans nom", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("ID: $docId\nCom: ${commission.toStringAsFixed(0)}% | Solde: ${data['solde_commission'] ?? 0} USD"),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BoutonPartagePartenaire(
                          partnerId: docId,
                          partnerData: data,
                        ),
                        PopupMenuButton<String>(
                          onSelected: (action) => _handleAction(context, action, docId, data),
                          itemBuilder: (context) => _getActionsForStatus(statusFilter),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<PopupMenuEntry<String>> _getActionsForStatus(String status) {
    List<PopupMenuEntry<String>> actions = [
      const PopupMenuItem(value: 'show_qr', child: ListTile(leading: Icon(Icons.qr_code_2), title: Text("Afficher QR Code"))),
      const PopupMenuItem(value: 'share_info', child: ListTile(leading: Icon(Icons.send_rounded, color: Colors.green), title: Text("Envoyer accès (WhatsApp)"))),
      const PopupMenuItem(value: 'edit_commission', child: ListTile(leading: Icon(Icons.percent), title: Text("Taux Commission"))),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'edit_uid', child: ListTile(leading: Icon(Icons.link), title: Text("Lier UID Firebase"))),
      const PopupMenuDivider(),
    ];

    if (status == 'active') {
      actions.add(const PopupMenuItem(value: 'suspend', child: ListTile(leading: Icon(Icons.pause), title: Text("Suspendre"))));
      actions.add(const PopupMenuItem(value: 'archive', child: ListTile(leading: Icon(Icons.archive), title: Text("Archiver"))));
    } else {
      actions.add(const PopupMenuItem(value: 'restore', child: ListTile(leading: Icon(Icons.restore), title: Text("Restaurer (Activer)"))));
    }

    actions.add(const PopupMenuDivider());
    actions.add(const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text("Supprimer", style: TextStyle(color: Colors.red)))));

    return actions;
  }

  Color _getStatusColor(String status) {
    if (status == 'active') return Colors.green;
    if (status == 'suspended') return Colors.orange;
    return Colors.grey;
  }

  void _handleAction(BuildContext context, String action, String docId, Map<String, dynamic> data) async {
    final ref = FirebaseFirestore.instance.collection('partenaires').doc(docId);

    switch (action) {
      case 'show_qr':
        _displayQrCodeDialog(context, docId, data['nom'] ?? "Partenaire");
        break;
      case 'edit_commission':
        _showCommissionEditDialog(context, docId, data['commission_rate'] ?? 0.0);
        break;
      case 'edit_uid':
        _showEditUidDialog(context, docId, data['linked_uid'] ?? "");
        break;
      case 'suspend':
        await ref.update({'is_active': false, 'status': 'suspended'});
        break;
      case 'archive':
        await ref.update({'is_active': false, 'status': 'archived'});
        break;
      case 'restore':
        await ref.update({'is_active': true, 'status': 'active'});
        break;
      case 'delete':
        _confirmDelete(context, docId);
        break;
    }
  }

  void _displayQrCodeDialog(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("QR Code : $name"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              "https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$docId",
              height: 200,
              width: 200,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.qr_code_2, size: 200),
            ),
            const SizedBox(height: 10),
            SelectableText(docId, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer"))],
      ),
    );
  }

  void _showCommissionEditDialog(BuildContext context, String docId, dynamic currentRate) {
    TextEditingController controller = TextEditingController(text: (currentRate * 100).toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Modifier la Commission (%)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(suffixText: "%", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue),
                SizedBox(width: 5),
                Expanded(child: Text("Pour régler un solde, utilisez l'onglet Validation Retraits", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic))),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              double newRate = (double.tryParse(controller.text) ?? 0) / 100;
              await FirebaseFirestore.instance.collection('partenaires').doc(docId).update({'commission_rate': newRate});
              Navigator.pop(context);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  void _showEditUidDialog(BuildContext context, String partnerDocId, String currentUid) {
    TextEditingController controller = TextEditingController(text: currentUid);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Lier un compte utilisateur"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "UID Firebase", border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              String newUid = controller.text.trim();
              await FirebaseFirestore.instance.collection('partenaires').doc(partnerDocId).update({'linked_uid': newUid});
              Navigator.pop(context);
            },
            child: const Text("Mettre à jour"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer ?"),
        content: const Text("Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('partenaires').doc(docId).delete();
              Navigator.pop(context);
            },
            child: const Text("SUPPRIMER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}