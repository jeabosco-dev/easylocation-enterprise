// lib/widgets/confirmation_publication_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/formulaire_publication_model.dart';
import '../services/config_service.dart';
import '../utils/ui_utils.dart';

class ConfirmationPublicationDialog extends StatefulWidget {
  final FormulairePublicationModel data;
  final VoidCallback onConfirm;

  const ConfirmationPublicationDialog({
    super.key,
    required this.data,
    required this.onConfirm,
  });

  @override
  State<ConfirmationPublicationDialog> createState() => _ConfirmationPublicationDialogState();
}

class _ConfirmationPublicationDialogState extends State<ConfirmationPublicationDialog> {
  bool _accepted = false;
  final ScrollController _dialogScrollController = ScrollController();

  @override
  void dispose() {
    _dialogScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigService>(context, listen: false);
    
    final double tauxCommission = config.commissionRate; 
    final double pourcentageAffichage = tauxCommission * 100;

    final double prixLoyer = widget.data.price ?? 0;
    final int garantieMinimale = widget.data.garantieMinimale ?? 0;
    
    final double montantCommission = prixLoyer * tauxCommission;
    final double montantRecuParBailleur = (prixLoyer * garantieMinimale) - montantCommission;

    return AlertDialog(
      title: const Text('Confirmer la publication'),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      content: SizedBox(
        width: double.maxFinite,
        child: Scrollbar(
          controller: _dialogScrollController,
          thumbVisibility: true,
          thickness: 6,
          radius: const Radius.circular(10),
          child: SingleChildScrollView(
            controller: _dialogScrollController,
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Récapitulatif des frais :',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Loyer mensuel :'),
                      trailing: Text('${UIUtils.formatPrice(prixLoyer)}\$')),
                ),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Garantie minimale :'),
                      trailing: Text('$garantieMinimale mois')),
                ),
                const Divider(height: 30),
                
                Text('Commission (${pourcentageAffichage.toStringAsFixed(0)}% sur le 1er mois uniquement) :',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Montant de la commission :'),
                      trailing: Text('${UIUtils.formatPrice(montantCommission, decimalDigits: 1)}\$')),
                ),
                
                const Text(
                  'Nos frais de commission sont déduits de la garantie versée par le locataire pour simplifier la transaction.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Le montant net que vous recevrez pour la garantie minimale est de ${UIUtils.formatPrice(montantRecuParBailleur)}\$.',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),
                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'J’accepte les frais et les conditions de publication',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    value: _accepted,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (bool? newValue) {
                      setState(() => _accepted = newValue ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _accepted ? widget.onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accepted ? Theme.of(context).primaryColor : Colors.grey[300],
            foregroundColor: _accepted ? Colors.white : Colors.grey[700],
          ),
          child: const Text('Publier la propriété'),
        ),
      ],
    );
  }
}