// lib/services/submission/image_compression_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class CompressedImageResult {
  final File file;
  final bool isTempFileCreated;

  CompressedImageResult({
    required this.file,
    required this.isTempFileCreated,
  });
}

class ImageCompressionService {
  /// Compresse l'image sur Mobile et retourne un [CompressedImageResult].
  /// Sur Web, contourne la compression et retourne le fichier original sans interagir avec le disque.
  Future<CompressedImageResult?> compressImage(File file) async {
    if (kIsWeb) {
      return CompressedImageResult(file: file, isTempFileCreated: false);
    }

    if (!await file.exists()) {
      debugPrint('❌ Fichier introuvable pour la compression : ${file.path}');
      return null;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final String targetPath =
          "${appDir.path}/FINAL_${DateTime.now().millisecondsSinceEpoch}.jpg";

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null) {
        return CompressedImageResult(file: file, isTempFileCreated: false);
      }

      return CompressedImageResult(
        file: File(result.path),
        isTempFileCreated: true,
      );
    } catch (e) {
      debugPrint('❌ Erreur lors de la compression image: $e');
      return CompressedImageResult(file: file, isTempFileCreated: false);
    }
  }
}