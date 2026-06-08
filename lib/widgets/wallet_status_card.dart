// lib/widgets/wallet_status_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../models/wallet_model.dart';
import '../screens/mon_portefeuille_page.dart';

class WalletStatusCard extends StatelessWidget {
  const WalletStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final WalletModel? wallet = walletProvider.wallet;

    if (wallet == null) {
      return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    bool isBailleur = wallet.accountType == 'bailleur';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MonPortefeuillePage())),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isBailleur ? [Colors.green.shade900, Colors.green.shade700] : [Colors.blue.shade900, Colors.blue.shade700],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: (isBailleur ? Colors.green : Colors.blue).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              _buildIconContainer(),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBailleur ? "SOLDE TOTAL DISPONIBLE" : "MON PORTEFEUILLE",
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${wallet.totalAvailable.toStringAsFixed(2)} \$",
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildMiniLabel("Retirable", "${wallet.realBalance.toStringAsFixed(2)} \$", Colors.greenAccent),
                        const SizedBox(width: 15),
                        _buildMiniLabel("Bonus/Avantages", "${wallet.nonWithdrawableBalance.toStringAsFixed(2)} \$", Colors.orangeAccent),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBadge(wallet),
                  const SizedBox(height: 25),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
    );
  }

  Widget _buildMiniLabel(String title, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBadge(WalletModel wallet) {
    String badgeText;
    Color textColor;
    if (wallet.isRetirable) {
      badgeText = "RETIRABLE";
      textColor = Colors.green.shade900;
    } else if (wallet.bonusBalance > 0) {
      badgeText = "BONUS ACTIF";
      textColor = Colors.orange.shade800;
    } else {
      badgeText = "SOLDE";
      textColor = Colors.blue.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Text(badgeText, style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 10)),
    );
  }
}