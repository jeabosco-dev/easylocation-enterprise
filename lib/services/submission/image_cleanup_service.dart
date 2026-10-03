// lib/services/submission/image_cleanup_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_storage/firebase_storage.dart';

class ImageCleanupService {
  final FirebaseStorage _storage;

  ImageCleanupService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Supprime uniquement les fichiers temporaires créés lors de la session de soumission courante
  Future<void> cleanupLocalImages(List<File> createdTempFiles) async {
    if (kIsWeb || createdTempFiles.isEmpty) return;

    for (final file in createdTempFiles) {
      try {
        if (await file.exists()) {
          await file.delete();
          debugPrint('🧹 Nettoyage ciblé : ${file.path} supprimé');
        }
      } catch (e) {
        debugPrint('⚠️ Erreur nettoyage fichier local (${file.path}): $e');
      }
    }
  }

  /// Supprime les images du Firebase Storage qui ne sont plus référencées
  Future<void> cleanupUnusedStorageImages(
      List<dynamic> oldUrls, List<dynamic> newUrls) async {
    final oldList = oldUrls.whereType<String>().toList();
    final newList = newUrls.whereType<String>().toList();

    final List<String> urlsToDelete =
        oldList.where((url) => !newList.contains(url)).toList();

    for (final url in urlsToDelete) {
      try {
        if (url.contains('firebasestorage.googleapis.com')) {
          await _storage.refFromURL(url).delete();
          debugPrint('🗑️ Image Storage obsolète supprimée : $url');
        }
      } catch (e) {
        debugPrint('⚠️ Erreur suppression Storage ($url): $e');
      }
    }
  }
}