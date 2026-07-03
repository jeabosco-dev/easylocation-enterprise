import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Soumission ou modification de l'avis
  Future<void> submitReview(String propertyId, double rating) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Utilisateur non connecté");

    final reviewRef = _db.collection('proprietes')
                         .doc(propertyId)
                         .collection('comments')
                         .doc(user.uid);

    await reviewRef.set({
      'userId': user.uid,
      'rating': rating,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // Utilisation de merge pour ne pas écraser d'autres champs si besoin
  }

  // 2. Suppression de l'avis
  Future<void> deleteReview(String propertyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Utilisateur non connecté");

    final reviewRef = _db.collection('proprietes')
                         .doc(propertyId)
                         .collection('comments')
                         .doc(user.uid);

    await reviewRef.delete();
  }
}