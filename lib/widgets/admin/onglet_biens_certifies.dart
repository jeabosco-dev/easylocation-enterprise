import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart'; 
import 'package:easylocation_mvp/models/formulaire_publication_model.dart';
import 'package:easylocation_mvp/models/property_model.dart'; 
import 'package:easylocation_mvp/widgets/admin/property_details_panel.dart';
import 'package:easylocation_mvp/services/admin_workflow_service.dart';

class OngletBiensCertifies extends StatefulWidget {
  const OngletBiensCertifies({super.key});

  @override
  State<OngletBiensCertifies> createState() => _OngletBiensCertifiesState();
}

class _OngletBiensCertifiesState extends State<OngletBiensCertifies> {
  bool _isProcessing = false;
  String _selectedCommune = 'Toutes'; 
  final AdminWorkflowService _workflowService = AdminWorkflowService();

  void _refreshBadges() {
    context.read<AdminCountsProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.white,
          title: _buildCommuneFilter(),
          bottom: TabBar(
            labelColor: Colors.green[800],
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green[800],
            indicatorWeight: 3,
            tabs: const [
              Tab(child: Text("DISPONIBLES", style: TextStyle(fontWeight: FontWeight.bold))),
              Tab(child: Text("RÉSERVÉS / LOUÉS", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              children: [
                _buildPropertyStream(showAvailable: true),
                _buildPropertyStream(showAvailable: false),
              ],
            ),
            if (_isProcessing) 
              Container(
                color: Colors.white70,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommuneFilter() {
    final communes = ['Toutes', 'Ibanda', 'Kadutu', 'Bagira'];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: communes.length,
        itemBuilder: (context, index) {
          final c = communes[index];
          final isSelected = _selectedCommune == c;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black)),
              selected: isSelected,
              selectedColor: Colors.green[700],
              onSelected: (val) => setState(() => _selectedCommune = c),
            ),
          );
        },
      ),
    );
  }

  /// Stream corrigé avec filtres Firestore et Tri sur verifiedAt
  Widget _buildPropertyStream({required bool showAvailable}) {
    // 1. Base de la requête (Biens validés et visibles)
    Query query = FirebaseFirestore.instance
        .collection(FirestoreCollections.properties)
        .where(FirestoreFields.isVerified, isEqualTo: true)
        .where(FirestoreFields.isVisible, isEqualTo: true);

    // 2. Filtre de commune
    if (_selectedCommune != 'Toutes') {
      query = query.where('commune', isEqualTo: _selectedCommune);
    }

    // 3. Séparation logique par Status
    if (showAvailable) {
      query = query.where(FirestoreFields.status, isEqualTo: PropertyStatus.disponible);
    } else {
      query = query.where(FirestoreFields.status, whereIn: [
        PropertyStatus.reserved, 
        'rented', 
        'occupied'
      ]);
    }

    // 4. Tri par date de certification (Vérifie bien que le champ est 'verifiedAt' en base)
    // Note: Un index composite Firestore peut être requis pour combiner le filtrage et le tri.
    query = query.orderBy('verifiedAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Erreur de flux : ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final property = Property.fromMap(data, docs[index].id);
            return _buildEnterpriseCard(property, data);
          },
        );
      },
    );
  }

  Widget _buildEnterpriseCard(Property p, Map<String, dynamic> rawData) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          ListTile(
            onTap: () => _ouvrirDetails(p.id!, rawData),
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60, height: 60,
                color: Colors.green.shade50,
                child: const Icon(Icons.home_work, color: Colors.green),
              ),
            ),
            title: Text("${p.typeBien} • ${p.commune}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Réf: ${p.referenceUnique}", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                const SizedBox(height: 4),
                Text("${p.price}\$ / mois", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat(Icons.visibility, p.views.toString(), Colors.blue),
                _buildMiniStat(Icons.favorite, p.favoriteCount.toString(), Colors.pink),
                _buildMiniStat(Icons.share, p.shares.toString(), Colors.orange),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_moderator, color: Colors.redAccent, size: 22),
                  onPressed: () => _revoquerCertification(p.id!, rawData),
                  tooltip: "Révoquer la certification",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(width: 12),
      ],
    );
  }

  Future<void> _revoquerCertification(String id, Map<String, dynamic> data) async {
    final TextEditingController reasonController = TextEditingController();
    
    final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("RÉVOQUER LA CERTIFICATION ?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: "Motif obligatoire", hintText: "Ex: Erreur technique, données obsolètes..."),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("CONFIRMER", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    ) ?? false;

    if (confirm && reasonController.text.isNotEmpty) {
      final profile = context.read<UserProfileProvider>();
      setState(() => _isProcessing = true);
      try {
        await _workflowService.executeSecureAction(
          propertyId: id,
          adminId: profile.userData!.uid,
          adminName: profile.agentFullName,
          fullPropertyData: data,
          actionType: "REVOCATION",
          details: reasonController.text,
          updateData: {
            FirestoreFields.isVerified: false,
            FirestoreFields.status: PropertyStatus.archive,
            'revocationDate': FieldValue.serverTimestamp(),
          },
        );
        _refreshBadges();
        _showSnackBar("Certification révoquée avec succès", Colors.green);
      } catch (e) {
        _showSnackBar("Erreur: $e", Colors.red);
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _ouvrirDetails(String id, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: PropertyDetailsPanel(
          property: Property.fromMap(data, id),
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text("Aucun bien dans cette catégorie", style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color col) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: col, behavior: SnackBarBehavior.floating)
  );
}