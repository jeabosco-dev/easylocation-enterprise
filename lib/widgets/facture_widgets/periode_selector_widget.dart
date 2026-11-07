// lib/widgets/facture_widgets/periode_selector_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PeriodeSelectorWidget extends StatelessWidget {
  final String? currentPeriode;
  final ValueChanged<String> onPeriodeChanged;

  const PeriodeSelectorWidget({
    super.key,
    required this.currentPeriode,
    required this.onPeriodeChanged,
  });

  /// Méthode statique utilitaire pour sécuriser et obtenir une période valide à tout moment
  static String getSecuredPeriode(String? periodeInput) {
    if (periodeInput != null && periodeInput.trim().isNotEmpty) {
      return periodeInput;
    }
    // Par défaut : Mois en cours formaté (ex: Novembre 2026) avec prise en charge de la locale française
    return DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final String displayPeriode = getSecuredPeriode(currentPeriode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 20, color: Colors.blue.shade800),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Période concernée", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(displayPeriode, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                ],
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () async {
              // Optionnel : Permettre de changer la période à la volée si besoin
              // Pour l'instant, on sécurise ou propose un choix simple
              onPeriodeChanged(displayPeriode);
            },
            icon: const Icon(Icons.edit, size: 14),
            label: const Text("Modifier", style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
          ),
        ],
      ),
    );
  }
}