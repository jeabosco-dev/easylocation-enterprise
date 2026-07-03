// lib/utils/ui_utils.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'financial_utils.dart'; // Import nécessaire

class UIUtils {
  /// Affiche un message flash (Succès ou Erreur)
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  /// Affiche un dialogue de succès après une action majeure
  static void showSuccessDialog(BuildContext context, {required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("COMPRIS", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Formate un montant en int (cents) pour l'affichage (ex: 2376 -> "23,76")
  static String formatCents(int cents) {
    return formatPrice(FinancialHelper.fromCents(cents));
  }

  /// Formate un nombre en prix avec 2 décimales par défaut
  static String formatPrice(num value, {int decimalDigits = 2}) {
    final formatter = NumberFormat.currency(
      locale: 'fr_FR', 
      symbol: '', 
      decimalDigits: decimalDigits
    );
    return formatter.format(value).trim();
  }
}