import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/property_model.dart'; 

class BoiteAvisUnique extends StatefulWidget {
  final Property property; 
  const BoiteAvisUnique({super.key, required this.property});

  @override
  State<BoiteAvisUnique> createState() => _BoiteAvisUniqueState();
}

class _BoiteAvisUniqueState extends State<BoiteAvisUnique> {
  double _rating = 5;
  double _oldRating = 0;
  bool _hasExistingReview = false;
  bool _isLoading = true;
  String? _activeRole; // ✅ Ajouté pour la gestion multi-rôle

  @override
  void initState() {
    super.initState();
    _checkExistingReview();
  }

  Future<void> _checkExistingReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Récupérer le rôle de l'utilisateur
      final userDoc = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists && mounted) {
        setState(() {
          _activeRole = userDoc.data()?['activeRole'] ?? userDoc.data()?['role'];
        });
      }

      // 2. Vérifier si un avis existe déjà pour ce logement
      final doc = await FirebaseFirestore.instance
          .collection('proprietes')
          .doc(widget.property.id)
          .collection('comments')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _rating = (doc.data()!['rating'] as num).toDouble();
          _oldRating = _rating;
          _hasExistingReview = true;
        });
      }
    } catch (e) {
      debugPrint("Erreur lors de la vérification de l'avis: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveReview() async {
    final user = FirebaseAuth.instance.currentUser;
    
    // ✅ SÉCURITÉ : Vérifier si l'utilisateur est bien un locataire
    if (user == null || _activeRole != 'locataire') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Action refusée : Seuls les locataires peuvent noter un logement."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final propertyRef = FirebaseFirestore.instance.collection('proprietes').doc(widget.property.id);
    final reviewRef = propertyRef.collection('comments').doc(user.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        if (!_hasExistingReview) {
          // Nouvel avis
          transaction.set(reviewRef, {
            'rating': _rating,
            'timestamp': FieldValue.serverTimestamp(),
            'userId': user.uid,
          });
          transaction.update(propertyRef, {
            'ratingCount': FieldValue.increment(1),
            'totalRating': FieldValue.increment(_rating),
          });
          
          // Mise à jour locale du modèle
          widget.property.ratingCount += 1;
          widget.property.totalRating += _rating;
        } else {
          // Mise à jour d'un avis existant
          transaction.update(reviewRef, {'rating': _rating});
          double diff = _rating - _oldRating;
          transaction.update(propertyRef, {'totalRating': FieldValue.increment(diff)});
          
          // Mise à jour locale du modèle
          widget.property.totalRating += diff;
        }
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Erreur sauvegarde avis: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'enregistrement : $e"))
        );
      }
    }
  }

  Future<void> _deleteReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final propertyRef = FirebaseFirestore.instance.collection('proprietes').doc(widget.property.id);
    
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(propertyRef);
        if (!snapshot.exists) return;

        int currentCount = (snapshot.data() as Map<String, dynamic>)['ratingCount'] ?? 0;
        double currentTotal = ((snapshot.data() as Map<String, dynamic>)['totalRating'] ?? 0).toDouble();

        transaction.delete(propertyRef.collection('comments').doc(user.uid));

        transaction.update(propertyRef, {
          'ratingCount': currentCount > 0 ? FieldValue.increment(-1) : 0,
          'totalRating': currentTotal >= _oldRating ? FieldValue.increment(-_oldRating) : 0,
        });

        widget.property.ratingCount = (widget.property.ratingCount > 0) ? widget.property.ratingCount - 1 : 0;
        widget.property.totalRating = (widget.property.totalRating >= _oldRating) ? widget.property.totalRating - _oldRating : 0.0;
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Erreur suppression avis: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()));
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _hasExistingReview ? "Modifier votre note" : "Noter ce logement", 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) => IconButton(
              icon: Icon(
                index < _rating ? Icons.star : Icons.star_border, 
                color: Colors.amber, 
                size: 40
              ),
              onPressed: () => setState(() => _rating = index + 1.0),
            )),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveReview,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _hasExistingReview ? "Enregistrer ma nouvelle note" : "Valider ma note",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (_hasExistingReview)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextButton(
                onPressed: _deleteReview, 
                child: const Text("Supprimer mon avis", style: TextStyle(color: Colors.red))
              ),
            ),
        ],
      ),
    );
  }
}
