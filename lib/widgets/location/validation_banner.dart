import 'package:flutter/material.dart';
import '../../models/contract_model.dart';

class ValidationBanner extends StatelessWidget {
  final ContractModel contrat;
  final VoidCallback onConfirm;
  final VoidCallback onContact;

  const ValidationBanner({
    super.key,
    required this.contrat,
    required this.onConfirm,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    // Sécurité : au cas où le nom du bailleur ne serait pas encore chargé
    final String affichageBailleur = (contrat.bailleurNom != null && contrat.bailleurNom!.isNotEmpty)
        ? contrat.bailleurNom!
        : "votre bailleur";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade900,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user, color: Colors.white),
              SizedBox(width: 10),
              Text(
                "Contrat trouvé !",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Le bailleur $affichageBailleur a enregistré votre contrat avec un loyer de ${contrat.loyerMensuel}\$. Est-ce exact ?",
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onConfirm,
                  child: const Text("OUI, JE CONFIRME", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton( // Changé en OutlinedButton pour mieux contraster avec le vert
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onContact,
                  child: const Text("NON, SIGNALER", style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}