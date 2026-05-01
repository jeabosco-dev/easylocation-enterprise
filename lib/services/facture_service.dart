import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../models/facture_model.dart';
import 'package:easylocation_mvp/constants/constants.dart';

class FactureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _rng = Random();

  /// ✅ Enregistre une nouvelle facture dans Firestore
  Future<void> creerFacture(FactureModel facture) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Utilisateur non connecté — Impossible de créer la facture.");
    }

    if (facture.id == null || facture.id!.isEmpty) {
      throw Exception("L'ID de la facture est manquant.");
    }

    try {
      await _runWriteWithRetry(() async {
        await _db
            .collection(FirestoreCollections.factures)
            .doc(facture.id) 
            .set(facture.toMap());
      }, "creerFacture");

      print("✅ Facture enregistrée avec succès. ID: ${facture.id}");
    } catch (e, stackTrace) {
      print("❌ Erreur critique lors de l'enregistrement de la facture: $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// ✅ Récupérer les factures d'un utilisateur (Locataire) en temps réel
  Stream<List<FactureModel>> getMesFactures(String clientId) {
    return _db
        .collection(FirestoreCollections.factures)
        .where('clientId', isEqualTo: clientId)
        .orderBy(FactureFields.dateCreation, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FactureModel.fromMap(doc.data(), doc.id)) // ✅ CORRECTION ICI : Ajout de doc.id
            .toList());
  }

  /// ✅ Mécanisme de réessai automatique (Retry)
  Future<void> _runWriteWithRetry(Future<void> Function() op, String context) async {
    int retries = 3;
    int delayMs = 500;

    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        return await op();
      } on FirebaseException catch (e, stack) {
        if (e.code == 'unavailable' || e.code == 'internal') {
          print('⚠️ Firestore instable ($context). Tentative ${attempt + 1}/$retries...');
          if (attempt == retries - 1) {
            await Sentry.captureException(e, stackTrace: stack);
            rethrow;
          }
          final delay = delayMs + _rng.nextInt(delayMs);
          await Future.delayed(Duration(milliseconds: delay));
          delayMs *= 2;
        } else {
          rethrow;
        }
      } catch (e, stack) {
        await Sentry.captureException(e, stackTrace: stack);
        rethrow;
      }
    }
  }
}