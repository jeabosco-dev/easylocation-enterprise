// lib/widgets/wallet/transaction_list_tile.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';

class TransactionListTile extends StatelessWidget {
  final TransactionModel transaction;
  final String currentUserId; // Nécessaire pour déterminer le contexte

  const TransactionListTile({
    super.key,
    required this.transaction,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPositive = transaction.isPositive;
    final String dateStr = DateFormat('dd MMM yyyy, HH:mm').format(transaction.date);
    
    // Logique P2P : Vérifie si l'utilisateur courant est le destinataire
    final isIncoming = transaction.receiverId == currentUserId;
    
    // Texte dynamique pour le sous-titre
    String getSubtitleText() {
      // Si ce n'est pas un transfert P2P (pas de senderId/receiverId), on affiche la date
      if (transaction.senderId == null || transaction.receiverId == null) {
        return dateStr;
      }
      
      // Sinon, on affiche le mouvement P2P
      return isIncoming 
          ? "Reçu de ${transaction.senderName ?? 'Inconnu'}" 
          : "Envoyé à ${transaction.receiverName ?? 'Inconnu'}";
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isPositive ? Colors.green.shade50 : Colors.red.shade50,
        child: Icon(
          isPositive ? Icons.arrow_downward : Icons.arrow_upward,
          color: isPositive ? Colors.green : Colors.red,
          size: 20,
        ),
      ),
      title: Text(
        transaction.title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        getSubtitleText(),
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      trailing: Text(
        "${isPositive ? '+' : '-'} ${transaction.amount.toStringAsFixed(2)} \$",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isPositive ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}