import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/property_model.dart';
import '../widgets/carte_propriete_widget.dart';
import '../providers/user_profile_provider.dart';

class SectionRecommandationsWidget extends StatefulWidget {
  final String userId;
  const SectionRecommandationsWidget({super.key, required this.userId});

  @override
  State<SectionRecommandationsWidget> createState() => _SectionRecommandationsWidgetState();
}

class _SectionRecommandationsWidgetState extends State<SectionRecommandationsWidget> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // On lance le chargement après le build initial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _genererRecommandations();
    });
  }

  Future<void> _genererRecommandations() async {
    final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);

    // ✅ 1. SÉCURITÉ CACHE : Si déjà chargé, on ne fait rien
    if (profileProvider.cachedRecommendedProperties.isNotEmpty) return;
    if (_isLoading) return;
    
    if (mounted) setState(() => _isLoading = true);

    try {
      final userRef = FirebaseFirestore.instance.collection('utilisateurs').doc(widget.userId);
      final historyRef = FirebaseFirestore.instance
          .collection('historique_locataire')
          .doc(widget.userId)
          .collection('user_history');

      // Récupération des données sources
      final results = await Future.wait([
        userRef.collection('favoris').get(), 
        userRef.get(), 
        historyRef.orderBy('timestamp', descending: true).limit(10).get(), 
      ]);

      final favorisCollection = results[0] as QuerySnapshot;
      final userDoc = results[1] as DocumentSnapshot;
      final historySnap = results[2] as QuerySnapshot;

      // Exclusion de ce que l'utilisateur a déjà vu
      final Set<String> idsExclure = {};
      for (var doc in favorisCollection.docs) idsExclure.add(doc.id);
      
      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData != null && userData.containsKey('favoris')) {
        final List<dynamic> favorisField = userData['favoris'] ?? [];
        for (var id in favorisField) idsExclure.add(id.toString());
      }
      for (var doc in historySnap.docs) idsExclure.add(doc.id);

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> profilDocs = [];
      final listIds = idsExclure.toList();
      
      if (listIds.isNotEmpty) {
        // On récupère les détails par paquets de 10
        for (int i = 0; i < listIds.length; i += 10) {
          final sublist = listIds.sublist(i, (i + 10 > listIds.length) ? listIds.length : i + 10);
          final snap = await FirebaseFirestore.instance
              .collection('proprietes')
              .where(FieldPath.documentId, whereIn: sublist)
              .get();
          profilDocs.addAll(snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>());
        }
      }

      List<Property> resultatsFinal = [];

      // --- LOGIQUE DE RECOMMANDATION ---
      if (profilDocs.isNotEmpty) {
        final quartiers = profilDocs.map((doc) => doc.data()['quartier'] as String?).whereType<String>().toSet().toList();
        List<String> communes = profilDocs.map((doc) => doc.data()['commune'] as String?).whereType<String>().toSet().toList();

        if (communes.length > 30) communes = communes.sublist(0, 30);
        
        double moyennePrix = 0;
        final prixDocs = profilDocs.map((doc) => (doc.data()['price'] as num? ?? 0).toDouble()).toList();
        if (prixDocs.isNotEmpty) {
          moyennePrix = prixDocs.reduce((a, b) => a + b) / prixDocs.length;
        }

        final querySnapshot = await FirebaseFirestore.instance
            .collection('proprietes')
            .where('status', isEqualTo: 'published')
            .where('commune', whereIn: communes.isEmpty ? ['Inconnu'] : communes)
            .orderBy('publicationDate', descending: true)
            .limit(25)
            .get();

        resultatsFinal = querySnapshot.docs
            .where((doc) {
              final data = doc.data();
              final prix = (data['price'] as num? ?? 0).toDouble();
              bool estPasDejaVu = !idsExclure.contains(doc.id);
              bool correspondQuartier = quartiers.contains(data['quartier']);
              bool correspondBudget = prix <= (moyennePrix * 1.5); 
              return estPasDejaVu && (correspondQuartier || correspondBudget);
            })
            .map((doc) => Property.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .take(10)
            .toList();
      }

      // Si pas assez de résultats ou pas d'historique, on prend les plus récents
      if (resultatsFinal.isEmpty) {
        final fallbackSnapshot = await FirebaseFirestore.instance
            .collection('proprietes')
            .where('status', isEqualTo: 'published')
            .orderBy('publicationDate', descending: true)
            .limit(10)
            .get();
        
        resultatsFinal = fallbackSnapshot.docs
            .map((doc) => Property.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList();
      }

      if (mounted) {
        // ✅ On met à jour le Provider (le Selector s'occupera du reste)
        profileProvider.setRecommendedProperties(resultatsFinal);
      }

    } catch (e) {
      debugPrint("🚨 Erreur Recommandations : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ ON RESTE AVEC LE SELECTOR : C'est lui qui empêche le clignotement
    return Selector<UserProfileProvider, List<Property>>(
      selector: (_, prov) => prov.cachedRecommendedProperties,
      builder: (context, recommandations, child) {
        
        if (_isLoading && recommandations.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (recommandations.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "Recommandé pour vous",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 280, 
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: recommandations.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: MediaQuery.of(context).size.width * 0.75,
                    margin: const EdgeInsets.only(right: 12),
                    child: CarteProprieteWidget(
                      property: recommandations[index],
                      index: index,
                      allPropertiesIds: recommandations.map((p) => p.id).toList(),
                      isHorizontal: true,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
