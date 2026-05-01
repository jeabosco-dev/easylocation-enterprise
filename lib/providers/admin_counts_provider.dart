// lib/providers/admin_counts_provider.dart

import 'package:flutter/material.dart'; // ✅ INDISPENSABLE pour ChangeNotifier
import 'package:easylocation_mvp/services/admin_workflow_service.dart'; // ✅ INDISPENSABLE pour le service

class AdminCountsProvider extends ChangeNotifier {
  final AdminWorkflowService _service = AdminWorkflowService();
  Map<String, int> counts = {};
  bool isLoading = false;

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners(); // Prévient les badges qu'on charge
    
    try {
      counts = await _service.getAllCounts();
    } catch (e) {
      debugPrint("Erreur lors du rafraîchissement des compteurs : $e");
    } finally {
      isLoading = false;
      notifyListeners(); // Prévient les badges qu'on a les chiffres
    }
  }
}