import 'package:flutter/material.dart';
import '../../models/contract_model.dart';
import '../../utils/date_helper.dart';

class TenantCard extends StatelessWidget {
  final ContractModel contrat;
  final VoidCallback onSettingsPressed;
  final VoidCallback onPdfPressed;
  final VoidCallback onHistoryPressed;
  final VoidCallback onEditDatePressed; 
  final VoidCallback onPayPressed;
  final VoidCallback onWhatsAppPressed;
  final VoidCallback onClosePressed;

  const TenantCard({
    super.key,
    required this.contrat,
    required this.onSettingsPressed,
    required this.onPdfPressed,
    required this.onHistoryPressed,
    required this.onEditDatePressed,
    required this.onPayPressed,
    required this.onWhatsAppPressed,
    required this.onClosePressed,
  });

  @override
  Widget build(BuildContext context) {
    // Logique métier harmonisée
    final DateTime dateEcheance = contrat.prochainPaiement;
    final bool estPaye = contrat.statutPaiement == 'paye';
    final String statutLabel = DateHelper.getStatutPaiement(dateEcheance, estPaye);
    final bool enRetard = statutLabel == "EN RETARD";
    final bool expireBientot = DateHelper.doitRelancerPublication(contrat.endDate);
    final bool enAttente = contrat.enAttenteValidation == true;

    // Calcul du jour d'échéance (ex: le 27 du mois)
    final String jourEcheance = contrat.startDate.day.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: enRetard ? 4 : 1,
      shadowColor: enRetard ? Colors.red : Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          if (expireBientot) _buildExpiryWarning(),
          ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: enRetard ? Colors.red : (enAttente ? Colors.orange : Colors.blueGrey),
              child: const Icon(Icons.person, color: Colors.white),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    "Réf: ${contrat.refMaison}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (contrat.locataireId == null || contrat.locataireId!.isEmpty)
                  _buildCustomBadge("HORS-APP", Colors.blueGrey),
              ],
            ),
            subtitle: Text(
              contrat.locataireNom.isEmpty ? "Locataire Inconnu" : contrat.locataireNom,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (enAttente)
                  _buildCustomBadge("À VALIDER", Colors.orangeAccent)
                else
                  _buildPaymentStatusChip(statutLabel),
                IconButton(
                  icon: const Icon(Icons.notifications_active_outlined, size: 20, color: Colors.blue),
                  onPressed: onSettingsPressed,
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // --- SECTION HARMONISÉE (LES 4 POINTS CLÉS) ---
                    _buildDetailRow("Prise d'effet", DateHelper.formatShortDate(contrat.startDate)),
                    
                    if (contrat.dernierNombreMoisPayes != null && contrat.dernierNombreMoisPayes! > 0)
                      _buildDetailRow(
                        "Dernière prolongation", 
                        "+${contrat.dernierNombreMoisPayes} mois",
                        valueColor: Colors.green[700]
                      ),

                    _buildDetailRow(
                      "Date d'expiration", 
                      DateHelper.formatShortDate(contrat.endDate),
                      isBoldValue: true,
                      valueColor: enRetard ? Colors.red : Colors.blue[800]
                    ),
                    
                    _buildDetailRow("Jour de l'échéance", "Chaque $jourEcheance du mois"),

                    const Divider(height: 24),
                    _buildDetailRow("Loyer mensuel", "${contrat.loyerMensuel} \$"),
                    
                    // BOUTON MODIFIER
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onEditDatePressed,
                        icon: const Icon(Icons.edit_note, size: 20),
                        label: const Text("Ajuster les dates ou le contrat"),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange[800],
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // ACTIONS (PDF & ENCAISSEMENT)
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: onPdfPressed,
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text("REÇU / BAIL"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.history, color: Colors.blue),
                              onPressed: onHistoryPressed,
                              tooltip: "Historique",
                            ),
                            const SizedBox(width: 4),
                            ElevatedButton.icon(
                              onPressed: onPayPressed,
                              icon: Icon(enAttente ? Icons.check_circle : Icons.payments, size: 18),
                              label: Text(enAttente ? "VALIDER CASH" : "ENCAISSER"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: enAttente ? Colors.green.shade700 : Colors.blue.shade900,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // WHATSAPP & CLÔTURE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: TextButton.icon(
                            onPressed: onWhatsAppPressed,
                            icon: Icon(Icons.message, color: enRetard ? Colors.red : Colors.green),
                            label: Text(
                              "RELANCER WHATSAPP",
                              style: TextStyle(color: enRetard ? Colors.red : Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onClosePressed,
                          icon: const Icon(Icons.no_meeting_room, color: Colors.red),
                          tooltip: "Clôturer le bail", // Label mis à jour
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Bail finit bientôt. Relancer la pub ?",
              style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text("OUI", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusChip(String status) {
    Color color = status == "PAYÉ" ? Colors.green : (status == "EN RETARD" ? Colors.red : Colors.orange);
    return _buildCustomBadge(status, color);
  }

  Widget _buildCustomBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBoldValue = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value, 
            style: TextStyle(
              fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w600, 
              fontSize: 13,
              color: valueColor ?? Colors.black87
            )
          ),
        ],
      ),
    );
  }
}