// lib/screens/mentions_legales_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class MentionsLegalesPage extends StatelessWidget {
  final String documentPath;
  final String pageTitle;

  const MentionsLegalesPage({
    super.key,
    required this.documentPath,
    required this.pageTitle,
  });

  Future<String> _loadDocument() async {
    return await rootBundle.loadString(documentPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder(
        future: _loadDocument(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Markdown(
                  data: snapshot.data!,
                ),
              );
            } else {
              return const Center(child: Text("Erreur lors du chargement du document."));
            }
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
