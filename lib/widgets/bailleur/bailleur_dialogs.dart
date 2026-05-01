import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contract_provider.dart';
import '../../models/contract_model.dart';

class BailleurDialogs {
  
  // 1. CONFIGURATION DES RAPPELS (Initialisation avec données réelles)
  static void showSettingsDialog(BuildContext context, ContractModel contrat) {
    // ✅ Initialisation avec les données réelles de la base (via la Map notifications)
    bool pushActive = contrat.notifications?['pushActive'] ?? true; 
    bool smsActive = contrat.notifications?['smsActive'] ?? false;
    int frequence = (contrat.notifications?['frequenceJours'] ?? 2).toInt(); 

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Configuration des Rappels", 
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text("Notifications Push"),
                subtitle: const Text("Alertes gratuites dans l'app"),
                value: pushActive,
                onChanged: (val) => setState(() => pushActive = val),
              ),
              SwitchListTile(
                title: const Text("Rappels par SMS"),
                subtitle: const Text("Utile si le locataire n'a pas internet"),
                value: smsActive,
                onChanged: (val) => setState(() => smsActive = val),
              ),
              const Divider(),
              const Text("Fréquence en cas de retard", 
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: frequence,
                isExpanded: true,
                items: [1, 2, 3, 5, 7].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text("Tous les $value jours"),
                  );
                }).toList(),
                onChanged: (val) => setState(() => frequence = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("ANNULER")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
              onPressed: () async {
                final provider = context.read<ContractProvider>();
                // ✅ CORRECTIF : Ajout du paramètre rappelFinBailMois requis
                final success = await provider.updateRappels(
                  contractId: contrat.id,
                  pushEnabled: pushActive,
                  smsEnabled: smsActive,
                  frequenceJours: frequence,
                  rappelFinBailMois: (contrat.notifications?['rappelFinBailMois'] ?? 1).toInt(),
                );
                
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? "Réglages enregistrés !" : "Erreur de mise à jour")),
                  );
                }
              },
              child: const Text("ENREGISTRER", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // 2. ENREGISTREMENT D'UN PAIEMENT
  static void showPaymentDialog(BuildContext context, ContractModel contrat) {
    final TextEditingController moisController = TextEditingController(text: "1");

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.green),
            SizedBox(width: 10),
            Text("Enregistrer un paiement"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Locataire : ${contrat.locataireNom.isEmpty ? 'Inconnu' : contrat.locataireNom}"),
            const SizedBox(height: 15),
            const Text("Nombre de mois payés :", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 5),
            TextField(
              controller: moisController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: "mois",
                filled: true,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Note : Le serveur calculera automatiquement les nouvelles dates.",
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              int? nbMois = int.tryParse(moisController.text);
              if (nbMois != null && nbMois > 0) {
                final provider = context.read<ContractProvider>();
                final success = await provider.prolongerBail(contrat.id, nbMois);
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? "Paiement validé !" : "Erreur lors de l'enregistrement"),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("CONFIRMER LE PAIEMENT"),
          ),
        ],
      ),
    );
  }

  // 3. RECTIFICATION DE LA DATE D'ENTRÉE (L'oublié)
  static void showEditStartDateDialog(BuildContext context, ContractModel contrat) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: contrat.startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)), 
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: "RECTIFIER LA DATE D'ENTRÉE",
    );

    if (picked != null && picked != contrat.startDate && context.mounted) {
      final success = await context.read<ContractProvider>().updateContractStartDate(contrat.id, picked);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Date rectifiée !"), backgroundColor: Colors.green),
        );
      }
    }
  }

  // 4. CLÔTURE DU CONTRAT
  static void showCloseContractDialog(BuildContext context, ContractModel contrat) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Clôturer ce bail ?"),
        content: const Text("Cela libérera la maison dans votre inventaire. Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final provider = context.read<ContractProvider>();
              final success = await provider.cloturerBail(contrat.id, contrat.refMaison);
              if (context.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success ? "Bail clôturé et maison libérée" : "Erreur lors de la clôture"),
                  backgroundColor: success ? Colors.green : Colors.red,
                ));
              }
            },
            child: const Text("OUI, CLÔTURER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}