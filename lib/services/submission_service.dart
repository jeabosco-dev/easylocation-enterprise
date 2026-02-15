// lib/services/submission_service.dart

import 'dart:io';
import 'package:flutter/material.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; 
import 'package:path_provider/path_provider.dart'; 

// Vos imports personnalisés
import '../models/formulaire_publication_model.dart';
import '../constants/constants.dart';
import '../services/property_service.dart';
import '../controllers/formulaire_publication_controller.dart'; 

class SubmissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  final PropertyService _propertyService = PropertyService();

  static const Map<String, String> _specificImageKeyMap = {
    'salonImage': 'salonImage',
    'cuisineImage': 'cuisineImage',
    'toiletteParentaleImage': 'toiletteParentaleImage',
    'garageImage': 'garageImage',
    'courRecreationImage': 'courRecreationImage',
    'depotImage': 'depotImage',
  };

  // ***************************************************************
  // LOGIQUE DE NETTOYAGE
  // ***************************************************************

  Future<void> _cleanupUnusedStorageImages(List<String> oldUrls, List<String> newUrls) async {
    final List<String> urlsToDelete = oldUrls.where((url) => !newUrls.contains(url)).toList();

    for (String url in urlsToDelete) {
      try {
        if (url.contains('firebasestorage.googleapis.com')) {
          await _storage.refFromURL(url).delete();
          debugPrint('🗑️ Image obsolète supprimée'); 
        }
      } catch (e) {
        debugPrint('⚠️ Erreur suppression Storage: $e');
      }
    }
  }

  // ***************************************************************
  // LOGIQUE DE COMPRESSION
  // ***************************************************************

  Future<File?> _compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final String targetPath = 
          "${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg";

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, 
        minWidth: 1024,
        minHeight: 1024,
      );

      return result != null ? File(result.path) : file;
    } catch (e) {
      debugPrint('❌ Erreur compression: $e');
      return file; 
    }
  }

  // ***************************************************************
  // LOGIQUE STORAGE (UPLOAD)
  // ***************************************************************

  Future<String?> _uploadSingleImageSource(
      dynamic source, String bailleurId, String propertyId, String fileName, 
      {VoidCallback? onComplete}) async {
    
    if (source == null || source == FormulairePublicationModelSentinel) return null;
    if (source is! ImageSource) return null;
    
    if (source.isUrl) {
      onComplete?.call();
      return source.url;
    }

    if (source.isFile && source.file != null) {
      final ref = _storage.ref().child(
        StoragePaths.getPropertyImagePath(bailleurId, propertyId, fileName)
      );
      
      try {
        File? fileToUpload = await _compressImage(File(source.file!.path));
        if (fileToUpload == null) return null;

        final snapshot = await ref.putFile(fileToUpload);
        String url = await snapshot.ref.getDownloadURL();
        
        onComplete?.call(); 
        return url;
      } catch (e) {
        debugPrint('❌ Échec upload $fileName: $e');
        return null;
      }
    }
    return null;
  }

  Future<List<String>> _uploadImageSourceList(
      List<ImageSource> sources, String bailleurId, String propertyId, String folder,
      {VoidCallback? onImageComplete}) async {
    
    final uploadTasks = sources.asMap().entries.map((entry) async {
      final index = entry.key;
      final source = entry.value;

      if (source.isUrl) {
        onImageComplete?.call();
        return source.url;
      }
      
      if (source.isFile && source.file != null) {
        final String fileName = 'chambre_${index + 1}.jpg';
        final ref = _storage.ref().child(
          StoragePaths.getChambreImagePath(bailleurId, propertyId, folder, fileName)
        );
        
        try {
          File? fileToUpload = await _compressImage(File(source.file!.path));
          if (fileToUpload == null) return null;

          final snapshot = await ref.putFile(fileToUpload);
          String url = await snapshot.ref.getDownloadURL();
          
          onImageComplete?.call(); 
          return url;
        } catch (e) {
          debugPrint('❌ Échec upload chambre $index: $e');
          return null;
        }
      }
      return null;
    }).toList();

    final results = await Future.wait(uploadTasks);
    return results.whereType<String>().toList();
  }

  // ***************************************************************
  // ACTIONS FIRESTORE & ORCHESTRATION
  // ***************************************************************

  Future<void> submitProperty({
    required FormulairePublicationController controller, 
    required String bailleurId, 
    String? propertyId, 
    Function(double)? onProgress
  }) async {
    final bool isUpdate = propertyId != null;
    
    final docRef = isUpdate 
        ? _firestore.collection(FirestoreCollections.properties).doc(propertyId)
        : _firestore.collection(FirestoreCollections.properties).doc();
    
    final finalPropertyId = docRef.id;
    final formData = controller.data; 

    try {
      int totalImages = 0;
      if (formData.mainImage != null) totalImages++;
      totalImages += formData.chambresImages.length;
      _specificImageKeyMap.forEach((key, _) {
        if (_getSourceFromKey(formData, key) != null) totalImages++;
      });

      int imagesDone = 0;
      void updateProgress() {
        imagesDone++;
        if (onProgress != null && totalImages > 0) {
          double p = (imagesDone.toDouble() / totalImages.toDouble()) * 0.85; 
          onProgress(p);
        }
      }

      onProgress?.call(0.05);

      Map<String, dynamic> existingData = {};
      List<String> oldImageUrls = [];
      if (isUpdate) {
        final doc = await docRef.get();
        if (doc.exists) {
          existingData = doc.data() as Map<String, dynamic>;
          oldImageUrls = List<String>.from(existingData['imageUrls'] ?? []);
        }
      }

      final mainImageTask = _uploadSingleImageSource(
        formData.mainImage, bailleurId, finalPropertyId, 'main', 
        onComplete: updateProgress
      );

      final chambresTask = _uploadImageSourceList(
        formData.chambresImages, bailleurId, finalPropertyId, 'chambres', 
        onImageComplete: updateProgress
      );

      Map<String, Future<String?>> specificTasks = {};
      _specificImageKeyMap.forEach((key, value) {
        dynamic source = _getSourceFromKey(formData, key);
        specificTasks[key] = _uploadSingleImageSource(
          source, bailleurId, finalPropertyId, key, 
          onComplete: updateProgress
        );
      });

      final results = await Future.wait([
        mainImageTask,
        chambresTask,
        Future.wait(specificTasks.values),
      ]);

      String? mainImageUrl = (results[0] as String?) ?? existingData['mainImageUrl'];
      if (mainImageUrl == null) throw Exception('Image principale requise');

      final List<String> chambresUrls = results[1] as List<String>;
      final Map<String, String> specificUrls = {};
      final List<String?> specificResults = results[2] as List<String?>;
      
      int idx = 0;
      for (var key in specificTasks.keys) {
        String? url = specificResults[idx] ?? (existingData['specificImageUrls'] as Map?)?[key];
        if (url != null) specificUrls[key] = url;
        idx++;
      }

      onProgress?.call(0.90);

      // Mise à jour locale du controller pour refléter les URLs finales
      controller.updateData(
        mainImage: ImageSource(url: mainImageUrl),
        chambresImages: chambresUrls.map((url) => ImageSource(url: url)).toList(),
        salonImage: specificUrls.containsKey('salonImage') ? ImageSource(url: specificUrls['salonImage']) : null,
        cuisineImage: specificUrls.containsKey('cuisineImage') ? ImageSource(url: specificUrls['cuisineImage']) : null,
        toiletteParentaleImage: specificUrls.containsKey('toiletteParentaleImage') ? ImageSource(url: specificUrls['toiletteParentaleImage']) : null,
        garageImage: specificUrls.containsKey('garageImage') ? ImageSource(url: specificUrls['garageImage']) : null,
        courRecreationImage: specificUrls.containsKey('courRecreationImage') ? ImageSource(url: specificUrls['courRecreationImage']) : null,
        depotImage: specificUrls.containsKey('depotImage') ? ImageSource(url: specificUrls['depotImage']) : null,
      );

      // ✅ RÉCUPÉRATION ET SÉCURISATION DES DONNÉES
      final Map<String, dynamic> finalData = controller.prepareDataForFirebase();
      
      finalData.addAll({
        'id': finalPropertyId,
        'bailleurId': bailleurId,
        'lastUpdated': FieldValue.serverTimestamp(),
        
        // --- 🔑 LES CHAMPS CLÉS POUR VOTRE WIDGET D'IMAGES ---
        'mainImageUrl': mainImageUrl,
        'chambresImageUrls': chambresUrls,
        'specificImageUrls': specificUrls, // C'est ici que se joue l'affichage "Salon", "Cuisine"
        'imageUrls': [mainImageUrl, ...chambresUrls, ...specificUrls.values],
        
        // --- 🔥 SÉCURITÉ ET TRI ---
        'sortIndex': existingData['sortIndex'] ?? 0, 
        'createdAt': existingData['createdAt'] ?? FieldValue.serverTimestamp(),
        'isVerified': existingData['isVerified'] ?? false, 
        'status': existingData['status'] ?? 'disponible', 
        'estLouee': existingData['estLouee'] ?? false,
      });

      if (isUpdate) {
        await docRef.update(finalData);
        await _cleanupUnusedStorageImages(oldImageUrls, List<String>.from(finalData['imageUrls']));
      } else {
        await _propertyService.createProperty(finalData);
      }

      // ✅ HARMONISATION DU JOURNAL D'ACTIVITÉS
      await _firestore.collection(FirestoreCollections.activityLog).add({
        'activity': isUpdate ? 'Mise à jour réussie : $finalPropertyId' : 'Nouvelle publication : $finalPropertyId',
        'type': isUpdate ? 'modification' : 'creation', 
        'userId': bailleurId,
        'propertyId': finalPropertyId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      onProgress?.call(1.0); 

    } catch (e) {
      debugPrint('❌ Erreur SubmissionService: $e');
      rethrow;
    }
  }

  dynamic _getSourceFromKey(FormulairePublicationModel data, String key) {
    switch (key) {
      case 'salonImage': return data.salonImage;
      case 'cuisineImage': return data.cuisineImage;
      case 'toiletteParentaleImage': return data.toiletteParentaleImage;
      case 'garageImage': return data.garageImage;
      case 'courRecreationImage': return data.courRecreationImage;
      case 'depotImage': return data.depotImage;
      default: return null;
    }
  }
}
