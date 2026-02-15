import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/property_model.dart';
import 'carte_propriete_widget.dart';

class SectionProprietesSimilaires extends StatefulWidget {
  final Property currentProperty;

  const SectionProprietesSimilaires({super.key, required this.currentProperty});

  @override
  State<SectionProprietesSimilaires> createState() => _SectionProprietesSimilairesState();
}

class _SectionProprietesSimilairesState extends State<SectionProprietesSimilaires> {
  late Future<QuerySnapshot<Map<String, dynamic>>> _similarPropertiesFuture;

  @override
  void initState() {
    super.initState();
    _loadSimilarProperties();
  }

  @override
  void didUpdateWidget(covariant SectionProprietesSimilaires oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentProperty.id != widget.currentProperty.id) {
      setState(() {
        _loadSimilarProperties();
      });
    }
  }

  void _loadSimilarProperties() {
    final double minPrice = widget.currentProperty.price * 0.8;
    final double maxPrice = widget.currentProperty.price * 1.2;

    _similarPropertiesFuture = FirebaseFirestore.instance
        .collection('proprietes')
        .where('status', isEqualTo: 'published')
        .where('commune', isEqualTo: widget.currentProperty.commune)
        .where('price', isGreaterThanOrEqualTo: minPrice)
        .where('price', isLessThanOrEqualTo: maxPrice)
        .limit(10)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // ✅ Empêche la colonne de prendre trop de place
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Expanded( // ✅ Utilise Expanded pour éviter l'overflow horizontal du texte
                child: Text(
                  "Propriétés similaires",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Budget : ${widget.currentProperty.price.toStringAsFixed(0)}\$",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: _similarPropertiesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            if (snapshot.hasError) {
              debugPrint("Erreur Firestore Similaires: ${snapshot.error}");
              return const SizedBox.shrink();
            }

            final docs = snapshot.data?.docs ?? [];
            final list = docs
                .map((doc) => Property.fromFirestore(doc))
                .where((p) => p.id != widget.currentProperty.id)
                .toList();

            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Text(
                  "Aucune autre propriété similaire trouvée.",
                  style: TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              );
            }

            // Tri
            list.sort((a, b) {
              if (a.quartier == widget.currentProperty.quartier && b.quartier != widget.currentProperty.quartier) return -1;
              if (a.quartier != widget.currentProperty.quartier && b.quartier == widget.currentProperty.quartier) return 1;
              return 0;
            });

            final List<String> allIds = list.map((e) => e.id).toList();

            // ✅ SOLUTION OVERFLOW : On utilise un SizedBox avec une hauteur suffisante 
            // ou on laisse le contenu gérer sa propre taille si possible.
            return SizedBox(
              height: 280, // ✅ Augmenté de 260 à 280 pour donner de l'air aux cartes
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 280, // ✅ Largeur explicite pour les cartes horizontales
                    margin: const EdgeInsets.only(right: 12, bottom: 8), // ✅ bottom: 8 pour l'ombre
                    child: CarteProprieteWidget(
                      property: list[index],
                      index: index,
                      allPropertiesIds: allIds,
                      isHorizontal: true,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
