// lib/services/submission_service.dart

import 'dart:async'; // ✅ AJOUTÉ pour unawaited
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
import '../services/goal_tracking_service.dart'; 

// ✅ CORRECTION : Import du fichier contenant l'énumération MissionType
import '../models/community_goal_model.dart'; 

class SubmissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  final PropertyService _propertyService = PropertyService();
  final GoalTrackingService _goalService = GoalTrackingService(); 

  static const Map<String, String> _specificImageKeyMap = {
    'salonImage': 'salonImage',
    'cuisineImage': 'cuisineImage',
    'toiletteParentaleImage': 'toiletteParentaleImage',
    'garageImage': 'garageImage',
    'courRecreationImage': 'courRecreationImage',
    'depotImage': 'depotImage',
  };

  // ***************************************************************
  // LOGIQUE DE NETTOYAGE (STORAGE & LOCAL)
  // ***************************************************************

  /// Supprime les images du dossier permanent local après un upload réussi
  Future<void> _cleanupLocalImages() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final directory = Directory(appDir.path);
      final List<FileSystemEntity> files = directory.listSync();
      
      for (var file in files) {
        if (file is File && (file.path.contains('img_') || file.path.contains('FINAL_'))) {
          await file.delete();
          debugPrint('🧹 Nettoyage local : ${file.path} supprimé');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erreur nettoyage local: $e');
    }
  }

  Future<void> _cleanupUnusedStorageImages(List<String> oldUrls, List<String> newUrls) async {
    final List<String> urlsToDelete = oldUrls.where((url) => !newUrls.contains(url)).toList();

    for (String url in urlsToDelete) {
      try {
        if (url.contains('firebasestorage.googleapis.com')) {
          await _storage.refFromURL(url).delete();
          debugPrint('🗑️ Image Storage obsolète supprimée'); 
        }
      } catch (e) {
        debugPrint('⚠️ Erreur suppression Storage: $e');
      }
    }
  }

  // ***************************************************************
  // LOGIQUE DE COMPRESSION SÉCURISÉE (DOCUMENTS DIRECTORY)
  // ***************************************************************

  Future<File?> _compressImage(File file) async {
    if (!await file.exists()) {
      debugPrint('❌ Erreur : Fichier source introuvable à : ${file.path}');
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

      // ✅ REFIX OPTIMISATION : Si la compression échoue ou s'annule, on renvoie le fichier d'origine
      if (result == null) return file;
      
      // ✅ REFIX OPTIMISATION : Si elle réussit, on renvoie le nouveau fichier compressé
      return File(result.path);

    } catch (e) {
      debugPrint('❌ Erreur compression service: $e');
      return file; 
    }
  }

  // ***************************************************************
  // LOGIQUE STORAGE (UPLOAD) SÉCURISÉE
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
        
        if (fileToUpload == null || !await fileToUpload.exists()) {
          debugPrint('❌ Upload annulé : Fichier absent pour $fileName');
          return null;
        }

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
          
          if (fileToUpload == null || !await fileToUpload.exists()) {
            debugPrint('❌ Chambre $index absente au moment de l\'upload');
            return null;
          }

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

      final Map<String, dynamic> finalData = controller.prepareDataForFirebase();
      
      finalData.addAll({
        'hasSalon': specificUrls.containsKey('salonImage') || (finalData['hasSalon'] ?? false),
        'hasCuisine': specificUrls.containsKey('cuisineImage') || (finalData['hasCuisine'] ?? false),
        'hasToiletteParentale': specificUrls.containsKey('toiletteParentaleImage') || (finalData['hasToiletteParentale'] ?? false),
        'hasGarage': specificUrls.containsKey('garageImage') || (finalData['hasGarage'] ?? false),
        'hasCourRecreation': specificUrls.containsKey('courRecreationImage') || (finalData['hasCourRecreation'] ?? false),
        'hasDepot': specificUrls.containsKey('depotImage') || (finalData['hasDepot'] ?? false),
      });

      // ***************************************************************
      // SÉCURISATION DU WORKFLOW PRODUCTION
      // ***************************************************************
      final nowTimestamp = FieldValue.serverTimestamp();

      finalData.addAll({
        'id': finalPropertyId,
        'bailleurId': bailleurId,
        'typeBien': formData.typeBien, 
        'mainImageUrl': mainImageUrl,
        'chambresImageUrls': chambresUrls,
        'specificImageUrls': specificUrls, 
        'imageUrls': [mainImageUrl, ...chambresUrls, ...specificUrls.values],
        'sortIndex': existingData['sortIndex'] ?? 0, 
        'createdAt': existingData['createdAt'] ?? nowTimestamp,
        
        'lastUpdated': nowTimestamp,
        'updatedAt': nowTimestamp, 
        
        FirestoreFields.isVerified: isUpdate 
            ? (existingData[FirestoreFields.isVerified] ?? false) 
            : false, 
        
        FirestoreFields.status: isUpdate 
            ? (existingData[FirestoreFields.status] ?? PropertyStatus.disponible) 
            : PropertyStatus.disponible, 

        'hasPriorityRequest': isUpdate 
            ? (existingData['hasPriorityRequest'] ?? false) 
            : false, 
        'priorityStatus': isUpdate ? existingData['priorityStatus'] : null,
        'priorityRequestAt': isUpdate ? existingData['priorityRequestAt'] : null,

        FirestoreFields.processingStatus: isUpdate 
            ? (existingData[FirestoreFields.processingStatus] ?? WorkflowStatus.jachere) 
            : WorkflowStatus.jachere,

        FirestoreFields.assignedAdminId: isUpdate ? existingData[FirestoreFields.assignedAdminId] : null,
        FirestoreFields.assignedAdminName: isUpdate ? existingData[FirestoreFields.assignedAdminName] : null,

        'estLouee': existingData['estLouee'] ?? false,
        'electricite': formData.electricite ?? existingData['electricite'] ?? 'Pas d’électricité',
      });

      if (isUpdate) {
        await docRef.update(finalData);
        await _cleanupUnusedStorageImages(oldImageUrls, List<String>.from(finalData['imageUrls']));
      } else {
        await docRef.set(finalData);
        
        // Lancement asynchrone du tracking sans bloquer l'UI
        unawaited(_goalService.trackAction(
          ville: formData.ville ?? 'Inconnue', 
          type: MissionType.publications
        ));
      }

      await _cleanupLocalImages();

      // Journal d'activités
      await _firestore.collection(FirestoreCollections.activityLog).add({
        'activity': isUpdate 
            ? 'Mise à jour réussie : $finalPropertyId' 
            : 'Nouvelle publication : $finalPropertyId',
        'type': isUpdate ? 'modification' : 'creation', 
        'userId': bailleurId,
        'propertyId': finalPropertyId,
        'timestamp': nowTimestamp,
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