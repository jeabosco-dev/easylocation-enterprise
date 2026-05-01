import 'package:flutter/material.dart';
import '../../models/wallet_model.dart';

class TransferDialog extends StatefulWidget {
  final WalletModel wallet;
  final Function(String phone, double amount) onVerify;

  const TransferDialog({
    super.key,
    required this.wallet,
    required this.onVerify,
  });

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    phoneController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Envoyer des crédits"),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Le destinataire recevra le montant en Crédit Service (Bonus).",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "N° Téléphone destinataire",
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) =>
                  (val == null || val.isEmpty) ? "Numéro requis" : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Montant (\$)",
                suffixText: "\$",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return "Montant requis";
                double? amt = double.tryParse(val);
                if (amt == null || amt <= 0) return "Montant invalide";
                if (amt > widget.wallet.totalAvailable) return "Solde insuffisant";
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("ANNULER"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final double amount = double.parse(amountController.text);
              final String phone = phoneController.text.trim();
              
              // On ferme ce dialogue avant de lancer la vérification
              Navigator.pop(context);
              
              // On déclenche la fonction de vérification passée en paramètre
              widget.onVerify(phone, amount);
            }
          },
          child: const Text(
            "VÉRIFIER",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}