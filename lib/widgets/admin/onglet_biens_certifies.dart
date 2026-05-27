// lib/widgets/admin/onglet_biens_certifies.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart'; 
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
    final String? myId = context.read<UserProfileProvider>().userData?.uid;
    context.read<AdminCountsProvider>().refresh(adminId: myId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        title: _buildCommuneFilter(),
      ),
      body: Stack(
        children: [
          _buildPropertyStream(),
          if (_isProcessing) 
            Container(
              color: Colors.white70,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
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

  Widget _buildPropertyStream() {
    Query query = FirebaseFirestore.instance
        .collection(FirestoreCollections.properties)
        .where(FirestoreFields.isVerified, isEqualTo: true)
        .where(FirestoreFields.isVisible, isEqualTo: true)
        .where(FirestoreFields.status, isEqualTo: PropertyStatus.disponible); 

    if (_selectedCommune != 'Toutes') {
      query = query.where('commune', isEqualTo: _selectedCommune);
    }

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
            // ✅ MODIFICATION : Passage de l'index de ligne dynamique (index + 1)
            return _buildEnterpriseCard(property, data, index + 1);
          },
        );
      },
    );
  }

  // ✅ MODIFICATION : Réception du paramètre numeroLigne
  Widget _buildEnterpriseCard(Property p, Map<String, dynamic> rawData, int numeroLigne) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          ListTile(
            onTap: () => _ouvrirDetails(p.id!, rawData),
            contentPadding: const EdgeInsets.all(12),
            // ✅ MODIFICATION : Remplacement de la boîte d'icône par le CircleAvatar numéroté
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade50,
              radius: 18,
              child: Text(
                "$numeroLigne",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                  fontSize: 13,
                ),
              ),
            ),
            // ✅ MODIFICATION : Intégration de l'icône originale Icons.home_work dans la ligne de titre
            title: Row(
              children: [
                const Icon(
                  Icons.home_work, 
                  color: Colors.green, 
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${p.typeBien} • ${p.commune}", 
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
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
          Text("Aucun bien disponible en ligne", style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color col) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: col, behavior: SnackBarBehavior.floating)
  );
}