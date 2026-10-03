// lib/services/submission/submission_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, VoidCallback;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

// Core imports corrigés
import '../../models/formulaire_publication_model.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import '../property_service.dart';
import '../../controllers/formulaire_publication_controller.dart';
import '../goal_tracking_service.dart';
import '../../models/community_goal_model.dart';
import '../../models/property_model.dart';

// Services internes
import 'image_upload_service.dart';
import 'image_cleanup_service.dart';
import 'image_compression_service.dart';

class SubmissionService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final PropertyService _propertyService;
  final GoalTrackingService _goalService;
  final ImageUploadService _uploadService;
  final ImageCleanupService _cleanupService;

  SubmissionService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    PropertyService? propertyService,
    GoalTrackingService? goalService,
    ImageUploadService? uploadService,
    ImageCleanupService? cleanupService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _propertyService = propertyService ?? PropertyService(),
        _goalService = goalService ?? GoalTrackingService(),
        _uploadService = uploadService ?? ImageUploadService(storage: storage),
        _cleanupService = cleanupService ?? ImageCleanupService(storage: storage);

  static const Map<String, String> _specificImageKeyMap = {
    'salonImage': 'salonImage',
    'cuisineImage': 'cuisineImage',
    'toiletteParentaleImage': 'toiletteParentaleImage',
    'garageImage': 'garageImage',
    'courRecreationImage': 'courRecreationImage',
    'depotImage': 'depotImage',
  };

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

  Future<void> submitProperty({
    required FormulairePublicationController controller,
    required String bailleurId,
    String? propertyId,
    Function(double)? onProgress,
  }) async {
    final bool isUpdate = propertyId != null;
    final docRef = isUpdate
        ? _firestore.collection(FirestoreCollections.properties).doc(propertyId)
        : _firestore.collection(FirestoreCollections.properties).doc();

    final finalPropertyId = docRef.id;
    final formData = controller.data;
    final List<File> tempFilesToClean = [];

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
          final double p = (imagesDone.toDouble() / totalImages.toDouble()) * 0.85;
          onProgress(p);
        }
      }

      onProgress?.call(0.05);

      Map<String, dynamic> existingData = {};
      List<dynamic> oldImageUrls = [];

      if (isUpdate) {
        final doc = await docRef.get();
        if (doc.exists) {
          existingData = Map<String, dynamic>.from(doc.data() as Map);
          oldImageUrls = List.from(existingData['imageUrls'] ?? []);
        }
      }

      // 1. Upload Image Principale
      final mainUploadResult = await _uploadService.uploadSingleImageSource(
        formData.mainImage, bailleurId, finalPropertyId, 'main',
        onComplete: updateProgress,
      );

      if (mainUploadResult.tempFileToClean != null) {
        tempFilesToClean.add(mainUploadResult.tempFileToClean!);
      }

      String? mainImageUrl = mainUploadResult.url ?? existingData['mainImageUrl'];
      if (mainImageUrl == null) {
        throw Exception('Image principale requise');
      }

      // 2. Upload Images Chambres
      final chambresResult = await _uploadService.uploadImageSourceList(
        formData.chambresImages, bailleurId, finalPropertyId, 'chambres',
        onImageComplete: updateProgress,
      );
      tempFilesToClean.addAll(chambresResult.tempFilesToClean);
      final List<String> chambresUrls = chambresResult.urls;

      // 3. Upload Images Spécifiques avec préservation des anciennes URL
   final Map<String, Future<UploadResult>> specificTasks = {};

_specificImageKeyMap.forEach((key, _) {
  final source = _getSourceFromKey(formData, key);

  // null = aucune photo à conserver pour ce champ.
  // Une ImageSource(url: ...) = conserver l'ancienne photo.
  // Une ImageSource(file: ...) = nouvelle photo à uploader.
  if (source != null) {
    specificTasks[key] = _uploadService.uploadSingleImageSource(
      source,
      bailleurId,
      finalPropertyId,
      key,
      onComplete: updateProgress,
    );
  }
});

      final Map<String, String> specificUrls = {};

      // ✅ REPRISE DES ANCIENNES IMAGES EXISTANTES SI NON REMPLACÉES
final specificKeys = specificTasks.keys.toList();

final List<UploadResult> specificUploadResults =
    await Future.wait(specificTasks.values);

