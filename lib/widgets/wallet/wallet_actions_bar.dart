import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/wallet_model.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/phone_utils.dart';

class WalletActionsBar extends StatefulWidget {
  final WalletModel wallet;

  const WalletActionsBar({
    super.key,
    required this.wallet,
  });

  @override
  State<WalletActionsBar> createState() => _WalletActionsBarState();
}

class _WalletActionsBarState extends State<WalletActionsBar> {
  late BuildContext _pageContext;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pageContext = context;
  }

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
            if (widget.wallet.totalAvailable > 0) {
              _showSendDialog(_pageContext, widget.wallet);
            } else {
              _showError(_pageContext, "Votre solde est vide.");
            }
          },
        ),
        const SizedBox(width: 40),
        _actionButton(
          Icons.call_received_rounded,
          "Demander",
          Colors.green.shade700,
          () => _showRequestDialog(_pageContext),
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

  // --- DIALOGUES ---

  // Méthode appelée lors du clic sur le bouton "Check" (Accepter)
  void showAcceptDialog(BuildContext pageContext, Map<String, dynamic> request) {
    final TextEditingController amountController = TextEditingController(text: request['amount'].toString());

    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: Text("Accepter demande de ${request['senderName'] ?? 'Utilisateur'}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Montant initial : ${request['amount']} \$"),
            const SizedBox(height: 15),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Montant à envoyer (\$)", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Fermer le dialogue
              pageContext.read<WalletProvider>().rejectPaymentRequest(request['id']);
            },
            child: const Text("REFUSER", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              double finalAmount = double.tryParse(amountController.text) ?? (request['amount'] as num).toDouble();
              Navigator.pop(dialogContext); // Fermer le dialogue
              _confirmAcceptance(pageContext, request, finalAmount);
            },
            child: const Text("ACCEPTER"),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAcceptance(BuildContext pageContext, Map<String, dynamic> request, double amount) async {
    BuildContext? loadingDialogContext;
    showDialog(context: pageContext, barrierDismissible: false, builder: (c) {
      loadingDialogContext = c;
      return const Center(child: CircularProgressIndicator());
    });

    try {
      final provider = pageContext.read<WalletProvider>();
      // On passe le montant modifié dans la requête
      await provider.acceptPaymentRequest({...request, 'amount': amount});
      
      if (mounted) ScaffoldMessenger.of(pageContext).showSnackBar(const SnackBar(content: Text("Paiement accepté !")));
    } catch (e) {
      _showError(pageContext, "Erreur : $e");
    } finally {
      // Garantit la fermeture du loader même en cas d'erreur
      if (loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
        Navigator.pop(loadingDialogContext!); 
      }
    }
  }

  void _showSendDialog(BuildContext pageContext, WalletModel wallet) {
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Envoyer des crédits"),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Le destinataire recevra le montant en Crédit Service.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 15),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "N° Téléphone destinataire",
                    prefixIcon: const Icon(Icons.phone),
                    prefixText: "+243 ",
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
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final double amount = double.parse(amountController.text);
                final String phone = normalizePhoneNumber(phoneController.text.trim());
                Navigator.pop(dialogContext); 
                _handleVerifyAndSend(pageContext, phone, amount);
              }
            },
            child: const Text("VÉRIFIER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRequestDialog(BuildContext pageContext) {
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
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
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "N° de téléphone", prefixText: "+243 "),
                  validator: (val) => (val == null || val.isEmpty) ? "Requis" : null,
                ),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Montant (\$)", suffixText: "\$"),
                  validator: (val) => (val == null || val.isEmpty) ? "Requis" : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final double amount = double.parse(amountController.text);
                final String phone = normalizePhoneNumber(phoneController.text.trim());
                Navigator.pop(dialogContext);
                _handleSendRequest(pageContext, phone, amount);
              }
            },
            child: const Text("ENVOYER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- LOGIQUE ACTIONS ROBUSTE ---

  Future<void> _handleVerifyAndSend(BuildContext pageContext, String phone, double amount) async {
    BuildContext? loadingDialogContext;
    
    showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder: (c) {
        loadingDialogContext = c;
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final String? recipientName = await pageContext.read<WalletProvider>().getUserNameByPhone(phone);
      
      if (loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
        Navigator.pop(loadingDialogContext!);
      }

      if (!mounted) return;

      if (recipientName != null) {
        _confirmTransfer(pageContext, phone, recipientName, amount);
      } else {
        _showError(pageContext, "Utilisateur non trouvé.");
      }
    } catch (e) {
      if (loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
        Navigator.pop(loadingDialogContext!);
      }
      if (mounted) _showError(pageContext, "Erreur de connexion.");
    }
  }

  Future<void> _handleSendRequest(BuildContext pageContext, String phone, double amount) async {
    BuildContext? loadingDialogContext;
    
    showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder: (c) {
        loadingDialogContext = c;
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final provider = pageContext.read<WalletProvider>();
      final String? recipientName = await provider.getUserNameByPhone(phone);
      
      if (loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
        Navigator.pop(loadingDialogContext!);
      }

      if (!mounted) return;

      if (recipientName != null) {
        await provider.createPaymentRequest(receiverPhone: phone, amount: amount);
        if (mounted) {
          ScaffoldMessenger.of(pageContext).showSnackBar(
            SnackBar(content: Text("Demande envoyée à $recipientName"), backgroundColor: Colors.blue.shade800),
          );
        }
      } else {
        _showError(pageContext, "Numéro inconnu.");
      }
    } catch (e) {
      if (loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
        Navigator.pop(loadingDialogContext!);
      }
      if (mounted) _showError(pageContext, "Erreur lors de l'envoi.");
    }
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red.shade700));
  }

  void _confirmTransfer(BuildContext pageContext, String phone, String recipientName, double amount) {
    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Confirmer l'envoi"),
        content: Text("Envoyer $amount \$ à ${recipientName.toUpperCase()} ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("MODIFIER")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              BuildContext? loadingDialogContext;
              showDialog(
                context: pageContext,
                barrierDismissible: false,
                builder: (c) {
                  loadingDialogContext = c;
                  return const Center(child: CircularProgressIndicator());
                },
              );
              
              try {
                await pageContext.read<WalletProvider>().sendCreditsToUser(receiverPhone: phone, amount: amount);
                if (mounted && loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
                  Navigator.pop(loadingDialogContext!);
                  ScaffoldMessenger.of(pageContext).showSnackBar(const SnackBar(content: Text("Transfert réussi !"), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted && loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
                  Navigator.pop(loadingDialogContext!);
                  _showError(pageContext, "Erreur lors du transfert.");
                }
              }
            },
            child: const Text("CONFIRMER"),
          ),
        ],
      ),
    );
  }
}