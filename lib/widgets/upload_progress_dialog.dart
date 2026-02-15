// lib/widgets/upload_progress_dialog.dart

import 'package:flutter/material.dart';

class UploadProgressDialog extends StatelessWidget {
  final double progress;

  const UploadProgressDialog({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    // Logique pour le message dynamique
    String message = "Traitement en cours...";
    if (progress < 0.1) {
      message = "Compression des images...";
    } else if (progress < 0.9) {
      message = "Envoi des photos vers le serveur...";
    } else if (progress < 1.0) {
      message = "Finalisation de l'annonce...";
    } else {
      message = "Terminé ! ✅";
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Publication",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 25),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 90,
                  width: 90,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 7,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                  ),
                ),
                Text(
                  "${(progress * 100).toInt()}%",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
