// lib/widgets/informations_generales_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/formulaire_publication_controller.dart';
import 'selecteur_localisation.dart'; 

class InformationsGeneralesWidget extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  const InformationsGeneralesWidget({super.key, required this.formKey});

  @override
  _InformationsGeneralesWidgetState createState() => _InformationsGeneralesWidgetState();
}

class _InformationsGeneralesWidgetState extends State<InformationsGeneralesWidget> {
  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<FormulairePublicationController>(context);
    final data = controller.data;

    return Form(
      key: widget.formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text("Localisation",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          SelecteurLocalisation(
            provinceSaisie: data.province,
            villeSaisie: data.ville,
            communeSaisie: data.commune,
            quartierSaisi: data.quartier, 
            avenueSaisie: data.avenue,
            
            villeSpecifique: data.villeSpecifique,
            communeSpecifique: data.communeSpecifique,
            quartierSpecifique: data.quartierSpecifique,
            avenueSpecifique: data.avenueSpecifique,

            onProvinceChange: (val) => controller.updateData(
                province: val,
                ville: null, commune: null, quartier: null, avenue: null,
                villeSpecifique: null, communeSpecifique: null, 
                quartierSpecifique: null, avenueSpecifique: null),
            
            onVilleChange: (val) => controller.updateData(
                ville: val, 
                commune: null, quartier: null, avenue: null,
                villeSpecifique: null, communeSpecifique: null, 
                quartierSpecifique: null, avenueSpecifique: null),
            
            onCommuneChange: (val) => controller.updateData(
                commune: val, 
                quartier: null, avenue: null,
                communeSpecifique: null, quartierSpecifique: null, avenueSpecifique: null),
            
            onQuartierChange: (val) => controller.updateData(
                quartier: val, 
                avenue: null,
                quartierSpecifique: null, avenueSpecifique: null),
            
            onAvenueChange: (val) => controller.updateData(
                avenue: val,
                avenueSpecifique: null),

            onVilleSpecifiqueChange: (val) => controller.updateData(villeSpecifique: val),
            onCommuneSpecifiqueChange: (val) => controller.updateData(communeSpecifique: val),
            onQuartierSpecifiqueChange: (val) => controller.updateData(quartierSpecifique: val),
            onAvenueSpecifiqueChange: (val) => controller.updateData(avenueSpecifique: val),
          ),

          const SizedBox(height: 12),

          _buildTextField(
            label: 'Numéro de la maison (Optionnel)',
            hint: 'Ex: 12A',
            initialValue: data.numeroMaison,
            onChanged: (value) => controller.updateData(numeroMaison: value),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4.0, left: 4.0),
            child: Text(
              "Laissez vide si la maison n'a pas de numéro",
              style: TextStyle(color: Colors.blueGrey, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ),

          const SizedBox(height: 24),
          const Text("Conditions financières",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildTextField(
            label: 'Prix de loyer mensuel (\$) *',
            hint: 'Ex: 150',
            initialValue: data.price?.toString(),
            keyboard: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) =>
                controller.updateData(price: double.tryParse(value) ?? 0.0), // ✅ Corrigé : évite le null
            validator: (value) =>
                (double.tryParse(value ?? '') ?? 0) <= 0 ? 'Prix invalide' : null,
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Garantie idéale *',
                  hint: 'Mois',
                  initialValue: data.garantieIdeale?.toString(),
                  keyboard: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) =>
                      controller.updateData(garantieIdeale: int.tryParse(value)),
                  validator: (value) =>
                      (int.tryParse(value ?? '') ?? 0) <= 0 ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  label: 'Garantie min. *',
                  hint: 'Mois',
                  initialValue: data.garantieMinimale?.toString(),
                  keyboard: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) =>
                      controller.updateData(garantieMinimale: int.tryParse(value)),
                  validator: (value) {
                    final min = int.tryParse(value ?? '') ?? 0;
                    final ideal = data.garantieIdeale ?? 0;
                    if (min <= 0) return 'Invalide';
                    if (min > ideal) return 'Max $ideal';
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text("Disponibilité & Niveau",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

          // --- SECTION DISPONIBILITÉ ---
          _buildRadioSection<bool>(
            title: "Le bien est disponible : *",
            options: [
              RadioOption(label: "Immédiatement", value: true),
              RadioOption(label: "À une date précise", value: false),
            ],
            groupValue: data.disponibiliteImmediate,
            validator: (val) => val == null ? "Veuillez faire un choix" : null,
            onChanged: (val) => controller.updateData(
                disponibiliteImmediate: val, dateDisponibilite: null), // ✅ Nettoyage date
          ),

          if (data.disponibiliteImmediate == false) ...[
            FormField<DateTime>(
              initialValue: data.dateDisponibilite,
              validator: (val) => val == null ? "Obligatoire : Veuillez sélectionner une date précise" : null,
              builder: (state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: state.hasError ? Colors.red : Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: Text(data.dateDisponibilite != null
                          ? 'Date: ${data.dateDisponibilite!.day}/${data.dateDisponibilite!.month}/${data.dateDisponibilite!.year}'
                          : 'Cliquer pour choisir la date *'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) {
                          state.didChange(picked);
                          controller.updateData(dateDisponibilite: picked);
                        }
                      },
                    ),
                    if (state.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                        child: Text(state.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                  ],
                );
              },
            ),
          ],

          const SizedBox(height: 12),

          // --- SECTION NIVEAU ---
          _buildRadioSection<bool>(
            title: "Niveau de propriété : *",
            options: [
              RadioOption(label: "Maison non en étage", value: false),
              RadioOption(label: "Maison en étage", value: true),
            ],
            groupValue: data.maisonEnEtage,
            validator: (val) => val == null ? "Veuillez préciser le niveau" : null,
            onChanged: (val) {
              controller.updateData(
                  maisonEnEtage: val, niveauEtage: val == true ? null : 0); // ✅ Nettoyage étage
            },
          ),

          if (data.maisonEnEtage == true) ...[
            const SizedBox(height: 8),
            _buildTextField(
              label: 'Numéro de l\'étage *',
              hint: '0, 1, 2, 99...',
              initialValue: data.niveauEtage?.toString(),
              keyboard: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) =>
                  controller.updateData(niveauEtage: int.tryParse(value)),
              validator: (value) => (value == null || value.isEmpty) ? 'Ce champ est obligatoire' : null,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8.0, left: 4.0),
              child: Text(
                "Note : Mettez 0 pour Rez-de-chaussée, 99 pour Grenier. "
                "Pour les autres, mettez le chiffre exact (ex: 1 pour 1er étage).",
                style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    String? initialValue,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? formatters,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
      keyboardType: keyboard,
      inputFormatters: formatters,
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildRadioSection<T>({
    required String title,
    required List<RadioOption> options,
    required T? groupValue,
    required String? Function(T?)? validator,
    required Function(T) onChanged,
  }) {
    return FormField<T>(
      initialValue: groupValue,
      validator: validator,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            ...options.map((opt) => RadioListTile<T>(
                title: Text(opt.label),
                value: opt.value,
                groupValue: groupValue,
                onChanged: (val) {
                  if (val != null) {
                    state.didChange(val);
                    onChanged(val);
                  }
                },
                contentPadding: EdgeInsets.zero,
                dense: true)),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Text(state.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }
}

class RadioOption {
  final String label;
  final dynamic value;
  RadioOption({required this.label, required this.value});
}
