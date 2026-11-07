// lib/widgets/wallet/withdraw_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/wallet_model.dart';
import '../../utils/phone_utils.dart';
import '../../services/config_service.dart';
import '../../providers/wallet_provider.dart';

class WithdrawDialog extends StatefulWidget {
  final WalletModel wallet;
  final String source; // 'main', 'commission', 'both'

  const WithdrawDialog({
    super.key,
    required this.wallet,
    this.source = 'main',
  });

  @override
  State<WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<WithdrawDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  
  String _selectedMethod = 'Mobile Money';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  double get _availableSourceBalance {
    switch (widget.source) {
      case 'commission':
        return widget.wallet.commissionBalance;
      case 'both':
        return widget.wallet.mainBalance + widget.wallet.commissionBalance;
      case 'main':
      default:
        return widget.wallet.mainBalance;
    }
  }

  String get _sourceTitle {
    switch (widget.source) {
      case 'commission':
        return "Commissions";
      case 'both':
        return "Total Rétirable (Solde + Commissions)";
      case 'main':
      default:
        return "Balance Principale";
    }
  }

  int _toCents(double amount) {
    return (amount * 100).round();
  }

  double _calculerFraisService(ConfigService configService) {
    final double mainBalance = widget.wallet.mainBalance;
    final double reliquatDisponible = widget.wallet.reliquatRemboursement;

    // 1. Source Commissions seule : Toujours exonérée
    if (widget.source == 'commission') {
      return 0.0;
    }

    double mainAmountDrawn = 0.0;
    double montantDemande = _amountController.text.isEmpty
        ? _availableSourceBalance
        : (double.tryParse(_amountController.text) ?? 0.0);

    // 2. Traitement du solde principal utilisé (directement ou via 'both')
    if (widget.source == 'main') {
      mainAmountDrawn = montantDemande;
    } else if (widget.source == 'both') {
      if (mainBalance <= 0) {
        mainAmountDrawn = 0.0;
      } else if (mainBalance >= montantDemande) {
        mainAmountDrawn = montantDemande;
      } else {
        mainAmountDrawn = mainBalance;
      }
    }

    // Si aucune somme de la balance principale n'est touchée, pas de frais
    if (mainAmountDrawn <= 0) {
      return 0.0;
    }

    // 3. Vérification des exonérations de reliquat/réinvestissement sur la part 'main'
    if (reliquatDisponible > 0 && widget.wallet.hasReinvested) {
      final int mainCentimes = _toCents(mainAmountDrawn);
      final int reliquatCentimes = _toCents(reliquatDisponible);

      if (mainCentimes > 0 && mainCentimes <= reliquatCentimes) {
        return 0.0;
      }
    }

    return configService.refundServiceFee;
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final amount = double.parse(_amountController.text);
      final configService = Provider.of<ConfigService>(context, listen: false);
      final double fraisService = _calculerFraisService(configService);
      
      String infoCompte;
      if (_selectedMethod == 'Retrait au bureau') {
        infoCompte = 'RETRAIT_BUREAU';
      } else {
        infoCompte = normalizePhoneNumber(_accountController.text.trim());
      }
          
      try {
        await Provider.of<WalletProvider>(context, listen: false).requestWithdrawal(
          amount: amount,
          fee: fraisService,
          accountInfo: infoCompte,
          source: widget.source,
        );
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Demande de retrait envoyée avec succès !"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur : ${e.toString()}"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configService = Provider.of<ConfigService>(context);
    
    final double fraisService = _calculerFraisService(configService);
    final double soldeDisponible = _availableSourceBalance;
    final double maxRetirable = (soldeDisponible - fraisService) > 0 ? (soldeDisponible - fraisService) : 0;

    return AlertDialog(
      title: Text("Retrait : $_sourceTitle"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Affichage stylisé des soldes ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _buildBalanceRow("Source :", _sourceTitle, Colors.blue.shade900),
                    const Divider(),
                    _buildBalanceRow("Solde disponible :", "${soldeDisponible.toStringAsFixed(2)} \$", Colors.black87),
                    const Divider(),
                    _buildBalanceRow(
                      "Frais service :", 
                      fraisService == 0.0 ? "0.00 \$ (Exonéré)" : "- ${fraisService.toStringAsFixed(2)} \$", 
                      fraisService == 0.0 ? Colors.green.shade700 : Colors.red.shade700
                    ),
                    const Divider(),
                    _buildBalanceRow("Solde retirable :", "${maxRetirable.toStringAsFixed(2)} \$", Colors.green.shade700),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: _selectedMethod,
                decoration: const InputDecoration(labelText: "Méthode de retrait", border: OutlineInputBorder()),
                items: ['Mobile Money', 'Retrait au bureau'].map((String val) {
                  return DropdownMenuItem(value: val, child: Text(val));
                }).toList(),
                onChanged: (val) => setState(() => _selectedMethod = val!),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                decoration: const InputDecoration(labelText: "Montant", prefixIcon: Icon(Icons.attach_money)),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  if (amount == null || amount <= 0) return "Montant invalide";
                  if (amount > maxRetirable) return "Maximum autorisé : ${maxRetirable.toStringAsFixed(2)} \$";
                  return null;
                },
              ),

              if (_selectedMethod == 'Mobile Money')
                const SizedBox(height: 15),

              if (_selectedMethod == 'Mobile Money')
                TextFormField(
                  controller: _accountController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "N° Mobile Money",
                    helperText: "Format sans le 0 initial (ex: 97xxxxxxx)",
                    prefixIcon: Icon(Icons.phone_android),
                    prefixText: "+243 ",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.length < 8) ? "Numéro invalide" : null,
                ),

              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Text(
                  _selectedMethod == 'Mobile Money'
                      ? "⚠️ Frais d'envoi à votre charge. Votre nom doit correspondre au compte."
                      : "✅ Vous pourrez passer récupérer votre argent en espèces à nos bureaux munis d'une pièce d'identité.",
                  style: TextStyle(
                    fontSize: 12, 
                    color: _selectedMethod == 'Mobile Money' ? Colors.orange.shade800 : Colors.green.shade700, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context), 
          child: const Text("Annuler")
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
          child: _isLoading 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("Confirmer"),
        ),
      ],
    );
  }

  Widget _buildBalanceRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label, 
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Text(
              value, 
              style: TextStyle(fontWeight: FontWeight.bold, color: valueColor, fontSize: 13),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}