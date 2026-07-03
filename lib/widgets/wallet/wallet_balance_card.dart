import 'package:flutter/material.dart';
import '../../models/wallet_model.dart';

class WalletBalanceCard extends StatelessWidget {
  final WalletModel wallet;

  const WalletBalanceCard({
    super.key,
    required this.wallet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Solde Total
          Text(
            "${wallet.totalAvailable.toStringAsFixed(2)} \$",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            wallet.accountType == 'bailleur'
                ? "Crédit Services / Pub"
                : "Solde Total Disponible",
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const Divider(height: 30, thickness: 1, color: Colors.black12),

          // Grille des sous-totaux
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceItem("Principale", wallet.mainBalance, Colors.blue.shade900),
              _buildBalanceItem("Bonus", wallet.bonusBalance, Colors.orange.shade800),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceItem("Cashback", wallet.cashbackBalance, Colors.green.shade700),
              _buildBalanceItem("Commissions", wallet.commissionBalance, Colors.purple.shade700),
            ],
          ),

          // Affichage du remboursement en attente (Locataires seulement)
          if (wallet.accountType == 'locataire' && wallet.pendingRefund > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_empty, size: 14, color: Colors.orange.shade900),
                  const SizedBox(width: 5),
                  Text(
                    "Remboursement en cours : ${wallet.pendingRefund.toStringAsFixed(2)} \$",
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          "${amount.toStringAsFixed(2)} \$",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}