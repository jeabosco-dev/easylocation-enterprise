import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BoutonSignalerAbus extends StatelessWidget {
  final Color color;
  final bool showIcon;
  final String? propertyId;

  const BoutonSignalerAbus({
    super.key, 
    this.color = Colors.orange,
    this.showIcon = true,
    this.propertyId, 
  });

  void _showReportAbuseDialog(BuildContext context) {
    String? selectedAbuseType;
    final otherAbuseController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isSubmitting = false; // Pour gérer l'état d'envoi

    showDialog(
      context: context,
      barrierDismissible: false, // Empêche de fermer en cliquant à côté pendant l'envoi
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text("Signaler un abus"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Quel est le problème?"),
                    _buildRadio(setInnerState, 'Fraude', selectedAbuseType, (v) => selectedAbuseType = v),
                    _buildRadio(setInnerState, 'Contenu inapproprié', selectedAbuseType, (v) => selectedAbuseType = v),
                    _buildRadio(setInnerState, 'Faux profil', selectedAbuseType, (v) => selectedAbuseType = v),
                    _buildRadio(setInnerState, 'Autre', selectedAbuseType, (v) => selectedAbuseType = v),
                    
                    if (selectedAbuseType == 'Autre')
                      TextField(
                        controller: otherAbuseController,
                        decoration: const InputDecoration(labelText: "Titre du problème"),
                      ),
                    const SizedBox(height: 20),
                    const Text("Description détaillée :"),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: "Expliquez brièvement ici...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  onPressed: isSubmitting 
                    ? null 
                    : () async {
                        setInnerState(() => isSubmitting = true);
                        await _submitReport(
                          context, 
                          dialogContext, 
                          selectedAbuseType, 
                          otherAbuseController.text, 
                          descriptionController.text
                        );
                        // Si erreur, on redonne la main
                        if (dialogContext.mounted) {
                          setInnerState(() => isSubmitting = false);
                        }
                      },
                  child: isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Envoyer"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRadio(StateSetter setState, String value, String? groupValue, Function(String) onChanged) {
    return Material(
      color: Colors.transparent,
      child: RadioListTile<String>(
        title: Text(value),
        value: value,
        groupValue: groupValue,
        contentPadding: EdgeInsets.zero,
        onChanged: (val) => setState(() => onChanged(val!)),
      ),
    );
  }

  Future<void> _submitReport(BuildContext context, BuildContext dialogContext, String? type, String otherType, String desc) async {
    final finalType = type == 'Autre' ? otherType : type;
    
    if (finalType == null || finalType.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner le type de problème'))
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('abus_signalement').add({
        'propriete_id': propertyId ?? 'general', 
        'type_abus': finalType,
        'description': desc.trim(),
        'signaleur_id': FirebaseAuth.instance.currentUser?.uid ?? 'inconnu',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // FERMETURE DU DIALOG ICI
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Signalement envoyé avec succès.'),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi : $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: showIcon ? Icon(Icons.report_problem_outlined, color: color) : null,
      title: Text('Signaler un abus', style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: () => _showReportAbuseDialog(context),
    );
  }
}