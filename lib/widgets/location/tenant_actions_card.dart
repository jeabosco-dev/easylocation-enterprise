import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contract_provider.dart';
import '../../models/contract_model.dart';

class TenantActionsCard extends StatelessWidget {
  final ContractModel contrat;

  const TenantActionsCard({super.key, required this.contrat});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.flash_on, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Text("Actions Rapides", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            
            // Alerte si expiration proche (utilisation de joursRestantsLoyer pour la précision)
            if (contrat.joursRestantsLoyer < 10)
              Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Votre loyer expire très bientôt ! Prolongez votre bail pour rester en règle.",
                        style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                // BOUTON PROLONGER
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showProlongationDialog(context, contrat),
                    icon: const Icon(Icons.update, size: 18),
                    label: const Text("PROLONGER"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade900,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                
                // BOUTON CLÔTURER LE BAIL
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showExitDialog(context, contrat),
                    icon: const Icon(Icons.assignment_return_outlined, size: 18),
                    label: const Text("CLÔTURER"), // Texte mis à jour
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showProlongationDialog(BuildContext context, ContractModel contrat) {
    int moisSelectionnes = 1;
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Prolonger le bail"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Déclarez vos mois payés pour mettre à jour votre calendrier de location.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 15),
              Text("Loyer mensuel : ${contrat.loyerMensuel.toStringAsFixed(0)} USD", 
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              DropdownButtonFormField<int>(
                value: moisSelectionnes,
                decoration: const InputDecoration(
                  labelText: "Nombre de mois versés",
                  border: OutlineInputBorder(),
                ),
                items: [1, 2, 3, 6, 12].map((m) => DropdownMenuItem(
                  value: m, 
                  child: Text("$m mois (${(m * contrat.loyerMensuel).toStringAsFixed(0)} USD)")
                )).toList(),
                onChanged: (v) => setState(() => moisSelectionnes = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(context), 
              child: const Text("ANNULER")
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
              onPressed: isProcessing ? null : () async {
                setState(() => isProcessing = true);
                
                await context.read<ContractProvider>().declarerPaiementHorsApp(
                  contratId: contrat.id,
                  montantVerse: (moisSelectionnes * contrat.loyerMensuel).toDouble(),
                  modePaiement: "Cash / Direct",
                  datePaiement: DateTime.now(),
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Bail prolongé avec succès !"), backgroundColor: Colors.green),
                  );
                }
              },
              child: isProcessing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("VALIDER"),
            )
          ],
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context, ContractModel contrat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clôturer le bail"),
        content: const Text(
          "Voulez-vous signaler la fin de votre occupation ? "
          "Cette action informera le bailleur de votre intention de libérer le logement."
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<ContractProvider>().demanderSortie(contrat.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Demande de clôture envoyée.")),
                );
              }
            },
            child: const Text("CONFIRMER LA CLÔTURE"),
          )
        ],
      ),
    );
  }
}