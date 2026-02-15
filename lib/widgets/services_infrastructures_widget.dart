// lib/widgets/services_infrastructures_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/formulaire_publication_controller.dart';

class ServicesInfrastructuresWidget extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  const ServicesInfrastructuresWidget({super.key, required this.formKey});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<FormulairePublicationController>(context);
    final data = controller.data;
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSectionTitle(context, "Services de base", Icons.water_drop_outlined),
          
          // --- SECTION EAU ---
          _buildCardWrapper(
            child: Column(
              children: [
                _buildValidatedToggle(
                  label: 'Présence d’eau ? *',
                  value: data.hasEau,
                  onChanged: (val) => controller.updateData(
                    hasEau: val, 
                    compteurEau: val ? data.compteurEau : null, 
                  ),
                  validator: (v) => v == null ? "Veuillez préciser la présence d'eau" : null,
                ),
                if (data.hasEau == true) ...[
                  const Divider(height: 32),
                  _buildValidatedToggle(
                    label: 'Compteur d’eau individuel ? *',
                    value: data.compteurEau,
                    onChanged: (val) => controller.updateData(compteurEau: val),
                    validator: (v) => v == null ? "Précisez si le compteur est individuel" : null,
                  ),
                ],
              ],
            ),
          ),

          _buildSectionTitle(context, "Énergie & Accès", Icons.electric_bolt_outlined),

          // --- SECTION ÉLECTRICITÉ ---
          _buildCardWrapper(
            child: FormField<String>(
              initialValue: data.electricite,
              validator: (value) => (value == null || value.isEmpty) 
                  ? 'Veuillez sélectionner une option d\'électricité' 
                  : null,
              builder: (state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRadioGroup(
                      'Disponibilité Électricité *',
                      [
                        'Propre Cash-power',
                        'Commun (Immeuble/Parcelle)',
                        'Pas d’électricité'
                      ],
                      data.electricite,
                      (value) {
                        state.didChange(value);
                        controller.updateData(electricite: value);
                      },
                    ),
                    if (state.hasError)
                      _buildErrorText(state.errorText!, theme),
                  ],
                );
              },
            ),
          ),

          // --- SECTION ACCESSIBILITÉ ---
          _buildCardWrapper(
            child: _buildValidatedToggle(
              label: 'Accessible en voiture ? *',
              value: data.accessibiliteVoiture,
              onChanged: (val) => controller.updateData(accessibiliteVoiture: val),
              validator: (v) => v == null ? "Champ obligatoire" : null,
            ),
          ),

          _buildSectionTitle(context, "Cohabitation", Icons.people_outline),

          // --- SECTION COHABITATION ---
          _buildCardWrapper(
            child: Column(
              children: [
                _buildValidatedToggle(
                  label: 'Le bailleur habite sur place ? *',
                  value: data.bailleurHabiteAvec,
                  onChanged: (val) => controller.updateData(bailleurHabiteAvec: val),
                  validator: (v) => v == null ? "Champ obligatoire" : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: data.nombreMenages?.toString(),
                  decoration: InputDecoration(
                    labelText: 'Combien de ménages vivent déjà sur place ? *',
                    hintText: '0 si la parcelle est vide',
                    prefixIcon: const Icon(Icons.groups_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => controller.updateData(
                    nombreMenages: int.tryParse(value),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Champ obligatoire';
                    final n = int.tryParse(value);
                    if (n == null || n < 0) return 'Entrez un nombre valide';
                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // --- HELPERS DE CONSTRUCTION ---

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardWrapper({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildValidatedToggle({
    required String label,
    required bool? value,
    required ValueChanged<bool> onChanged,
    required String? Function(bool?) validator,
  }) {
    return FormField<bool>(
      initialValue: value,
      validator: validator,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Oui')),
                    ButtonSegment(value: false, label: Text('Non')),
                  ],
                  // Crucial: Autoriser la sélection vide quand la donnée est null au début
                  emptySelectionAllowed: true, 
                  selected: state.value == null ? <bool>{} : {state.value!},
                  onSelectionChanged: (Set<bool> newSelection) {
                    if (newSelection.isNotEmpty) {
                      state.didChange(newSelection.first);
                      onChanged(newSelection.first);
                    }
                  },
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4),
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

  Widget _buildRadioGroup(
    String title,
    List<String> options,
    String? currentValue,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...options.map((option) => RadioListTile<String>(
              title: Text(option, style: const TextStyle(fontSize: 14)),
              value: option,
              groupValue: currentValue,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onChanged: onChanged,
            )),
      ],
    );
  }

  Widget _buildErrorText(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 12),
      child: Text(
        text,
        style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
      ),
    );
  }
}
