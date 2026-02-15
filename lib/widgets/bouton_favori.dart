import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/property_model.dart';

class BoutonFavori extends StatefulWidget {
  final Property property;

  const BoutonFavori({super.key, required this.property});

  @override
  State<BoutonFavori> createState() => _BoutonFavoriState();
}

class _BoutonFavoriState extends State<BoutonFavori> {
  bool isFavorite = false;
  late int _localCount;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _resetButton();
  }

  void _resetButton() {
    _localCount = widget.property.favoriteCount;
    isFavorite = false; 
    _checkIfFavorite();
  }

  @override
  void didUpdateWidget(covariant BoutonFavori oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.property.id != widget.property.id) {
      _resetButton();
    }
  }

  Future<void> _checkIfFavorite() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final doc = await _firestore
        .collection('utilisateurs')
        .doc(user.uid)
        .collection('favoris')
        .doc(widget.property.id)
        .get();
    
    if (mounted) {
      setState(() {
        isFavorite = doc.exists;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userFavRef = _firestore
        .collection('utilisateurs')
        .doc(user.uid)
        .collection('favoris')
        .doc(widget.property.id);
        
    final propertyRef = _firestore.collection('proprietes').doc(widget.property.id);

    // Mise à jour visuelle immédiate
    setState(() {
      if (isFavorite) {
        if (_localCount > 0) _localCount--;
        isFavorite = false;
      } else {
        _localCount++;
        isFavorite = true;
      }
      widget.property.favoriteCount = _localCount;
    });

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot propSnap = await transaction.get(propertyRef);
        if (!propSnap.exists) return;

        int serverCount = (propSnap.data() as Map<String, dynamic>)['favoriteCount'] ?? 0;

        if (isFavorite) {
          // --- SAUVEGARDE AVEC TOUTE LA LOCALISATION ---
          transaction.set(userFavRef, {
            'id': widget.property.id,
            'titre': widget.property.title,
            'prix': widget.property.price,
            'imageUrl': widget.property.imageUrls.isNotEmpty ? widget.property.imageUrls.first : null,
            // AJOUT DES CHAMPS ICI :
            'province': widget.property.province,
            'ville': widget.property.ville,
            'commune': widget.property.commune,
            'quartier': widget.property.quartier,
            'dateAjout': FieldValue.serverTimestamp(),
          });
          transaction.update(propertyRef, {'favoriteCount': FieldValue.increment(1)});
        } else {
          // RETIRER DES FAVORIS
          transaction.delete(userFavRef);
          if (serverCount > 0) {
            transaction.update(propertyRef, {'favoriteCount': FieldValue.increment(-1)});
          }
        }
      });
    } catch (e) {
      _checkIfFavorite(); 
      debugPrint("Erreur favoris: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _toggleFavorite,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              "$_localCount",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const Text(
              "favoris",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
