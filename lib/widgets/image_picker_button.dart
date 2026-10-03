// lib/widgets/image_picker_button.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'dart:io' as io;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/formulaire_publication_model.dart';

class ImagePickerButton extends StatelessWidget {
  final ImageSource? currentImage;
  final String label;
  final ValueChanged<ImageSource> onImageSelected;
  final VoidCallback onImageRemoved;
  final bool isRequired;

  const ImagePickerButton({
    super.key,
    required this.currentImage,
    required this.label,
    required this.onImageSelected,
    required this.onImageRemoved,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage = currentImage != null &&
        (currentImage!.file != null || currentImage!.url != null);

    final Color borderColor = (isRequired && !hasImage)
        ? Colors.red
        : (hasImage ? Colors.blue : Colors.grey);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _pickImage(context),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                    color: borderColor, width: (isRequired && !hasImage) ? 2 : 1),
                borderRadius: BorderRadius.circular(8),
                color: hasImage ? Colors.blue.withOpacity(0.05) : Colors.grey[50],
              ),
              child: hasImage
                  ? Stack(
                      children: [
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: _buildPreviewImage(),
                              ),
                              const SizedBox(width: 15),
                              Flexible(
                                  child: Text("$label ajoutée",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: onImageRemoved,
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, color: borderColor, size: 30),
                          const SizedBox(height: 8),
                          Text("Ajouter photo - $label",
                              style: TextStyle(color: borderColor)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewImage() {
    if (currentImage?.file != null) {
      final pickedFile = currentImage!.file!;

      // 🌐 GESTION POUR LE WEB
      if (kIsWeb) {
        return Image.network(
          pickedFile.path,
          height: 80,
          width: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, color: Colors.orange, size: 50),
        );
      }

      // 📱 GESTION POUR MOBILE / DESKTOP
      final file = io.File(pickedFile.path);
      if (!file.existsSync()) {
        return const Icon(Icons.broken_image, color: Colors.orange, size: 50);
      }
      return Image.file(
        file,
        height: 80,
        width: 80,
        fit: BoxFit.cover,
        cacheWidth: 250,
      );
    } else if (currentImage?.url != null) {
      return Image.network(
        currentImage!.url!,
        height: 80,
        width: 80,
        fit: BoxFit.cover,
        cacheWidth: 250,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, size: 50),
      );
    }
    return const Icon(Icons.image, size: 50);
  }

  void _pickImage(BuildContext context) async {
    final imagePicker = picker.ImagePicker();
    final source = await showDialog<picker.ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Source de l'image"),
        content: const Text("Prendre une photo ou choisir dans la galerie ?"),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, picker.ImageSource.camera),
              child: const Text('Caméra')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, picker.ImageSource.gallery),
              child: const Text('Galerie')),
        ],
      ),
    );

    if (source != null) {
      final picker.XFile? pickedFile =
          await imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        // Sur le Web, pas de compression via le système de fichiers
        if (kIsWeb) {
          onImageSelected(ImageSource(file: pickedFile));
          return;
        }

        try {
          final appDir = await getApplicationDocumentsDirectory();
          final String fileName =
              'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final String targetPath = '${appDir.path}/$fileName';

          final XFile? compressedFile =
              await FlutterImageCompress.compressAndGetFile(
            pickedFile.path,
            targetPath,
            minWidth: 1080,
            minHeight: 1080,
            quality: 75,
            format: CompressFormat.jpeg,
          );

          onImageSelected(ImageSource(file: compressedFile ?? pickedFile));
          debugPrint("✅ Image sécurisée dans Documents : $targetPath");
        } catch (e) {
          debugPrint("❌ Erreur sécurisation image : $e");
          onImageSelected(ImageSource(file: pickedFile));
        }
      }
    }
  }
}