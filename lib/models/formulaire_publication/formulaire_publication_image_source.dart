// lib/models/formulaire_publication/formulaire_publication_image_source.dart
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// ***************************************************************
/// TYPE DÉDIÉ POUR LES IMAGES DANS LE FORMULAIRE DE PUBLICATION
/// ***************************************************************
@immutable
class ImageSource {
  final XFile? file;
  final String? url;

  const ImageSource({this.file, this.url});

  bool get isEmpty => file == null && url == null;
  bool get isFile => file != null;
  bool get isUrl => url != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageSource && 
      other.file?.path == file?.path && 
      other.url == url;

  @override
  int get hashCode => file.hashCode ^ url.hashCode;
}