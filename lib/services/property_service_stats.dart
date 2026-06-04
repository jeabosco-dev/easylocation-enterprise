part of 'property_service.dart';

extension PropertyServiceStats on PropertyService {
  
  // -----------------------------------------------------------------
  // ✅ GESTION DES STATISTIQUES DE LOCALITÉ (URGENCY BANNER)
  // -----------------------------------------------------------------

  Future<StatsLocaliteModel?> getLocaliteStats({
    required String province,
    required String ville,
    required String commune,
    required String quartier,
  }) async {
    try {
      final String baseId = "rdc_${_slugify(province)}_${_slugify(ville)}";
      final String statsId = "${baseId}_${_slugify(commune)}_${_slugify(quartier)}";
      
      // ✅ Correction : accès via le getter public 'db'
      var doc = await db.collection('stats_localites').doc(statsId).get();

      if (!doc.exists) {
        String fallbackId = "${baseId}_${_slugify(commune)}";
        doc = await db.collection('stats_localites').doc(fallbackId).get();
      }

      if (doc.exists && doc.data() != null) {
        return StatsLocaliteModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur getLocaliteStats: $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
    }
    return null;
  }

  // -----------------------------------------------------------------
  // ✅ LOGIQUE INTERNE DE MISE À JOUR DES STATS
  // -----------------------------------------------------------------

  // ✅ Important : Si vous déplacez cette méthode dans property_service.dart,
  // retirez le '_' du nom pour la rendre accessible globalement.
  Future<void> updateZoneStatsInTransaction(
    Transaction transaction, 
    String docId, 
    int nouvelleDuree
  ) async {
    // ✅ Correction : accès via getter public 'db'
    DocumentReference statRef = db.collection('stats_localites').doc(docId);
    DocumentSnapshot statSnap = await transaction.get(statRef);

    if (statSnap.exists) {
      Map<String, dynamic> data = statSnap.data() as Map<String, dynamic>;
      int currentTotal = data['total_rented'] ?? 0;
      int currentAvg = data['avg_hours'] ?? 0;

      int newTotal = currentTotal + 1;
      int newAvg = ((currentAvg * currentTotal) + nouvelleDuree) ~/ newTotal;

      transaction.update(statRef, {
        'avg_hours': newAvg,
        'total_rented': newTotal,
        'last_update': FieldValue.serverTimestamp(),
      });
    } else {
      transaction.set(statRef, {
        'avg_hours': nouvelleDuree,
        'total_rented': 1,
        'last_update': FieldValue.serverTimestamp(),
      });
    }
  }
}