// lib/services/migration_service.dart
import 'package:cloud_functions/cloud_functions.dart';

class MigrationService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<void> performQuickOnboarding({
    required Map<String, dynamic> propertyData,
    required String tenantName,
    required String tenantPhone,
    required DateTime startDate,
    required int durationMonths,
  }) async {
    try {
      final result = await _functions.httpsCallable('quickOnboarding').call({
        'propertyData': propertyData,
        'tenantData': {'nom': tenantName, 'phone': tenantPhone},
        'startDate': startDate.toIso8601String(),
        'dureeBail': durationMonths,
      });

      if (result.data['success'] == true) {
        print("Maison et contrat créés avec succès : ${result.data['contractId']}");
      }
    } catch (e) {
      print("Erreur Migration: $e");
      rethrow;
    }
  }
}