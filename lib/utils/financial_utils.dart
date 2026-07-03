// lib/utils/financial_utils.dart

class FinancialHelper {
  /// Convertit un montant double (ex: 23.76) en int représentant les cents (ex: 2376)
  /// À utiliser lors de la réception de données externes ou saisies utilisateur.
  static int toCents(double amount) => (amount * 100).round();

  /// Convertit les cents (ex: 2376) en double (ex: 23.76) 
  /// À utiliser uniquement juste avant l'affichage dans l'UI.
  static double fromCents(int cents) => cents / 100;
  
  /// Exemple de calcul sécurisé : Addition
  static int add(int cents1, int cents2) => cents1 + cents2;
  
  /// Exemple de calcul sécurisé : Soustraction
  static int subtract(int cents1, int cents2) => cents1 - cents2;
}