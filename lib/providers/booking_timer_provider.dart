// lib/providers/booking_timer_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/property_service.dart';

class BookingTimerProvider with ChangeNotifier, WidgetsBindingObserver {
  Timer? _timer;
  int _secondsRemaining = 900; // Aligné sur 15 minutes (900s) comme dans le service
  String? _currentPropertyId;
  int? _currentLockTimestamp; // Ajouté pour identifier le verrou précis
  bool _isExpired = false;

  int get secondsRemaining => _secondsRemaining;
  bool get isExpired => _isExpired;
  String? get currentPropertyId => _currentPropertyId;

  BookingTimerProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ✅ GESTION DU TIMER
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

  /// ✅ AJOUT DE LA MÉTHODE MANQUANTE
  /// Utilisée dans page_facture.dart pour arrêter le compte à rebours après paiement
  void stopTimer() {
    stopAndReset();
  }

  /// Action déclenchée quand le chrono arrive à 00:00
  void _handleTimeout() async {
    _timer?.cancel();
    _isExpired = true;
    
    if (_currentPropertyId != null && _currentLockTimestamp != null) {
      // ✅ On utilise la méthode de libération ciblée du service
      await PropertyService().verifierEtLibererVerrou(
        _currentPropertyId!, 
        _currentLockTimestamp!
      );
      
      _currentPropertyId = null;
      _currentLockTimestamp = null;
    }
    
    notifyListeners();
  }

  void stopAndReset() {
    _timer?.cancel();
    _timer = null;
    _currentPropertyId = null;
    _currentLockTimestamp = null;
    _secondsRemaining = 0;
    _isExpired = false;
    notifyListeners();
  }

  String get formattedTime {
    int minutes = _secondsRemaining ~/ 60;
    int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Note: La méthode didChangeAppLifecycleState a été simplifiée. 
  // Firebase gère le verrou par timestamp, donc même si l'app ferme, 
  // le service de "balayage" (cleanExpiredReservations) libérera la maison après 15 min.
}
