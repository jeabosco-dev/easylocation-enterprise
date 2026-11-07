// lib/widgets/wallet/withdraw_source_dialog.dart

import 'package:flutter/material.dart';
import '../../models/wallet_model.dart';
import 'withdraw_dialog.dart';

class WithdrawSourceDialog extends StatelessWidget {
  final WalletModel wallet;

  const WithdrawSourceDialog({
    super.key,
    required this.wallet,
  });

  @override
  Widget build(BuildContext context) {
    // Conditions de sécurité pour la sélection des sources
    final bool canSelectMain = wallet.mainBalance > 0;
    final bool canSelectCommission = wallet.commissionBalance > 0;
    final bool canSelectBoth = (wallet.mainBalance + wallet.commissionBalance) > 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Option de Retrait"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Choisissez la source des fonds à retirer :", style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 15),
          
          // Option 1 : Balance Principale
          ListTile(
            enabled: canSelectMain,
            leading: Icon(
              Icons.account_balance_wallet, 
              color: canSelectMain ? Colors.blue : Colors.grey
            ),
            title: Text(
              "Balance Principale", 
              style: TextStyle(color: canSelectMain ? Colors.black87 : Colors.grey)
            ),
            subtitle: Text("${wallet.mainBalance.toStringAsFixed(2)} \$"),
            onTap: canSelectMain ? () {
              Navigator.pop(context); // Ferme la boîte de choix
              _openWithdrawDialog(context, wallet, source: 'main');
            } : null,
          ),
          
          // Option 2 : Commissions
          ListTile(
            enabled: canSelectCommission,
            leading: Icon(
              Icons.card_giftcard, 
              color: canSelectCommission ? Colors.purple : Colors.grey
            ),
            title: Text(
              "Commissions", 
              style: TextStyle(color: canSelectCommission ? Colors.black87 : Colors.grey)
            ),
            subtitle: Text("${wallet.commissionBalance.toStringAsFixed(2)} \$"),
            onTap: canSelectCommission ? () {
              Navigator.pop(context);
              _openWithdrawDialog(context, wallet, source: 'commission');
            } : null,
          ),

          // Option 3 : Les deux (Total Rétirable)
          ListTile(
            enabled: canSelectBoth,
            leading: Icon(
              Icons.all_inclusive, 
              color: canSelectBoth ? Colors.green : Colors.grey
            ),
            title: Text(
              "Les deux (Total Rétirable)", 
              style: TextStyle(color: canSelectBoth ? Colors.black87 : Colors.grey)
            ),
            subtitle: Text("${(wallet.mainBalance + wallet.commissionBalance).toStringAsFixed(2)} \$"),
            onTap: canSelectBoth ? () {
              Navigator.pop(context);
              _openWithdrawDialog(context, wallet, source: 'both');
            } : null,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("ANNULER"),
        ),
      ],
    );
  }

  void _openWithdrawDialog(BuildContext context, WalletModel wallet, {required String source}) {
    showDialog(
      context: context,
      builder: (context) => WithdrawDialog(
        wallet: wallet,
        source: source, // ✅ Transmet bien la source choisie ('main', 'commission' ou 'both') au dialogue de retrait
      ),
    );
  }
}