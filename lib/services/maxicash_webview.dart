import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url.contains("google.com") || request.url.contains("success")) {
              Navigator.pop(context);
              if (widget.onSuccess != null) widget.onSuccess!();
              return NavigationDecision.prevent;
            }
            if (request.url.contains("cancel") || request.url.contains("decline")) {
              Navigator.pop(context);
              if (widget.onCancel != null) widget.onCancel!();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paiement Sécurisé MaxiCash", style: TextStyle(fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
