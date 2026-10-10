// lib/widgets/toilettes_section_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/formulaire_publication_controller.dart';
import '../models/formulaire_publication/formulaire_publication_image_source.dart';
import 'image_picker_button.dart';

class ToilettesSectionWidget extends StatelessWidget {
  const ToilettesSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FormulairePublicationController>();
    final data = controller.data;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          "Toilettes & Sanitaires",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // 1. Toilette Parentale (Interne / Privative)
        _buildValidatedYesNo(
          "Toilette parentale (chambre parentale) ? *",
          data.hasToiletteParentale,
          (val) => controller.updateData(
            hasToiletteParentale: val,
            toiletteParentaleImage: val ? data.toiletteParentaleImage : null,
          ),
        ),
        if (data.hasToiletteParentale == true)
          _buildValidatedImagePicker(
            label: 'Toilette Parentale',
            currentImage: data.toiletteParentaleImage,
            onImageSelected: (source) =>
                controller.updateData(toiletteParentaleImage: source),
            onImageRemoved: () =>
                controller.updateData(toiletteParentaleImage: null),
          ),

        const SizedBox(height: 16),

        // 2. Toilette Interne Commune (Partagée famille/enfants)
        _buildValidatedYesNo(
          "Toilette intérieure commune (familiale) ? *",
          data.hasToiletteInterneCommune,
          (val) => controller.updateData(
            hasToiletteInterneCommune: val,
            toiletteInterneCommuneImage:
                val ? data.toiletteInterneCommuneImage : null,
          ),
        ),
        if (data.hasToiletteInterneCommune == true)
          _buildValidatedImagePicker(
            label: 'Toilette intérieure commune',
            currentImage: data.toiletteInterneCommuneImage,
            onImageSelected: (source) =>
                controller.updateData(toiletteInterneCommuneImage: source),
            onImageRemoved: () =>
                controller.updateData(toiletteInterneCommuneImage: null),
          ),

        const SizedBox(height: 16),

        // 3. Toilette Externe (Parcelle / Cour)
        _buildValidatedYesNo(
          "Toilette extérieure ? *",
          data.hasToiletteExterne,
          (val) => controller.updateData(
            hasToiletteExterne: val,
            toiletteExterneImage: val ? data.toiletteExterneImage : null,
          ),
        ),
        if (data.hasToiletteExterne == true)
          _buildValidatedImagePicker(
            label: 'Toilette Externe',
            currentImage: data.toiletteExterneImage,
            onImageSelected: (source) =>
                controller.updateData(toiletteExterneImage: source),
            onImageRemoved: () =>
                controller.updateData(toiletteExterneImage: null),
          ),
      ],
    );
  }

  Widget _buildValidatedYesNo(
    String title,
    bool? currentValue,
    ValueChanged<bool> onChanged,
  ) {
    return FormField<bool>(
      initialValue: currentValue,
      validator: (value) =>
          currentValue == null ? 'Ce choix est obligatoire' : null,
      builder: (FormFieldState<bool> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: RadioListTile<bool>(
                      title: const Text('Oui'),
                      value: true,
                      groupValue: currentValue,
                      onChanged: (v) {
                        onChanged(v!);
                        state.didChange(v);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: RadioListTile<bool>(
                      title: const Text('Non'),
                      value: false,
                      groupValue: currentValue,
                      onChanged: (v) {
                        onChanged(v!);
                        state.didChange(v);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildValidatedImagePicker({
    required String label,
    required ImageSource? currentImage,
    required ValueChanged<ImageSource> onImageSelected,
    required VoidCallback onImageRemoved,
  }) {
    return FormField<ImageSource>(
      initialValue: currentImage,
      validator: (value) => (currentImage == null || currentImage.isEmpty)
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
                child: Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}