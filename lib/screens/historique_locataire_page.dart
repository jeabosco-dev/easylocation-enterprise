import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easylocation_mvp/screens/details_propriete_page.dart';
import 'package:easylocation_mvp/widgets/reference_badge_widget.dart'; 

class HistoriqueLocatairePage extends StatefulWidget {
  const HistoriqueLocatairePage({super.key});

  @override
  State<HistoriqueLocatairePage> createState() => _HistoriqueLocatairePageState();
}

class _HistoriqueLocatairePageState extends State<HistoriqueLocatairePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Suppression individuelle
  Future<void> _deleteHistoryItem(String docId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore
          .collection('historique_locataire')
          .doc(user.uid)
          .collection('user_history')
          .doc(docId)
          .delete();
    } catch (e) {
      _showSnackBar('Erreur lors de la suppression');
    }
  }

  // ✅ Vider tout l'historique (Batch)
  Future<void> _clearAllHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirmed = await _showConfirmDialog(
      'Vider l\'historique ?',
      'Voulez-vous effacer toutes vos consultations récentes ?'
    );

    if (confirmed) {
      try {
        final collection = _firestore
            .collection('historique_locataire')
            .doc(user.uid)
            .collection('user_history');

        final snapshot = await collection.get();
        final batch = _firestore.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        _showSnackBar('Historique effacé');
      } catch (e) {
        _showSnackBar('Erreur lors du nettoyage');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Connectez-vous")));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text("Mon Historique", 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            onPressed: _clearAllHistory,
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('historique_locataire')
            .doc(user.uid)
            .collection('user_history')
            .orderBy('timestamp', descending: true)
            .limit(40)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72, 
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String docId = docs[index].id;
              final String propertyId = data['id'] ?? docId;

              // --- Logique de Localisation Harmonisée ---
              List<String> loc = [];
              if (data['quartier']?.toString().isNotEmpty ?? false) loc.add(data['quartier']);
              if (data['commune']?.toString().isNotEmpty ?? false) loc.add(data['commune']);
              final String adresse = loc.isEmpty ? "Lieu non précisé" : loc.join(", ");

              // --- Logique Prix Harmonisée (Correction : supporte prix et price, String ou num) ---
              final dynamic rawPrice = data['prix'] ?? data['price'];
              final String prixAffichage = rawPrice != null ? "$rawPrice \$" : "Prix N/A";

              // --- Logique Image Harmonisée (Correction : priorité mainImageUrl) ---
              String imageUrl = '';
              if (data['mainImageUrl'] != null && data['mainImageUrl'].toString().isNotEmpty) {
                imageUrl = data['mainImageUrl'].toString();
              } else if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
                imageUrl = data['imageUrl'].toString();
              } else if (data['imageUrls'] is List && (data['imageUrls'] as List).isNotEmpty) {
                imageUrl = (data['imageUrls'] as List).first.toString();
              }

              final String ref = propertyId.length >= 6 
                  ? propertyId.substring(0, 6).toUpperCase() 
                  : propertyId.toUpperCase();

              return _buildHistoryCard(propertyId, docId, imageUrl, ref, adresse, prixAffichage);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(String propId, String docId, String url, String ref, String lieu, String prix) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => DetailsProprietePage(propertiesIds: [propId], initialIndex: 0),
      )),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.2, 
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image avec CachedNetworkImage pour la performance
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: url.isNotEmpty 
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[100]),
                          errorWidget: (context, url, error) => const Icon(Icons.broken_image_outlined),
                        )
                      : Container(
                          color: Colors.grey[100],
                          child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                        ),
                  ),
                  Positioned(top: 8, left: 8, child: ReferenceBadgeWidget(reference: ref)),
                  // Bouton supprimer (petit X)
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => _deleteHistoryItem(docId),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prix, 
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.blueAccent)
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Colors.redAccent),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          lieu,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 60, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text("Historique vide", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  Future<bool> _showConfirmDialog(String t, String c) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t), content: Text(c),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }
}
