import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:async';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final Map<String, Stopwatch> _timers = {};

  /// 1. Démarrer le chrono quand un client arrive sur une page stratégique
  static void startPageTimer(String pageName) {
    _timers[pageName] = Stopwatch()..start();
  }

  /// 2. Analyser le succès ou l'abandon (Google pour la masse, Sentry pour l'alerte argent)
  static void stopAndTrack(String pageName, {required bool aConsomme}) async {
    final timer = _timers[pageName];
    if (timer != null) {
      timer.stop();
      int secondes = timer.elapsed.inSeconds;

      // --- GOOGLE ANALYTICS (Statistiques de masse - Gratuit) ---
      // Cela te permet de voir dans ton dashboard Google le taux d'abandon par page.
      await _analytics.logEvent(
        name: 'page_performance',
        parameters: {
          'page_id': pageName,
          'duration': secondes,
          'success': aConsomme ? 1 : 0,
        },
      );

      // --- SENTRY (Alerte psychologique - Précis) ---
      // On ne l'utilise que si le client a passé bcp de temps sans acheter.
      if (!aConsomme && secondes > 60) {
        Sentry.captureMessage(
          "HÉSITATION CRITIQUE : L'utilisateur a passé $secondes sec sur $pageName sans valider.",
          level: SentryLevel.warning,
        );
      }

      _timers.remove(pageName);
    }
  }

  /// 3. Traquer une action spécifique (clic bouton, sélection option)
  static void logActionEvent(String actionName, {Map<String, dynamic>? details}) async {
    await _analytics.logEvent(
      name: 'user_action',
      parameters: {
        'action': actionName,
        ...?details,
      },
    );
    
    // Miette de pain pour Sentry (gratuit) pour comprendre le chemin en cas de bug
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: "Action: $actionName",
        category: "ui.action",
        data: details,
      ),
    );
  }

  /// 4. Traquer les problèmes de friction (Sentry)
  static void logFriction(String feature, String cause) {
    Sentry.captureMessage(
      "FRICTION : $feature bloqué par $cause",
      level: SentryLevel.info,
    );
  }
}
