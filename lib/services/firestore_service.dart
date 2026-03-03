// lib/services/firestore_service.dart

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// ✅ ON IMPORTE LES CONSTANTES CENTRALISÉES ICI
import 'package:easylocation_mvp/constants/constants.dart';

/// NOTE : Les classes FirestoreCollections et PropertyStatus ont été supprimées d'ici
/// car elles sont maintenant centralisées dans lib/core/constants.dart

/// Service dédié aux opérations Firestore ne concernant pas les profils utilisateurs
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _rng = Random();

  /// Tente d'exécuter une fonction d'écriture Firestore avec un mécanisme de réessai
  Future<void> _runWriteWithRetry(
      Future<void> Function() op, String context) async {
    int retries = 3;
    int delayMs = 500;

    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        return await op();
      } on FirebaseException catch (e, stack) {
        if (e.code == 'unavailable' || e.code == 'internal') {
          print('⚠️ Firestore indisponible ($context, ${e.code}). Nouvelle tentative (essai ${attempt + 1})...');

          if (attempt == retries - 1) {
            final hint = Hint()
              ..set('context', '$context failed after $retries tries');

            await Sentry.captureException(
              e,
              stackTrace: stack,
              hint: hint,
            );
            rethrow;
          }
          final delay = delayMs + _rng.nextInt(delayMs);
          await Future.delayed(Duration(milliseconds: delay));
          delayMs *= 2;
        } else {
          rethrow;
        }
      } catch (e, stack) {
        final hint = Hint()..set('context', 'Erreur inattendue lors de l\'exécution de $context');
        await Sentry.captureException(e, stackTrace: stack, hint: hint);
        rethrow;
      }
    }
  }

  /// Enregistre une activité pour un bailleur
  Future<void> logBailleurActivity(
      String bailleurId, String description) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(
          "Utilisateur non authentifié — impossible d'écrire l'activité log ($bailleurId).");
    }

    final data = {
      'userId': bailleurId,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // ✅ Utilisation de la constante centralisée (vient de constants.dart désormais)
    // On utilise activityLog car c'est le nom dans ton constants.dart
    final activitesRef = _db.collection(FirestoreCollections.activityLog);

    try {
      await _runWriteWithRetry(
        () => activitesRef.add(data),
        'logBailleurActivity',
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        await Sentry.captureException(e, stackTrace: stackTrace);
        throw Exception("Erreur de permission. Votre jeton est peut-être périmé.");
      }
      rethrow;
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
      throw Exception("Erreur inattendue lors de l'enregistrement de l'activité.");
    }
  }
}