// lib/services/maxicash_webview.dart

import 'dart:async'; // Pour unawaited
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

// Imports personnalisés
import '../constants/constants.dart';
import '../services/goal_tracking_service.dart'; 
import '../models/community_goal_model.dart'; 

class MaxicashWebView extends StatefulWidget {
  final String initialUrl;
  final String? ville; // Reçu pour le tracking géographique
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const MaxicashWebView({
    super.key,
    required this.initialUrl,
    this.ville,
    this.onSuccess,
    this.onCancel,
  });

  @override
  State<MaxicashWebView> createState() => _MaxicashWebViewState();
}

class _MaxicashWebViewState extends State<MaxicashWebView> {
  late final WebViewController _controller;
  final GoalTrackingService _goalService = GoalTrackingService(); 
  bool _isFinished = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();

    // 1. Configuration selon la plateforme (iOS/Android)
    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      params = AndroidWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params);

    // 2. Paramètres spécifiques Android
    if (_controller.platform is AndroidWebViewController) {
      // ✅ RÉACTIVÉ : Permet de voir les logs console de la WebView si besoin
      AndroidWebViewController.enableDebugging(true); 
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    // 3. Configuration de la navigation
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          // 🚨 TRACKING DU DÉBUT DE CHARGEMENT DE PAGE
          onPageStarted: (url) {
            debugPrint("🚀 PAGE STARTED: $url");
          },
          // 🚨 TRACKING DE LA FIN DE CHARGEMENT DE PAGE
          onPageFinished: (url) {
            debugPrint("✅ PAGE FINISHED: $url");
          },
          // 🚨 TRACKING DES ERREURS DE RESSOURCES WEB
          onWebResourceError: (error) {
            debugPrint("❌ WEBVIEW ERROR");
            debugPrint("Description: ${error.description}");
            debugPrint("Error Type: ${error.errorType}");
          },
          onNavigationRequest: (request) {
            final url = request.url.toLowerCase();
            debugPrint("🔗 URL CHARGÉE : $url");

            // ✅ DÉTECTION SUCCÈS
            if (url.contains("success") || 
                url.contains(MaxicashConfig.successUrl.toLowerCase())) {
              debugPrint("✅ PAIEMENT RÉUSSI DÉTECTÉ");

              // DÉCLENCHEMENT DU TRACKING GÉOGRAPHIQUE
              if (widget.ville != null) {
                unawaited(_goalService.trackAction(
                  ville: widget.ville!, 
                  type: MissionType.reservations
                ));
              }

              _close(widget.onSuccess);
              return NavigationDecision.prevent;
            }

            // ✅ DÉTECTION ÉCHEC ou ANNULATION
            if (url.contains("cancel") || 
                url.contains("failure") || 
                url.contains("payfailure") ||
                url.contains(MaxicashConfig.cancelUrl.toLowerCase())) {
              debugPrint("❌ REDIRECTION ÉCHEC OU ANNULATION DÉTECTÉE");
              _close(widget.onCancel);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  // ✅ LOGIQUE DE FERMETURE SÉCURISÉE AVEC DÉLAI POUR L'UX
  void _close(VoidCallback? callback) {
    if (!_isFinished) {
      _isFinished = true;
      if (mounted) {
        // 1. Fermeture de la WebView
        Navigator.of(context).pop();
        
        // 2. Exécution du callback après un court délai (animation de fermeture)
        Future.delayed(const Duration(milliseconds: 350), () {
           if (callback != null) {
             callback();
           }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Empêche le retour arrière sauvage (force l'usage du bouton fermer)
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close(widget.onCancel); 
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Paiement Sécurisé MaxiCash", style: TextStyle(fontSize: 16)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _close(widget.onCancel),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_progress < 100)
              Positioned(
                top: 0, left: 0, right: 0,
                child: LinearProgressIndicator(
                  value: _progress / 100.0,
                  minHeight: 3,
                  color: Theme.of(context).primaryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}