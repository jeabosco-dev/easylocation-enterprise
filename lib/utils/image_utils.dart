// Fichier : lib/utils/image_utils.dart
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';

class ImageUtils {
  static Future<dynamic> pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      if (kIsWeb) {
        // Pour le Web, retourne directement les octets (Uint8List).
        return await image.readAsBytes();
      } else {
        // Pour mobile/desktop, retourne un objet File.
        return File(image.path);
      }
    }
    return null;
  }
}
