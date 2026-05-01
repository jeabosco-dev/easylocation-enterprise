// lib/providers/booking_timer_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/property_service.dart';

class BookingTimerProvider with ChangeNotifier, WidgetsBindingObserver {
  Timer? _timer;
  
  // ✅ Timer fixé à 10 minutes (600 secondes)
  int _secondsRemaining = 600; 
  
  String? _currentPropertyId;
  int? _currentLockTimestamp; 
  String? _currentFactureId; // Sera mis à jour plus tard si null au début
  bool _isExpired = false;

  // --- GETTERS ---
  int get secondsRemaining => _secondsRemaining;
  bool get isExpired => _isExpired;
  String? get currentPropertyId => _currentPropertyId;
  
  /// Vérifie si le chrono tourne actuellement
  bool get isActive => _timer != null && _timer!.isActive;

  /// Alerte visuelle quand il reste moins de 2 minutes
  bool get isUrgent => _secondsRemaining > 0 && _secondsRemaining <= 120;

  BookingTimerProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // --- GESTION DU TIMER ---

  /// ✅ MODIFICATION : factureId est maintenant String? (optionnel avec null autorisé)
  void startTimer(String propertyId, int lockTimestamp, String? factureId, {int minutes = 10}) {
    _timer?.cancel(); 
    
    _currentPropertyId = propertyId;
    _currentLockTimestamp = lockTimestamp;
    _currentFactureId = factureId; // Peut être null à l'étape du paiement
    _secondsRemaining = minutes * 60;
    _isExpired = false;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        notifyListeners();
      } else {
        _handleTimeout();
      }
    });
    notifyListeners();
  }

  /// Permet de mettre à jour l'ID de facture en cours de route 
  /// (utile quand la facture est générée après le début du chrono)
  void updateInvoiceId(String invoiceId) {
    _currentFactureId = invoiceId;
    notifyListeners();
  }

  /// Arrête le compte à rebours (ex: après un paiement réussi)
  void stopTimer() {
    stopAndReset();
  }

  /// ✅ ACTION SÉCURISÉE : Déclenchée quand le chrono arrive à 00:00
  void _handleTimeout() async {
    _timer?.cancel();
    
    // On ne tente la libération que si on a au moins l'ID de propriété et le timestamp
    if (_currentPropertyId != null && _currentLockTimestamp != null) {
      
      // Si la facture est nulle, on passe une chaîne vide ou on gère dans le service
      await PropertyService().verifierEtLibererSiNonPaye(
        _currentPropertyId!, 
        _currentLockTimestamp!,
        _currentFactureId ?? "" // ✅ Sécurité si toujours null au timeout
      );
      
      _isExpired = true; 
      _currentPropertyId = null;
      _currentLockTimestamp = null;
      _currentFactureId = null;
    }
    
    notifyListeners();
  }

  /// Reset complet de l'état du provider
  void stopAndReset() {
    _timer?.cancel();
    _timer = null;
    _currentPropertyId = null;
    _currentLockTimestamp = null;
    _currentFactureId = null;
    _secondsRemaining = 0;
    _isExpired = false;
    notifyListeners();
  }

  /// Formatage pour l'affichage (ex: 09:59)
  String get formattedTime {
    int minutes = _secondsRemaining ~/ 60;
    int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}