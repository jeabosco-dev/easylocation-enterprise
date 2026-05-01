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
    // Écoute du provider pour mettre à jour le solde en temps réel
    final walletProvider = context.watch<WalletProvider>();
    final WalletModel? wallet = walletProvider.wallet;

    // Si le wallet n'est pas encore chargé, on affiche un placeholder discret
    if (wallet == null) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    bool isBailleur = wallet.accountType == 'bailleur';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: () {
          // Navigation vers la page de détails avec l'historique
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MonPortefeuillePage()),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isBailleur 
                  ? [Colors.green.shade900, Colors.green.shade700] 
                  : [Colors.blue.shade900, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isBailleur ? Colors.green : Colors.blue).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Section Icône
              _buildIconContainer(),
              
              const SizedBox(width: 15),
              
              // Section Textes (Solde)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBailleur ? "REVENUS DISPONIBLES" : "MON PORTEFEUILLE",
                      style: const TextStyle(
                        color: Colors.white70, 
                        fontSize: 11, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${wallet.totalAvailable.toStringAsFixed(2)} \$",
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 24, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    if (wallet.bonusBalance > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "+ ${wallet.bonusBalance.toStringAsFixed(2)} \$ de bonus inclus",
                          style: TextStyle(
                            color: Colors.yellow.shade200.withOpacity(0.8), 
                            fontSize: 11, 
                            fontStyle: FontStyle.italic
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Badge Statut & Flèche
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBadge(isBailleur, wallet.balance, wallet.totalAvailable),
                  const SizedBox(height: 10),
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
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15), 
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24)
      ),
      child: const Icon(
        Icons.account_balance_wallet_rounded, 
        color: Colors.white, 
        size: 28
      ),
    );
  }

  Widget _buildBadge(bool isBailleur, double realBalance, double totalAvailable) {
    String badgeText;
    
    if (isBailleur) {
      badgeText = "RETIRABLE";
    } else {
      if (realBalance > 0) {
        badgeText = "PARTIEL. RETIRABLE";
      } else if (totalAvailable > 0) {
        badgeText = "POINTS CADEAUX";
      } else {
        badgeText = "PORTEFEUILLE ACTIF"; // Message positif même à 0$
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4)
        ]
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: isBailleur ? Colors.green.shade900 : Colors.blue.shade900,
          fontWeight: FontWeight.w900, 
          fontSize: 10,
        ),
      ),
    );
  }
}