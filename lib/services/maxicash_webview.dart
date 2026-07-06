// lib/services/maxicash_webview.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _verifyingPayment = false;
  int _progress = 0;
  
  StreamSubscription<DocumentSnapshot>? _paymentSubscription;
  Timer? _verificationTimeout; // Sécurité anti-blocage

  @override
  void dispose() {
    _paymentSubscription?.cancel();
    _verificationTimeout?.cancel();
    super.dispose();
  }

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
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          onPageStarted: (url) {
            debugPrint("PAGE START : $url");
          },
          onPageFinished: (url) {
            debugPrint("PAGE FINISH : $url");
          },
          onNavigationRequest: (request) async {
            debugPrint("========== NAVIGATION ==========");
            debugPrint(request.url);

            final url = request.url.toLowerCase();
            
            if (url.contains("success") || url.contains(MaxicashConfig.successUrl.toLowerCase())) {
              if (!_verifyingPayment) {
                _startVerification();
              }
              return NavigationDecision.prevent;
            }

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

  void _startVerification() {
    setState(() => _verifyingPayment = true);

    // Initialisation du Timer de secours (60s)
    _verificationTimeout = Timer(const Duration(seconds: 60), () {
      if (!_isFinished) {
        debugPrint("⏳ Timeout atteint : échec de validation.");
        _finalize(false);
      }
    });

    _paymentSubscription = FirebaseFirestore.instance
        .collection('paiements')
        .doc(widget.paymentReference)
        .snapshots()
        .listen((snapshot) {
      
      if (snapshot.exists && snapshot.data()?['statut'] == 'valide') {
        _paymentSubscription?.cancel();
        _verificationTimeout?.cancel(); // Arrêt du timer si succès
        
        if (widget.ville != null) {
          unawaited(_goalService.trackAction(ville: widget.ville!, type: MissionType.reservations));
        }
        _finalize(true);
      }
    }, onError: (e) {
      debugPrint("❌ Erreur écoute Firestore: $e");
    });
  }

  void _finalize(bool isSuccess) {
    if (!_isFinished) {
      _isFinished = true;
      _paymentSubscription?.cancel();
      _verificationTimeout?.cancel();
      
      if (mounted) Navigator.of(context).pop();
      
      if (isSuccess && widget.onSuccess != null) {
        widget.onSuccess!();
      } else if (!isSuccess && widget.onCancel != null) {
        widget.onCancel!();
      }
    }
  }

  void _close(VoidCallback? callback) {
    if (!_isFinished) {
      _isFinished = true;
      _paymentSubscription?.cancel();
      _verificationTimeout?.cancel();
      
      if (mounted) {
        Navigator.of(context).pop();
        if (callback != null) Future.delayed(const Duration(milliseconds: 350), callback);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_verifyingPayment ? "Vérification..." : "Paiement Sécurisé"),
        leading: _verifyingPayment ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => _close(widget.onCancel)),
      ),
      body: _verifyingPayment
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Validation du paiement en cours..."),
                ],
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
              ],
            ),
    );
  }
}