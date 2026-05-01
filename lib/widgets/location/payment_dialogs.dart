import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contract_model.dart';
import '../../providers/contract_provider.dart';

class PaymentDialogs {
  static void showDeclarerPaiement(BuildContext context, ContractModel contrat) {
    final TextEditingController moisController = TextEditingController(text: "1");
    final TextEditingController refController = TextEditingController();
    
    // On utilise un StatefulBuilder pour gérer l'état local (loading et calcul du prix)
    showDialog(
      context: context,
      barrierDismissible: false, // Empêche de fermer en cliquant à côté pendant l'envoi
      builder: (context) {
        bool isLoading = false;
        double montantTotal = contrat.loyerMensuel;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text("Enregistrer un paiement"),
              content: SingleChildScrollView( // Sécurité pour le clavier
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      contrat.typeContrat == 'journal_perso'
                          ? "Ce paiement sera ajouté à votre journal. Pratique pour garder une trace de vos reçus papier."
                          : "Votre bailleur recevra une notification pour confirmer la réception.",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    
                    // Champ Nombre de mois avec calcul dynamique
                    TextField(
                      controller: moisController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Nombre de mois payés",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_month),
                      ),
                      onChanged: (val) {
                        setState(() {
                          int nb = int.tryParse(val) ?? 0;
                          montantTotal = nb * contrat.loyerMensuel;
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    
                    // Affichage du montant total pour éviter les erreurs
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Montant Total :", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            "${montantTotal.toStringAsFixed(0)} \$",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: refController,
                      decoration: const InputDecoration(
                        labelText: "Référence ou N° de reçu",
                        hintText: "Ex: Reçu N°45 ou Ref M-Pesa",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt_long),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    child: const Text("ANNULER")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isLoading ? null : () async {
                    int? nbMois = int.tryParse(moisController.text);
                    
                    if (nbMois != null && nbMois > 0) {
                      setState(() => isLoading = true);
                      
                      try {
                        // ✅ Appel corrigé avec le paramètre nommé contratId
                        await context.read<ContractProvider>().creerDemandePaiement(
                          contratId: contrat.id,
                          nbMois: nbMois,
                          reference: refController.text.trim(),
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Paiement enregistré avec succès."),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Veuillez saisir un nombre de mois valide.")),
                      );
                    }
                  },
                  child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("ENREGISTRER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}