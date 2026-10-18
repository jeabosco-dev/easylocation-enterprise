// lib/widgets/facture_widgets/facture_footer.dart

import 'package:flutter/material.dart';
import '../../models/facture_model.dart';
import '../../utils/ui_utils.dart';

class FactureFooter extends StatelessWidget {
  final FactureModel facture;
  final String deviseSelectionnee;
  final Function(String) onDeviseChanged;

  const FactureFooter({
    super.key,
    required this.facture,
    required this.deviseSelectionnee,
    required this.onDeviseChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 25),
        _buildDeviseSelector(),
        const SizedBox(height: 30),
        _buildNoteInfo(),
      ],
    );
  }

  Widget _buildNoteInfo() {
    final bool isService = facture.propertyId == 'SERVICE';

    if (isService) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50, 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                SizedBox(width: 10),
                Text("INFO PRESTATION", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Paiement unique pour prestation de service. L'équipe d'intervention sera affectée et planifiée dès la confirmation de votre paiement.",
              style: TextStyle(fontSize: 11, color: Colors.blue.shade900, height: 1.4),
            ),
          ],
        ),
      );
    }

    double soldeBailleur = ((facture.loyer ?? 0) * (facture.nbMoisGarantie ?? 0)) - facture.commissionBailleurUSD;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
              SizedBox(width: 10),
              Text("SOLDE BAILLEUR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Avance sur Garantie Locative de \$ ${UIUtils.formatPrice(facture.commissionBailleurUSD)} enregistrée auprès du bailleur. Il vous restera à régler \$ ${UIUtils.formatPrice(soldeBailleur)} sur place lors de la remise des clés.",
            style: TextStyle(fontSize: 11, color: Colors.blue.shade900, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviseSelector() {
    return Row(
      children: [
        Expanded(child: _buildCurrencyOption("USD", "\$ USD")),
        const SizedBox(width: 10),
        Expanded(child: _buildCurrencyOption("CDF", "FC CDF")),
      ],
    );
  }

  Widget _buildCurrencyOption(String code, String label) {
    bool isSelected = deviseSelectionnee == code;
    return GestureDetector(
      onTap: () => onDeviseChanged(code),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? (code == "USD" ? const Color(0xFF0D47A1) : Colors.green.shade700) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label, 
            style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}