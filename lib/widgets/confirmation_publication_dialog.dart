import 'package:flutter/material.dart';
import '../models/formulaire_publication_model.dart';

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
    // Logique de calcul extraite fidèlement
    final double prixLoyer = widget.data.price ?? 0;
    final int garantieMinimale = widget.data.garantieMinimale ?? 0;
    final double montantCommission = prixLoyer * 0.15;
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
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Loyer mensuel :'),
                    trailing: Text('${prixLoyer.toStringAsFixed(2)}\$')),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Garantie idéale souhaitée :'),
                    trailing: Text('${widget.data.garantieIdeale ?? 0} mois')),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Garantie minimale :'),
                    trailing: Text('$garantieMinimale mois')),
                const Divider(height: 30),
                const Text('Commission (15% sur le 1er mois uniquement) :',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Montant de la commission :'),
                    trailing: Text('${montantCommission.toStringAsFixed(2)}\$')),
                const Text(
                  'Nos frais de commission peuvent être directement récupérés auprès du locataire, afin de faciliter le processus. Vous acceptez alors qu\'il déduise ce montant de la garantie globale à vous verser.',
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
                    'Le montant net que vous recevrez pour la garantie minimale est de ${montantRecuParBailleur.toStringAsFixed(2)}\$.',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),
                CheckboxListTile(
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
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
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
