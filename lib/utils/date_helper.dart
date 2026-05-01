import 'package:intl/intl.dart';

class DateHelper {
  /// ✅ AJOUT : Calcule une date future en ajoutant un nombre de mois
  /// Utilisé pour Date de Fin (Début + Garantie) et Prochain Paiement (Début + 1)
  static DateTime ajouterMois(DateTime dateDepart, int nombreMois) {
    int year = dateDepart.year;
    int month = dateDepart.month + nombreMois;

    // Gestion du dépassement d'année (ex: Décembre + 1 mois)
    while (month > 12) {
      month -= 12;
      year++;
    }
    
    // On essaie de garder le même jour, mais on gère les fins de mois (ex: 31 Janvier + 1 mois -> 28 Février)
    int day = dateDepart.day;
    int dernierJourDuMoisCible = DateTime(year, month + 1, 0).day;
    if (day > dernierJourDuMoisCible) {
      day = dernierJourDuMoisCible;
    }

    return DateTime(year, month, day);
  }

  /// Formate une date pour l'affichage (ex: 05 Avril 2026)
  static String formatShortDate(DateTime date) {
    // Note: Assure-toi d'avoir appelé initializeDateFormatting('fr_FR', null); dans ton main.dart
    return DateFormat('dd MMMM yyyy', 'fr_FR').format(date);
  }

  /// Calcule le nombre de jours restants avant une échéance
  static int joursRestants(DateTime dateEcheance) {
    final aujourdhui = DateTime.now();
    final dateRef = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
    final echeanceRef = DateTime(dateEcheance.year, dateEcheance.month, dateEcheance.day);
    
    return echeanceRef.difference(dateRef).inDays;
  }

  /// Calcule le temps restant de manière lisible
  static String tempsRestant(DateTime dateFin) {
    final jours = joursRestants(dateFin);

    if (jours < 0) return "Terminé";
    if (jours == 0) return "Aujourd'hui";
    if (jours == 1) return "Demain";
    
    if (jours < 30) {
      return "Finit dans $jours jours";
    }
    
    int mois = (jours / 30).floor();
    if (mois <= 0) return "Finit ce mois-ci";
    
    return "Finit dans $mois mois";
  }

  /// Retourne un statut de paiement basé sur la date
  static String getStatutPaiement(DateTime dateEcheance, bool estPaye) {
    if (estPaye) return "PAYÉ";
    
    final jours = joursRestants(dateEcheance);
    if (jours < 0) return "EN RETARD";
    if (jours <= 5) return "DÛ BIENTÔT";
    
    return "EN ATTENTE";
  }

  /// Alerte "Relance Immobilière" (Fin de bail)
  static bool doitRelancerPublication(DateTime dateFinBail) {
    final jours = joursRestants(dateFinBail);
    return jours <= 30 && jours >= 0;
  }
}