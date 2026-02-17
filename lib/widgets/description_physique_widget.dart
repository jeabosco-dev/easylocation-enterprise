// lib/widgets/description_physique_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart'; // ✅ Ajouté

import '../../controllers/formulaire_publication_controller.dart';
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

    final Color borderColor = (isRequired && !hasImage) ? Colors.red : (hasImage ? Colors.blue : Colors.grey);

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
                border: Border.all(color: borderColor, width: (isRequired && !hasImage) ? 2 : 1),
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
                                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                          Text("Ajouter photo - $label", style: TextStyle(color: borderColor)),
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
      final file = File(currentImage!.file!.path);
      // ✅ Sécurité : Vérifier l'existence avant l'affichage pour éviter PathNotFoundException
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
      return Image.network(currentImage!.url!,
          height: 80,
          width: 80,
          fit: BoxFit.cover,
          cacheWidth: 250,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50));
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
          TextButton(onPressed: () => Navigator.pop(context, picker.ImageSource.camera), child: const Text('Caméra')),
          TextButton(onPressed: () => Navigator.pop(context, picker.ImageSource.gallery), child: const Text('Galerie')),
        ],
      ),
    );

    if (source != null) {
      final picker.XFile? pickedFile = await imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        try {
          // ✅ FIX : Utiliser getApplicationDocumentsDirectory au lieu du dossier temporaire/cache
          final appDir = await getApplicationDocumentsDirectory();
          final String fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final String targetPath = '${appDir.path}/$fileName';

          final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
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
          // Repli sur le fichier original en cas d'erreur de compression
          onImageSelected(ImageSource(file: pickedFile));
        }
      }
    }
  }
}

