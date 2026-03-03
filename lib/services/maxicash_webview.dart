import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class MaxicashWebView extends StatefulWidget {
  final String initialUrl;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const MaxicashWebView({
    super.key,
    required this.initialUrl,
    this.onSuccess,
    this.onCancel,
  });

  @override
  State<MaxicashWebView> createState() => _MaxicashWebViewState();
}

class _MaxicashWebViewState extends State<MaxicashWebView> {
  late final WebViewController _controller;
  bool _isFinished = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();

    // 1. Paramètres de plateforme avec forcing du mode Hybride sur Android
    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      // FORCE LE RENDU HYBRIDE (Indispensable pour corriger les crashs de surface EGL)
      params = AndroidWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params);

    // 2. Configuration spécifique Android
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    // 3. Configuration générale
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onNavigationRequest: (request) {
            final url = request.url.toLowerCase();
            debugPrint("🔗 URL CHARGÉE : $url");

            if (url.contains("success")) {
              _close(widget.onSuccess);
              return NavigationDecision.prevent;
            }

            if (url.contains("failure") || 
                url.contains("cancel") || 
                url.contains("payfailure")) {
              debugPrint("❌ REDIRECTION ÉCHEC DÉTECTÉE");
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
        if (callback != null) callback();
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
          title: const Text("Paiement Sécurisé"),
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
                top: 0,
                left: 0,
                right: 0,
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