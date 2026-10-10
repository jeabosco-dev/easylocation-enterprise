// lib/widgets/admin/admin_video_section_widget.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/property_model.dart';
import '../../services/property_service.dart';

class AdminVideoSectionWidget extends StatefulWidget {
  final Property property;
  final VoidCallback onVideoUpdated;

  const AdminVideoSectionWidget({
    super.key,
    required this.property,
    required this.onVideoUpdated,
  });

  @override
  State<AdminVideoSectionWidget> createState() => _AdminVideoSectionWidgetState();
}

class _AdminVideoSectionWidgetState extends State<AdminVideoSectionWidget> {
  final PropertyService _propertyService = PropertyService();

  Future<void> _pickAndUploadVideo() async {
    final picker.ImagePicker imagePicker = picker.ImagePicker();
    
    // ✅ 1. Durée maximale portée à 2 minutes
    final picker.XFile? pickedVideo = await imagePicker.pickVideo(
      source: picker.ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );

    if (pickedVideo == null) return;

    final int sizeInBytes = await pickedVideo.length();
    final double sizeInMb = sizeInBytes / (1024 * 1024);

    // ✅ 2. Poids maximal porté à 50 Mo
    if (sizeInMb > 50) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Fichier trop volumineux"),
            content: const Text("La vidéo est trop lourde (> 50 Mo). Veuillez choisir une vidéo plus courte ou compressée."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    try {
      final String fileName = "visite_${DateTime.now().millisecondsSinceEpoch}.mp4";

      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('proprietes')
          .child(widget.property.id)
          .child('video')
          .child(fileName);

      UploadTask uploadTask;
      if (kIsWeb) {
        final Uint8List videoBytes = await pickedVideo.readAsBytes();
        uploadTask = storageRef.putData(
          videoBytes,
          SettableMetadata(contentType: 'video/mp4'),
        );
      } else {
        final File videoFile = File(pickedVideo.path);
        uploadTask = storageRef.putFile(
          videoFile,
          SettableMetadata(contentType: 'video/mp4'),
        );
      }

      // Affichage de la boîte de dialogue avec barre de progression dynamique
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Text("Téléversement en cours"),
            content: StreamBuilder<TaskSnapshot>(
              stream: uploadTask.snapshotEvents,
              builder: (context, snapshot) {
                double progress = 0.0;
                if (snapshot.hasData) {
                  final data = snapshot.data!;
                  progress = data.bytesTransferred / data.totalBytes;
                }
                int percent = (progress * 100).toInt();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Veuillez patienter pendant l'envoi de la visite virtuelle..."),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(value: progress, minHeight: 10),
                    const SizedBox(height: 15),
                    Text(
                      "$percent %",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Attente de la fin de l'upload
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      await _propertyService.updateVideoUrl(widget.property.id, downloadUrl);
      widget.onVideoUpdated();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎬 Visite virtuelle ajoutée avec succès !"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      debugPrint("Erreur upload vidéo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'upload : $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeVideo() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer la vidéo ?"),
        content: const Text("Cette action retirera la visite virtuelle de la propriété."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      final String? currentVideoUrl = widget.property.videoUrl;

      if (currentVideoUrl != null && currentVideoUrl.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(currentVideoUrl);
          await ref.delete();
        } catch (_) {} 
      }

      await _propertyService.removeVideoUrl(widget.property.id);
      widget.onVideoUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vidéo supprimée."), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint("Erreur suppression vidéo : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? videoUrl = widget.property.videoUrl;
    final bool hasVideo = videoUrl != null && videoUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 5),
          child: Text(
            "VISITE VIRTUELLE (VIDÉO)".toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Colors.blueGrey.shade700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        hasVideo
            ? Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_fill, color: Colors.green, size: 32),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Vidéo certifiée active", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text("La visite est disponible pour les locataires.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _removeVideo,
                      tooltip: "Supprimer la vidéo",
                    ),
                  ],
                ),
              )
            : InkWell(
                onTap: _pickAndUploadVideo,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200, style: BorderStyle.solid),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, color: Colors.blue, size: 28),
                      SizedBox(height: 6),
                      Text(
                        "Ajouter la vidéo de visite (2 min max)", // ✅ Mis à jour textuellement
                        style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}