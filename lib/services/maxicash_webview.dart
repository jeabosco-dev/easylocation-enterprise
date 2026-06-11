// lib/services/maxicash_webview.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'package:easylocation_mvp/constants/all_constants.dart';
import '../services/goal_tracking_service.dart'; 
import '../models/community_goal_model.dart'; 

class MaxicashWebView extends StatefulWidget {
  final String initialUrl;
  final String paymentReference; 
  final String? ville;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const MaxicashWebView({
    super.key,
    required this.initialUrl,
    required this.paymentReference,
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

    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true);
    } else {
      params = AndroidWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params);

    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true); 
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          
          onPageFinished: (String url) {
            debugPrint("Page de paiement chargée : $url");
          },

          onNavigationRequest: (request) async {
            final url = request.url.toLowerCase();
            
            // ✅ DÉTECTION SUCCÈS - Fermeture du WebView et déclenchement du callback
            if (url.contains("success") || url.contains(MaxicashConfig.successUrl.toLowerCase())) {
              debugPrint("✅ PAIEMENT RÉUSSI - Fermeture du WebView");

              // 1. Tracking géographique
              if (widget.ville != null) {
                unawaited(_goalService.trackAction(ville: widget.ville!, type: MissionType.reservations));
              }

              // 2. Fermeture du WebView et exécution du callback de succès
              if (!_isFinished) {
                _isFinished = true;
                if (mounted) Navigator.of(context).pop(); 
                if (widget.onSuccess != null) {
                  widget.onSuccess!();
                }
              }
              return NavigationDecision.prevent;
            }

            // ✅ DÉTECTION ÉCHEC ou ANNULATION
            if (url.contains("cancel") || url.contains("failure") || url.contains(MaxicashConfig.cancelUrl.toLowerCase())) {
              _close(widget.onCancel);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  void _close(VoidCallback? callback) {
    if (!_isFinished) {
      _isFinished = true;
      if (mounted) {
        Navigator.of(context).pop();
        if (callback != null) Future.delayed(const Duration(milliseconds: 350), callback);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close(widget.onCancel); 
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Paiement Sécurisé", style: TextStyle(fontSize: 16)),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => _close(widget.onCancel)),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_progress < 100)
              LinearProgressIndicator(value: _progress / 100),
          ],
        ),
      ),
    );
  }
}