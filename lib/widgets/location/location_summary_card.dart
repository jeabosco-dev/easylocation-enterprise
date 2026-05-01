import 'package:flutter/material.dart';
import '../../models/contract_model.dart';
import '../../utils/date_helper.dart';

class LocationSummaryCard extends StatelessWidget {
  final ContractModel contrat;

  const LocationSummaryCard({super.key, required this.contrat});

  @override
  Widget build(BuildContext context) {
    // On récupère le statut via le helper
    final bool estPaye = contrat.statutPaiement == 'paye';
    final String statutLabel = DateHelper.getStatutPaiement(contrat.prochainPaiement, estPaye);

    Color statusColor;
    switch (statutLabel) {
      case "PAYÉ":
        statusColor = Colors.green;
        break;
      case "EN RETARD":
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Column(
        children: [
          // Header de la carte avec le statut
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 12, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  statutLabel,
                  style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
                ),
                const Spacer(),
                if (contrat.typeContrat == 'journal_perso')
                  _badge("JOURNAL PERSO", Colors.blueGrey)
                else if (statutLabel != "PAYÉ")
                  _badge("Action requise", Colors.red),
              ],
            ),
          ),
          
          // Corps de la carte
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // INFOS GÉNÉRALES
                _row("Référence Maison", contrat.refMaison, isPrimary: true),
                _row("Bailleur", contrat.nomBailleur ?? "Propriétaire"),
                _row("Loyer Mensuel", "${contrat.loyerMensuel.toStringAsFixed(0)} \$"),
                
                const Divider(height: 30),
                
                // PILIER DES DATES (Miroir de la TenantCard)
                _row(
                  "Prise d'effet", 
                  DateHelper.formatShortDate(contrat.startDate),
                  icon: Icons.calendar_today_outlined
                ),
                
                _row(
                  "Loyer valable jusqu'au", 
                  DateHelper.formatShortDate(contrat.prochainPaiement),
                  valueColor: statusColor,
                  icon: Icons.event_available
                ),

                _row(
                  "Fin théorique du bail", 
                  DateHelper.formatShortDate(contrat.endDate),
                  icon: Icons.event_busy
                ),
                
                // INDICATEUR DE DURÉE
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Durée totale du contrat", style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      Text(contrat.dureeMoyenne, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _row(String label, String value, {bool isPrimary = false, Color? valueColor, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey[400]),
            const SizedBox(width: 8),
          ],
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600, 
                fontSize: 13,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}