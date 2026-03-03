// lib/providers/booking_timer_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/property_service.dart';

class BookingTimerProvider with ChangeNotifier, WidgetsBindingObserver {
  Timer? _timer;
  int _secondsRemaining = 900; // 15 minutes par défaut
  String? _currentPropertyId;
  int? _currentLockTimestamp; 
  bool _isExpired = false;

  // --- GETTERS ---
  int get secondsRemaining => _secondsRemaining;
  bool get isExpired => _isExpired;
  String? get currentPropertyId => _currentPropertyId;
  
  /// Vérifie si le chrono tourne actuellement
  bool get isActive => _timer != null && _timer!.isActive;

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

  void startTimer(String propertyId, int lockTimestamp, {int minutes = 15}) {
    _timer?.cancel(); 
    
    _currentPropertyId = propertyId;
    _currentLockTimestamp = lockTimestamp;
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

  /// Arrête le compte à rebours (ex: après un paiement réussi)
  void stopTimer() {
    stopAndReset();
  }

  /// Action déclenchée quand le chrono arrive à 00:00
  void _handleTimeout() async {
    _timer?.cancel();
    _isExpired = true;
    
    if (_currentPropertyId != null && _currentLockTimestamp != null) {
      // Libération ciblée dans Firestore pour éviter les conflits
      await PropertyService().verifierEtLibererVerrou(
        _currentPropertyId!, 
        _currentLockTimestamp!
      );
      
      _currentPropertyId = null;
      _currentLockTimestamp = null;
    }
    
    notifyListeners();
  }

  /// Reset complet de l'état du provider
  void stopAndReset() {
    _timer?.cancel();
    _timer = null;
    _currentPropertyId = null;
    _currentLockTimestamp = null;
    _secondsRemaining = 0;
    _isExpired = false;
    notifyListeners();
  }

  /// Formatage pour l'affichage (ex: 14:59)
  String get formattedTime {
    int minutes = _secondsRemaining ~/ 60;
    int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Le balayage automatique des verrous expirés est géré par PropertyService
  // via le timestamp global, ce qui assure la cohérence même si l'app est fermée.
}