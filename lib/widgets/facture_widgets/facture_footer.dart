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
        if (facture.cadeauId != null && facture.cadeauId != 'Aucun') ...[
          const SizedBox(height: 15),
          _buildCadeauBadge(),
        ],
        const SizedBox(height: 25),
        _buildDeviseSelector(),
        const SizedBox(height: 30),
        _buildNoteBailleur(),
      ],
    );
  }

  Widget _buildCadeauBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade100)),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text("Cadeau inclus : ${facture.cadeauId}", style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNoteBailleur() {
    double soldeBailleur = ((facture.loyer ?? 0) * (facture.nbMoisGarantie ?? 0)) - facture.commissionBailleurUSD;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
          const SizedBox(width: 10),
          const Text("SOLDE BAILLEUR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        Text(
          "Le propriétaire est informé de l'acompte de \$ ${UIUtils.formatPrice(facture.commissionBailleurUSD)} payé ici. Le solde de \$ ${UIUtils.formatPrice(soldeBailleur)} sera versé directement au bailleur.",
          style: TextStyle(fontSize: 11, color: Colors.blue.shade900, height: 1.4),
        ),
      ]),
    );
  }

  Widget _buildDeviseSelector() {
    return Row(children: [
      Expanded(child: _buildCurrencyOption("USD", "\$ USD")),
      const SizedBox(width: 10),
      Expanded(child: _buildCurrencyOption("CDF", "FC CDF")),
    ]);
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
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300)
        ),
        child: Center(child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
      ),
    );
  }
}