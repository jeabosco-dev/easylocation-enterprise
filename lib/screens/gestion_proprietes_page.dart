import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easylocation_mvp/screens/details_propriete_page.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/screens/modifier_propriete_page.dart';
import 'package:easylocation_mvp/constants/constants.dart'; 
import 'package:easylocation_mvp/widgets/badge_statut_propriete.dart';
import 'package:easylocation_mvp/widgets/statistique_vue.dart';
import 'package:easylocation_mvp/services/service_journal.dart';
import 'package:easylocation_mvp/widgets/reference_badge_widget.dart'; 
import 'package:easylocation_mvp/widgets/bouton_archivage_widget.dart';
import 'package:easylocation_mvp/screens/mes_archives_page.dart';

class GestionProprietesPage extends StatefulWidget {
  const GestionProprietesPage({super.key});

  @override
  State<GestionProprietesPage> createState() => _GestionProprietesPageState();
}

class _GestionProprietesPageState extends State<GestionProprietesPage> {
  
  Future<void> _boostProperty(BuildContext context, Property property) async {
    final now = DateTime.now();
    final DateTime lastBoostDate = property.lastBoost ?? property.createdAt;
    final int daysSince = now.difference(lastBoostDate).inDays;

    if (daysSince < 7) {
      final int daysLeft = 7 - daysSince;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⏳ Trop tôt ! Revenez dans $daysLeft jour${daysLeft > 1 ? 's' : ''}."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.properties)
          .doc(property.id)
          .update({
            'lastBoost': Timestamp.fromDate(now),
            'sortIndex': Timestamp.fromDate(now),
          });

      await ServiceJournal.enregistrerActivite(
        activite: 'Annonce boostée : ${property.title}',
        type: 'boost',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🚀 Annonce propulsée !"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      debugPrint("Erreur lors du boost: $e");
    }
  }

  Future<void> _updatePrice(BuildContext context, String proprieteId, double currentPrice, String propertyTitle) async {
    final TextEditingController priceController = TextEditingController();
    priceController.text = currentPrice.toStringAsFixed(0);

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Changer le loyer', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nouveau prix (\$)', suffixText: '/ mois', border: OutlineInputBorder()),
          ),
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop()),
            ElevatedButton(
              child: const Text('Confirmer'),
              onPressed: () async {
                final double? newPrice = double.tryParse(priceController.text);
                if (newPrice != null && newPrice > 0) {
                  await FirebaseFirestore.instance.collection(FirestoreCollections.properties).doc(proprieteId).update({'price': newPrice});
                  await ServiceJournal.enregistrerActivite(activite: 'Prix mis à jour : $propertyTitle', type: 'modification');
                  if (mounted) Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderStats(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.home_work_outlined, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text(
            "$count ${count > 1 ? 'propriétés actives' : 'propriété active'}",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800], fontSize: 15),
          ),
          const Spacer(),
          const Icon(Icons.verified, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          const Text("Bailleur Vérifié", style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.08),
        foregroundColor: color,
        elevation: 0,
        side: BorderSide(color: color.withOpacity(0.2)),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Session expirée.')));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mon Parc Immobilier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(FirestoreCollections.properties)
                .where('bailleurId', isEqualTo: user.uid)
                .where('status', isEqualTo: 'archive')
                .snapshots(),
            builder: (context, snapshot) {
              int archiveCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.inventory_2_outlined),
                    tooltip: "Voir les archives",
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MesArchivesPage()),
                    ),
                  ),
                  if (archiveCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '$archiveCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ MISE À JOUR : Filtrage direct Firestore pour l'harmonisation
        stream: FirebaseFirestore.instance
            .collection(FirestoreCollections.properties)
            .where('bailleurId', isEqualTo: user.uid)
            .where('status', isNotEqualTo: 'archive') 
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final propertiesDocs = snapshot.data?.docs ?? [];
          
          // Transformation des documents en objets Property
          final List<Property> propertiesList = propertiesDocs
              .map((doc) => Property.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
              .toList();
          
          final List<String> allIds = propertiesList.map((p) => p.id).toList();

          if (propertiesList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_work_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('Aucune propriété active.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MesArchivesPage())),
                    child: const Text("Gérer mes archives"),
                  )
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildHeaderStats(propertiesList.length),
              Expanded(
                child: ListView.builder(
                  itemCount: propertiesList.length,
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  itemBuilder: (context, index) {
                    final property = propertiesList[index];
                    final String? imageUrl = property.imageUrls.isNotEmpty ? property.imageUrls.first : null;

                    return Card(
                      key: ValueKey(property.id),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey[200]!)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsProprietePage(propertiesIds: allIds, initialIndex: index))),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10.0),
                                    child: imageUrl != null
                                        ? CachedNetworkImage(imageUrl: imageUrl, width: 90, height: 90, fit: BoxFit.cover)
                                        : Container(width: 90, height: 90, color: Colors.grey[200], child: const Icon(Icons.home)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ReferenceBadgeWidget(reference: property.referenceCourte),
                                        const SizedBox(height: 6), 
                                        BadgeStatutPropriete(statut: property.status),
                                        const SizedBox(height: 6), 
                                        Text('${property.price.toStringAsFixed(0)} \$ / mois', 
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                                      ],
                                    ),
                                  ),
                                  StatistiqueVue(property: property),
                                ],
                              ),
                              const Divider(height: 24, thickness: 0.5),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildActionButton(
                                      label: "Modifier", 
                                      icon: Icons.edit_note, 
                                      color: Colors.blueGrey, 
                                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => ModifierProprietePage(property: property)))),
                                    const SizedBox(width: 8),
                                    _buildActionButton(
                                      label: "Prix", 
                                      icon: Icons.payments_outlined, 
                                      color: Colors.blue, 
                                      onTap: () => _updatePrice(context, property.id, property.price, property.title)),
                                    const SizedBox(width: 8),
                                    _buildActionButton(
                                      label: "Booster", 
                                      icon: Icons.rocket_launch, 
                                      color: Colors.deepPurple, 
                                      onTap: () => _boostProperty(context, property)),
                                    const SizedBox(width: 8),
                                    BoutonArchivageWidget(property: property),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
