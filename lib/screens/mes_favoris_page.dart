import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ Importation nécessaire
import 'details_propriete_page.dart';
import 'package:easylocation_mvp/widgets/reference_badge_widget.dart';

class MesFavorisPage extends StatefulWidget {
  const MesFavorisPage({Key? key}) : super(key: key);

  @override
  State<MesFavorisPage> createState() => _MesFavorisPageState();
}

class _MesFavorisPageState extends State<MesFavorisPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _supprimerFavori(String id) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('favoris')
          .doc(id)
          .delete();
    }
  }

  void _confirmerSuppressionTous() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Vider vos favoris ?"),
        content: const Text("Voulez-vous supprimer tous vos coups de cœur ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              final user = _auth.currentUser;
              if (user != null) {
                final snap = await _firestore.collection('utilisateurs').doc(user.uid).collection('favoris').get();
                for (var doc in snap.docs) { await doc.reference.delete(); }
              }
            },
            child: const Text("Tout supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text("Mes Coups de Cœur", 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            onPressed: _confirmerSuppressionTous,
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
          )
        ],
      ),
      body: user == null
          ? const Center(child: Text("Connectez-vous pour voir vos favoris"))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('utilisateurs')
                  .doc(user.uid)
                  .collection('favoris')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator.adaptive());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final favoris = snapshot.data!.docs;

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.70, 
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: favoris.length,
                  itemBuilder: (context, index) {
                    final data = favoris[index].data() as Map<String, dynamic>;
                    final String id = favoris[index].id;
                    
                    List<String> localisationParts = [];
                    if (data['quartier']?.toString().isNotEmpty ?? false) localisationParts.add(data['quartier']);
                    if (data['commune']?.toString().isNotEmpty ?? false) localisationParts.add(data['commune']);
                    if (data['ville']?.toString().isNotEmpty ?? false) localisationParts.add(data['ville']);

                    final String adresseAffichage = localisationParts.isEmpty 
                        ? "Lieu non précisé" 
                        : localisationParts.join(", ");

                    final String prix = "${data['prix'] ?? data['price'] ?? 'N/A'} \$";
                    final String imageUrl = data['imageUrl'] ?? '';
                    final String refShort = id.length >= 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase();

                    return _buildPropertyCard(id, imageUrl, refShort, adresseAffichage, prix);
                  },
                );
              },
            ),
    );
  }

  Widget _buildPropertyCard(String id, String imageUrl, String ref, String lieu, String prix) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => DetailsProprietePage(propertiesIds: [id], initialIndex: 0),
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
              aspectRatio: 1.1, 
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    // ✅ Remplacement par CachedNetworkImage
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[100],
                        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned(top: 8, left: 8, child: ReferenceBadgeWidget(reference: ref)),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _supprimerFavori(id),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
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
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 13, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lieu,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500, height: 1.2),
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
          Icon(Icons.favorite_border, size: 60, color: Colors.blueGrey[50]),
          const SizedBox(height: 16),
          const Text("Aucun favori enregistré", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Parcourez les annonces pour en ajouter", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }
}