class DescriptionPhysiqueWidget extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  const DescriptionPhysiqueWidget({super.key, required this.formKey});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FormulairePublicationController>();
    final data = controller.data;

    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text("Pièces & Espaces", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildTextField(
            label: 'Nombre de chambres *',
            hint: 'Ex: 3',
            initialValue: data.nombreChambres?.toString(),
            keyboard: TextInputType.number,
            onChanged: (value) => controller.updateData(nombreChambres: int.tryParse(value)),
            validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0 ? 'Minimum 1 chambre' : null,
          ),

          if ((data.nombreChambres ?? 0) > 0) ...[
            const SizedBox(height: 12),
            const Text('Photos des Chambres *', style: TextStyle(fontWeight: FontWeight.w600)),
            ...List.generate(data.nombreChambres ?? 0, (index) {
              final image = data.chambresImages.length > index ? data.chambresImages[index] : null;
              return _buildValidatedImagePicker(
                label: 'Chambre ${index + 1}',
                currentImage: image,
                onImageSelected: (source) {
                  final currentSources = List<ImageSource>.from(data.chambresImages);
                  while (currentSources.length <= index) {
                    currentSources.add(ImageSource());
                  }
                  currentSources[index] = source;
                  controller.updateData(chambresImages: currentSources);
                },
                onImageRemoved: () {
                  final currentSources = List<ImageSource>.from(data.chambresImages);
                  if (currentSources.length > index) {
                    currentSources.removeAt(index);
                    controller.updateData(chambresImages: currentSources);
                  }
                },
              );
            }),
          ],

          const SizedBox(height: 24),
          const Text("Détails Intérieurs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildDropdownField(
            label: 'Type de sol *',
            value: data.selectedTypeSol,
            items: ['en carrelé', 'en ciment', 'autre'],
            onChanged: (value) => controller.updateData(selectedTypeSol: value),
            validator: (value) => value == null ? 'Champ obligatoire' : null,
          ),

          const SizedBox(height: 16),
          _buildValidatedYesNo(
              "Y a-t-il un salon ? *",
              data.hasSalon,
              (val) => controller.updateData(hasSalon: val, salonImage: val ? data.salonImage : null)),
          if (data.hasSalon == true)
            _buildValidatedImagePicker(
              label: 'Salon',
              currentImage: data.salonImage,
              onImageSelected: (source) => controller.updateData(salonImage: source),
              onImageRemoved: () => controller.updateData(salonImage: null),
            ),

          const SizedBox(height: 16),
          _buildValidatedYesNo("Y a-t-il une cuisine ? *", data.hasCuisine,
              (val) => controller.updateData(hasCuisine: val, cuisineImage: val ? data.cuisineImage : null)),
          if (data.hasCuisine == true)
            _buildValidatedImagePicker(
              label: 'Cuisine',
              currentImage: data.cuisineImage,
              onImageSelected: (source) => controller.updateData(cuisineImage: source),
              onImageRemoved: () => controller.updateData(cuisineImage: null),
            ),

          const SizedBox(height: 16),
          _buildValidatedYesNo("Y a-t-il une arrière-cuisine (dépôt) ? *", data.hasDepot,
              (val) => controller.updateData(hasDepot: val, depotImage: val ? data.depotImage : null)),
          if (data.hasDepot == true)
            _buildValidatedImagePicker(
              label: 'Dépôt',
              currentImage: data.depotImage,
              onImageSelected: (source) => controller.updateData(depotImage: source),
              onImageRemoved: () => controller.updateData(depotImage: null),
            ),

          const SizedBox(height: 16),
          _buildValidatedYesNo("Toilette interne (parents) ? *", data.hasToiletteParentale,
              (val) => controller.updateData(hasToiletteParentale: val, toiletteParentaleImage: val ? data.toiletteParentaleImage : null)),
          if (data.hasToiletteParentale == true)
            _buildValidatedImagePicker(
              label: 'Toilette Parentale',
              currentImage: data.toiletteParentaleImage,
              onImageSelected: (source) => controller.updateData(toiletteParentaleImage: source),
              onImageRemoved: () => controller.updateData(toiletteParentaleImage: null),
            ),

          const SizedBox(height: 24),
          const Text("Commodités & Extérieur", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildValidatedYesNo("Garage ? *", data.hasGarage,
              (val) => controller.updateData(hasGarage: val, garageImage: val ? data.garageImage : null)),
          if (data.hasGarage == true)
            _buildValidatedImagePicker(
              label: 'Garage',
              currentImage: data.garageImage,
              onImageSelected: (source) => controller.updateData(garageImage: source),
              onImageRemoved: () => controller.updateData(garageImage: null),
            ),

          _buildValidatedYesNo("Cour de récréation ? *", data.hasCourRecreation,
              (val) => controller.updateData(hasCourRecreation: val, courRecreationImage: val ? data.courRecreationImage : null)),
          if (data.hasCourRecreation == true)
            _buildValidatedImagePicker(
              label: 'Cour de Récréation',
              currentImage: data.courRecreationImage,
              onImageSelected: (source) => controller.updateData(courRecreationImage: source),
              onImageRemoved: () => controller.updateData(courRecreationImage: null),
            ),

          _buildValidatedRadioGroup(
            "Type de maison *",
            ['en matériaux durable', 'en matériaux semi durable'],
            data.typeMaison,
            (val) => controller.updateData(typeMaison: val),
          ),

          _buildValidatedYesNo("Maison en enclos ? *", data.maisonEnclos, (val) => controller.updateData(maisonEnclos: val)),

          _buildValidatedYesNo("Élevage animaux possible ? *", data.possibiliteAnimaux, (val) => controller.updateData(possibiliteAnimaux: val)),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildValidatedImagePicker({
    required String label,
    required ImageSource? currentImage,
    required ValueChanged<ImageSource> onImageSelected,
    required VoidCallback onImageRemoved,
  }) {
    return FormField<ImageSource>(
      initialValue: currentImage,
      validator: (value) => (currentImage == null || (currentImage.file == null && currentImage.url == null))
          ? 'La photo de "$label" est obligatoire'
          : null,
      builder: (FormFieldState<ImageSource> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ImagePickerButton(
              label: label,
              currentImage: currentImage,
              isRequired: true,
              onImageSelected: (source) {
                onImageSelected(source);
                state.didChange(source);
              },
              onImageRemoved: () {
                onImageRemoved();
                state.didChange(null);
              },
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(state.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(
      {required String label,
      required String hint,
      String? initialValue,
      TextInputType keyboard = TextInputType.text,
      Function(String)? onChanged,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
        keyboardType: keyboard,
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownField(
      {required String label,
      required String? value,
      required List<String> items,
      required Function(String?) onChanged,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  Widget _buildValidatedYesNo(String title, bool? currentValue, ValueChanged<bool> onChanged) {
    return FormField<bool>(
      initialValue: currentValue,
      validator: (value) => currentValue == null ? 'Ce choix est obligatoire' : null,
      builder: (FormFieldState<bool> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Row(
              children: [
                Expanded(
                    child: RadioListTile<bool>(
                        title: const Text('Oui'),
                        value: true,
                        groupValue: currentValue,
                        onChanged: (v) {
                          onChanged(v!);
                          state.didChange(v);
                        },
                        contentPadding: EdgeInsets.zero)),
                Expanded(
                    child: RadioListTile<bool>(
                        title: const Text('Non'),
                        value: false,
                        groupValue: currentValue,
                        onChanged: (v) {
                          onChanged(v!);
                          state.didChange(v);
                        },
                        contentPadding: EdgeInsets.zero)),
              ],
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(state.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildValidatedRadioGroup(String title, List<String> options, String? currentValue, ValueChanged<String?> onChanged) {
    return FormField<String>(
      initialValue: currentValue,
      validator: (value) => currentValue == null ? 'Ce choix est obligatoire' : null,
      builder: (FormFieldState<String> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ...options.map((opt) => RadioListTile<String>(
                title: Text(opt),
                value: opt,
                groupValue: currentValue,
                onChanged: (val) {
                  onChanged(val);
                  state.didChange(val);
                },
                contentPadding: EdgeInsets.zero,
                dense: true)),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(state.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }
}