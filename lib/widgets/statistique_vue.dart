import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easylocation_mvp/models/property_model.dart';

class StatistiqueVue extends StatefulWidget {
  final Property property;

  const StatistiqueVue({super.key, required this.property});

  @override
  State<StatistiqueVue> createState() => _StatistiqueVueState();
}

class _StatistiqueVueState extends State<StatistiqueVue> {
  late int _localViews;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _localViews = widget.property.views;
    _handleViewIncrement();
  }

  @override
  void didUpdateWidget(StatistiqueVue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.property.id != widget.property.id) {
      _localViews = widget.property.views;
      _handleViewIncrement();
    }
  }

  Future<void> _handleViewIncrement() async {
    final user = FirebaseAuth.instance.currentUser;
    // On ne compte les vues que pour les utilisateurs connectés
    if (user == null) return;

    try {
      // 1. Références Firestore
      final propertyRef = _firestore.collection('proprietes').doc(widget.property.id);
      final viewerRef = propertyRef.collection('viewers').doc(user.uid);
      
      // Récupération du document utilisateur pour vérifier le rôle ACTIF
      final userDoc = await _firestore.collection('utilisateurs').doc(user.uid).get();

      if (userDoc.exists) {
        // ✅ CORRECTION MULTI-RÔLE : On vérifie 'activeRole'
        // On garde une sécurité avec ?? pour l'ancien champ 'role' au cas où
        final String activeRole = userDoc.data()?['activeRole'] ?? userDoc.data()?['role'] ?? '';

        // 2. Vérifier si l'utilisateur agit actuellement en tant que locataire
        if (activeRole == 'locataire') {
          
          // 3. Vérifier si ce locataire a déjà vu cette annonce
          final viewDoc = await viewerRef.get();
          
          if (!viewDoc.exists) {
            // Utilisation d'un WriteBatch pour l'atomicité
            WriteBatch batch = _firestore.batch();

            // Marquer l'utilisateur comme ayant vu l'annonce
            batch.set(viewerRef, {'timestamp': FieldValue.serverTimestamp()});

            // Incrémenter le compteur global sur le document de la maison
            batch.update(propertyRef, {'views': FieldValue.increment(1)});

            await batch.commit();

            // 4. Mise à jour de l'UI locale
            if (mounted) {
              setState(() {
                _localViews += 1;
                widget.property.views = _localViews;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("🚨 Erreur lors de l'incrémentation des vues: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.remove_red_eye_outlined, color: Colors.blueGrey, size: 28),
        const SizedBox(height: 4),
        Text(
          "$_localViews",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const Text(
          "vues",
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}
