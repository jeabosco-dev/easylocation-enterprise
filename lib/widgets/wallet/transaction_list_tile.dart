import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';

class TransactionListTile extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionListTile({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPositive = transaction.isPositive;
    final String dateStr = DateFormat('dd MMM yyyy, HH:mm').format(transaction.date);

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
        dateStr,
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