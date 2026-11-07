// lib/widgets/wallet/wallet_balance_card.dart

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
    // Calcul des sous-totaux pour chaque grand groupe
    final double totalRetirable = wallet.mainBalance + wallet.commissionBalance;
    final double totalNonRetirable = wallet.bonusBalance + wallet.cashbackBalance;

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
          // Solde Total Global
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

          // --- BLOC 1 : POCHES RÉTIRABLES (Total + Détail) ---
          _buildCategoryHeaderWithTotal(
            title: "Poches Rétirables", 
            totalAmount: totalRetirable, 
            color: Colors.green.shade800, 
            icon: Icons.lock_open_rounded,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceItem("Principale", wallet.mainBalance, Colors.blue.shade900),
              _buildBalanceItem("Commissions", wallet.commissionBalance, Colors.purple.shade700),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 0.5, color: Colors.black12),
          const SizedBox(height: 15),

          // --- BLOC 2 : POCHES NON RÉTIRABLES / AVANTAGES (Total + Détail) ---
          _buildCategoryHeaderWithTotal(
            title: "Poches Non Rétirables (Avantages)", 
            totalAmount: totalNonRetirable, 
            color: Colors.orange.shade800, 
            icon: Icons.lock_rounded,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceItem("Bonus", wallet.bonusBalance, Colors.orange.shade800),
              _buildBalanceItem("Cashback", wallet.cashbackBalance, Colors.green.shade700),
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

  // En-tête de catégorie sécurisé avec Expanded pour éviter le débordement (Overflow)
  Widget _buildCategoryHeaderWithTotal({
    required String title,
    required double totalAmount,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "Total : ${totalAmount.toStringAsFixed(2)} \$",
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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