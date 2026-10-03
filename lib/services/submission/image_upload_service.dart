// lib/services/submission/image_upload_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, VoidCallback;
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/formulaire_publication_model.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import 'image_compression_service.dart';

class UploadResult {
  final String? url;
  final File? tempFileToClean;

  UploadResult({this.url, this.tempFileToClean});
}

class MultiUploadResult {
  final List<String> urls;
  final List<File> tempFilesToClean;

  MultiUploadResult({required this.urls, required this.tempFilesToClean});
}

class ImageUploadService {
  final FirebaseStorage _storage;
  final ImageCompressionService _compressionService;

  ImageUploadService({
    FirebaseStorage? storage,
    ImageCompressionService? compressionService,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _compressionService = compressionService ?? ImageCompressionService();

  /// Détermine le type MIME en fonction de l'extension du fichier
  String _detectContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  /// Upload une image unique (principale ou spécifique)
  Future<UploadResult> uploadSingleImageSource(
    dynamic source,
    String bailleurId,
    String propertyId,
    String fileName, {
    VoidCallback? onComplete,
  }) async {
    if (source == null || source == FormulairePublicationModelSentinel) {
      return UploadResult();
    }
    if (source is! ImageSource) return UploadResult();

    if (source.isUrl) {
      onComplete?.call();
      return UploadResult(url: source.url);
    }

    if (source.isFile && source.file != null) {
      final ref = _storage.ref().child(
            StoragePaths.getPropertyImagePath(bailleurId, propertyId, fileName),
          );

      try {
        TaskSnapshot snapshot;
        File? tempToClean;

        if (kIsWeb) {
          final bytes = await source.file!.readAsBytes();
          final contentType = _detectContentType(source.file!.name);
          snapshot = await ref.putData(
            bytes,
            SettableMetadata(contentType: contentType),
          );
        } else {
          final compressResult = await _compressionService
              .compressImage(File(source.file!.path));

          if (compressResult == null || !await compressResult.file.exists()) {
            debugPrint('❌ Upload annulé : Fichier absent pour $fileName');
            return UploadResult();
          }

          if (compressResult.isTempFileCreated) {
            tempToClean = compressResult.file;
          }

          final contentType = _detectContentType(compressResult.file.path);
          snapshot = await ref.putFile(
            compressResult.file,
            SettableMetadata(contentType: contentType),
          );
        }

        final String url = await snapshot.ref.getDownloadURL();
        onComplete?.call();

        return UploadResult(url: url, tempFileToClean: tempToClean);
      } catch (e) {
        debugPrint('❌ Échec upload $fileName : $e');
        return UploadResult();
      }
    }

    return UploadResult();
  }

  /// Upload la liste des images des chambres
  Future<MultiUploadResult> uploadImageSourceList(
    List<dynamic> sources,
    String bailleurId,
    String propertyId,
    String folder, {
    VoidCallback? onImageComplete,
  }) async {
    final List<String?> results = List.filled(sources.length, null);
    final List<File> tempFiles = [];

    final uploadTasks = sources.asMap().entries.map((entry) async {
      final index = entry.key;
      final source = entry.value;

      if (source is! ImageSource) return;

      if (source.isUrl) {
        onImageComplete?.call();
        results[index] = source.url;
        return;
      }

      if (source.isFile && source.file != null) {
        final String fileName = 'chambre_${index + 1}.jpg';
        final ref = _storage.ref().child(
              StoragePaths.getChambreImagePath(
                  bailleurId, propertyId, folder, fileName),
            );

        try {
          TaskSnapshot snapshot;

          if (kIsWeb) {
            final bytes = await source.file!.readAsBytes();
            final contentType = _detectContentType(source.file!.name);
            snapshot = await ref.putData(
              bytes,
              SettableMetadata(contentType: contentType),
            );
          } else {
            final compressResult = await _compressionService
                .compressImage(File(source.file!.path));

            if (compressResult == null || !await compressResult.file.exists()) {
              debugPrint('❌ Chambre ${index + 1} absente lors de l\'upload');
              return;
            }

            if (compressResult.isTempFileCreated) {
              tempFiles.add(compressResult.file);
            }

            final contentType = _detectContentType(compressResult.file.path);
            snapshot = await ref.putFile(
              compressResult.file,
              SettableMetadata(contentType: contentType),
            );
          }

          final String url = await snapshot.ref.getDownloadURL();
          onImageComplete?.call();
          results[index] = url;
        } catch (e) {
          debugPrint('❌ Échec upload chambre ${index + 1} : $e');
        }
      }
    }).toList();

    await Future.wait(uploadTasks);

    final validUrls = results
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();

    return MultiUploadResult(urls: validUrls, tempFilesToClean: tempFiles);
  }
}