for (int i = 0; i < specificKeys.length; i++) {
  final key = specificKeys[i];
  final uploadResult = specificUploadResults[i];

  if (uploadResult.tempFileToClean != null) {
    tempFilesToClean.add(uploadResult.tempFileToClean!);
  }

  if (uploadResult.url != null && uploadResult.url!.isNotEmpty) {
    specificUrls[key] = uploadResult.url!;
  }
}

      for (int i = 0; i < specificKeys.length; i++) {
        final key = specificKeys[i];
        final uploadResult = specificUploadResults[i];

        if (uploadResult.tempFileToClean != null) {
          tempFilesToClean.add(uploadResult.tempFileToClean!);
        }

        if (uploadResult.url != null && uploadResult.url!.isNotEmpty) {
          specificUrls[key] = uploadResult.url!;
        }
      }

      onProgress?.call(0.90);

      // Mise à jour du contrôleur
      controller.updateData(
        mainImage: ImageSource(url: mainImageUrl),
        chambresImages: chambresUrls.map((url) => ImageSource(url: url)).toList(),
        salonImage: specificUrls.containsKey('salonImage') ? ImageSource(url: specificUrls['salonImage']!) : null,
        cuisineImage: specificUrls.containsKey('cuisineImage') ? ImageSource(url: specificUrls['cuisineImage']!) : null,
        toiletteParentaleImage: specificUrls.containsKey('toiletteParentaleImage') ? ImageSource(url: specificUrls['toiletteParentaleImage']!) : null,
        garageImage: specificUrls.containsKey('garageImage') ? ImageSource(url: specificUrls['garageImage']!) : null,
        courRecreationImage: specificUrls.containsKey('courRecreationImage') ? ImageSource(url: specificUrls['courRecreationImage']!) : null,
        depotImage: specificUrls.containsKey('depotImage') ? ImageSource(url: specificUrls['depotImage']!) : null,
      );

      final Map<String, dynamic> finalData = Map<String, dynamic>.from(
        controller.prepareDataForFirebase(),
      );

      finalData.addAll({
        'hasSalon': specificUrls.containsKey('salonImage'),
        'hasCuisine': specificUrls.containsKey('cuisineImage'),
        'hasToiletteParentale': specificUrls.containsKey('toiletteParentaleImage'),
        'hasGarage': specificUrls.containsKey('garageImage'),
        'hasCourRecreation': specificUrls.containsKey('courRecreationImage'),
        'hasDepot': specificUrls.containsKey('depotImage'),
      });

      // Construction de roomMetadata
      final List<Map<String, dynamic>> roomMetadata = [
        {'label': 'Image principale', 'type': 'main', 'url': mainImageUrl}
      ];

      for (int i = 0; i < chambresUrls.length; i++) {
        roomMetadata.add({
          'label': 'Chambre ${i + 1}',
          'type': 'chambre',
          'roomIndex': i + 1,
          'url': chambresUrls[i],
        });
      }

      specificUrls.forEach((key, url) {
        roomMetadata.add({
          'label': key.replaceAll('Image', ''),
          'type': key,
          'url': url,
        });
      });

      final nowTimestamp = FieldValue.serverTimestamp();
      final status = isUpdate
          ? (existingData[FirestoreFields.status] ?? PropertyStatus.disponible)
          : PropertyStatus.disponible;

      final List<String> allImages = [
        mainImageUrl,
        ...chambresUrls,
        ...specificUrls.values,
      ];

      finalData.addAll({
        'id': finalPropertyId,
        'bailleurId': bailleurId,
        'typeBien': formData.typeBien,
        'mainImageUrl': mainImageUrl,
        'chambresImageUrls': chambresUrls,
        'specificImageUrls': specificUrls,
        'imageUrls': allImages,
        'roomMetadata': roomMetadata,
        'sortIndex': existingData['sortIndex'] ?? 0,
        'views': existingData['views'] ?? 0,
        'createdAt': existingData['createdAt'] ?? nowTimestamp,
        'lastUpdated': nowTimestamp,
        'updatedAt': nowTimestamp,
        FirestoreFields.status: status,
        'statusPriority': PropertyStatusNormalizer.getStatusPriority(status),
        'moderationStatus': isUpdate ? (existingData['moderationStatus'] ?? 'visible') : 'visible',
        FirestoreFields.isVerified: isUpdate ? (existingData[FirestoreFields.isVerified] ?? false) : false,
        FirestoreFields.isVisible: isUpdate ? (existingData[FirestoreFields.isVisible] ?? true) : true,
        'hasPriorityRequest': isUpdate ? (existingData['hasPriorityRequest'] ?? false) : false,
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
        await _cleanupService.cleanupUnusedStorageImages(oldImageUrls, allImages);
      } else {
        await docRef.set(finalData);
        unawaited(_goalService.trackAction(
          ville: formData.ville ?? 'Inconnue',
          type: MissionType.publications,
        ));
      }

      // Nettoyage ciblé des fichiers temporaires créés lors de la session
      await _cleanupService.cleanupLocalImages(tempFilesToClean);

      // Journal d'activité
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
}