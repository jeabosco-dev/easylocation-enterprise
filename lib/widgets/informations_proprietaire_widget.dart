import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Pour les formatters
import 'package:provider/provider.dart';
import '../../controllers/formulaire_publication_controller.dart';

class InformationsProprietaireWidget extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  const InformationsProprietaireWidget({super.key, required this.formKey});

  @override
  Widget build(BuildContext context) {
    // On utilise watch car on a besoin de réagir aux changements de statut (Autre)
    final controller = context.watch<FormulairePublicationController>();
    final data = controller.data;

    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSectionTitle(context, "Identité du bailleur (Propriétaire)", Icons.person_outline),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              "Ces informations figureront sur le contrat de bail. Vous pouvez les modifier si vous publiez pour un tiers.",
              style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 8),

          _buildCardWrapper(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: controller.nomProprioCtrl, // Utilisation du controller central
                        label: 'Nom *',
                        icon: Icons.badge_outlined,
                        onChanged: (value) => controller.updateData(nomProprietaire: value),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: controller.postnomProprioCtrl,
                        label: 'Post-nom *',
                        onChanged: (value) => controller.updateData(postnomProprietaire: value),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Requis' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: controller.prenomProprioCtrl,
                  label: 'Prénom (Facultatif)',
                  icon: Icons.person_add_alt,
                  onChanged: (value) => controller.updateData(prenomProprietaire: value),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: controller.telProprioCtrl,
                  label: 'Téléphone du bailleur *',
                  icon: Icons.phone_android,
                  keyboardType: TextInputType.phone,
                  formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                  onChanged: (value) => controller.updateData(telephoneProprietaire: value),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Requis';
                    if (value.length < 9) return 'Numéro trop court';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: controller.emailProprioCtrl,
                  label: 'Email du bailleur (Facultatif)',
                  icon: Icons.alternate_email,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) => controller.updateData(emailProprietaire: value),
                  validator: (value) {
                    if (value != null && value.isNotEmpty && !value.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
              ],
            ),
          ),

          _buildSectionTitle(context, "Situation Juridique", Icons.gavel_outlined),

          _buildCardWrapper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRadioGroup(
                  title: 'Statut légal par rapport au bien *',
                  options: [
                    'Propriétaire légal',
                    'Mandataire (Agit au nom du propriétaire)',
                    'Autre'
                  ],
                  currentValue: data.statutLegal,
                  onChanged: (value) {
                    controller.updateData(
                      statutLegal: value,
                      statutLegalAutre: value == 'Autre' ? data.statutLegalAutre : null
                    );
                    if (value != 'Autre') controller.statutLegalAutreCtrl.clear();
                  },
                ),
                if (data.statutLegal == 'Autre') ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: controller.statutLegalAutreCtrl,
                    label: 'Précisez le statut *',
                    icon: Icons.edit_note,
                    onChanged: (value) => controller.updateData(statutLegalAutre: value),
                    validator: (value) => value == null || value.isEmpty ? 'Précision requise' : null,
                  ),
                ],
              ],
            ),
          ),

          _buildSectionTitle(context, "Profil & Réactivité", Icons.work_outline),

          _buildCardWrapper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRadioGroup(
                  title: 'Statut professionnel du bailleur *',
                  options: ['Commerçant(e)', 'Fonctionnaire', 'Employé(e)', 'Entrepreneur(e)', 'Autre'],
                  currentValue: data.statutProfessionnel,
                  onChanged: (value) {
                    controller.updateData(
                      statutProfessionnel: value,
                      statutProAutre: value == 'Autre' ? data.statutProAutre : null
                    );
                    if (value != 'Autre') controller.statutProAutreCtrl.clear();
                  },
                ),
                if (data.statutProfessionnel == 'Autre') ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: controller.statutProAutreCtrl,
                    label: 'Précisez la profession *',
                    onChanged: (value) => controller.updateData(statutProAutre: value),
                    validator: (value) => value == null || value.isEmpty ? 'Requis' : null,
                  ),
                ],
                const Divider(height: 32),
                _buildSegmentedToggle(
                  label: 'Bailleur réactif pour réparations ?',
                  value: data.estReactif,
                  onChanged: (val) => controller.updateData(estReactif: val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    required ValueChanged<String> onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      inputFormatters: formatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: Theme.of(context).primaryColor, 
                  letterSpacing: 1.1)),
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: child,
    );
  }

  Widget _buildSegmentedToggle({required String label, required bool? value, required ValueChanged<bool> onChanged}) {
    return FormField<bool>(
      initialValue: value,
      validator: (val) => val == null ? 'Sélection requise' : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Oui')),
                    ButtonSegment(value: false, label: Text('Non')),
                  ],
                  selected: value == null ? <bool>{} : {value},
                  emptySelectionAllowed: true,
                  onSelectionChanged: (Set<bool> newSelection) {
                    if (newSelection.isNotEmpty) {
                      onChanged(newSelection.first);
                      state.didChange(newSelection.first);
                    }
                  },
                ),
              ],
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(state.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        );
      }
    );
  }

  Widget _buildRadioGroup({
    required String title, 
    required List<String> options, 
    required String? currentValue, 
    required ValueChanged<String?> onChanged
  }) {
    return FormField<String>(
      initialValue: currentValue,
      validator: (value) => (value == null || value.isEmpty) ? 'Veuillez choisir une option' : null,
      builder: (FormFieldState<String> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...options.map((option) => Material(
                  color: Colors.transparent,
                  child: RadioListTile<String>(
                    title: Text(option, style: const TextStyle(fontSize: 14)),
                    value: option,
                    groupValue: currentValue,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onChanged: (val) {
                      state.didChange(val);
                      onChanged(val);
                    },
                  ),
                )),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
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