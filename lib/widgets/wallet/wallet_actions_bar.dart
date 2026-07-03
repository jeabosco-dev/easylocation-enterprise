import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/wallet_model.dart';
import '../../providers/wallet_provider.dart';

class WalletActionsBar extends StatelessWidget {
  final WalletModel wallet;

  const WalletActionsBar({
    super.key,
    required this.wallet,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionButton(
          Icons.send_rounded,
          "Envoyer",
          Colors.blue.shade800,
          () {
            if (wallet.totalAvailable > 0) {
              _showSendDialog(context, wallet);
            } else {
              _showError(context, "Votre solde est vide.");
            }
          },
        ),
        const SizedBox(width: 40), // Espacement entre les deux boutons
        _actionButton(
          Icons.call_received_rounded,
          "Demander",
          Colors.green.shade700,
          () => _showRequestDialog(context),
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // --- DIALOGUES CORRIGÉS ---

  void _showSendDialog(BuildContext context, WalletModel wallet) {
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Envoyer des crédits"),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
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
                  validator: (val) => (val == null || val.isEmpty) ? "Requis" : null,
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
                    if (val == null || val.isEmpty) return "Requis";
                    double? amt = double.tryParse(val);
                    if (amt == null || amt <= 0) return "Invalide";
                    if (amt > wallet.totalAvailable) return "Solde insuffisant";
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final double amount = double.parse(amountController.text);
                final String phone = phoneController.text.trim();
                Navigator.pop(context);
                _handleVerifyAndSend(context, phone, amount);
              }
            },
            child: const Text("VÉRIFIER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRequestDialog(BuildContext context) {
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.call_received_rounded, color: Colors.green.shade700),
            const SizedBox(width: 10),
            const Flexible(child: Text("Demander des crédits")),
          ],
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Le destinataire recevra une notification pour accepter ou refuser votre demande.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "N° de téléphone",
                    prefixIcon: const Icon(Icons.contact_phone),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => (val == null || val.isEmpty) ? "Requis" : null,
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
                  validator: (val) => (val == null || val.isEmpty) ? "Requis" : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final double amount = double.parse(amountController.text);
                final String phone = phoneController.text.trim();
                Navigator.pop(context);
                _handleSendRequest(context, phone, amount);
              }
            },
            child: const Text("ENVOYER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- LOGIQUE ACTIONS ---

  void _handleVerifyAndSend(BuildContext context, String phone, double amount) async {
    _showLoading(context);
    try {
      final String? recipientName = await context.read<WalletProvider>().getUserNameByPhone(phone);
      if (context.mounted) {
        Navigator.pop(context);
        if (recipientName != null) {
          _confirmTransfer(context, phone, recipientName, amount);
        } else {
          _showError(context, "Utilisateur non trouvé.");
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showError(context, "Erreur de recherche.");
      }
    }
  }

  void _handleSendRequest(BuildContext context, String phone, double amount) async {
    _showLoading(context);
    try {
      final provider = context.read<WalletProvider>();
      final String? recipientName = await provider.getUserNameByPhone(phone);
      if (context.mounted) Navigator.pop(context);

      if (recipientName != null) {
        await provider.createPaymentRequest(receiverPhone: phone, amount: amount);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Demande envoyée à $recipientName"), backgroundColor: Colors.blue.shade800),
          );
        }
      } else {
        _showError(context, "Numéro inconnu.");
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showError(context, "Erreur lors de l'envoi.");
      }
    }
  }

  void _showLoading(BuildContext context) {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red.shade700));
  }

  void _confirmTransfer(BuildContext context, String phone, String recipientName, double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer l'envoi"),
        content: Text(
          "Envoyer $amount \$ à ${recipientName.toUpperCase()} ?",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("MODIFIER")),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _showLoading(context);
                  await context.read<WalletProvider>().sendCreditsToUser(receiverPhone: phone, amount: amount);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transfert réussi !"), backgroundColor: Colors.green));
                  }
                },
                child: const Text("CONFIRMER"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}