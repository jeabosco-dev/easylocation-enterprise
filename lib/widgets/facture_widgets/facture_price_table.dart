import 'package:flutter/material.dart';
import '../../models/facture_model.dart';
import '../../utils/ui_utils.dart';

class FacturePriceTable extends StatelessWidget {
  final FactureModel facture;
  final double netAPayerUSD;
  final double netAPayerCDF;
  final String deviseSelectionnee;
  final String totalAffiche;

  const FacturePriceTable({
    super.key,
    required this.facture,
    required this.netAPayerUSD,
    required this.netAPayerCDF,
    required this.deviseSelectionnee,
    required this.totalAffiche,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        children: [
          // Affichage des frais avec le pourcentage dynamique
          _buildPriceRow(
            "Frais de Service (${facture.comLocatairePercent.toStringAsFixed(0)}%)", 
            facture.commissionLocataireUSD
          ),
          
          // Affichage de l'acompte avec le pourcentage dynamique
          _buildPriceRow(
            "Acompte Garantie (${facture.comBailleurPercent.toStringAsFixed(0)}%)", 
            facture.commissionBailleurUSD
          ),

          if (facture.montantCashback > 0)
            _buildPriceRow(
              "Bonus Challenge Ville (Points)",
              -facture.montantCashback,
              customColor: Colors.green.shade700,
            ),

          if (facture.montantWallet > 0)
            _buildPriceRow(
              "Déduction Portefeuille (Wallet)",
              -facture.montantWallet,
              customColor: Colors.orange.shade700,
            ),

          _buildPriceRow(
            "NET À PAYER",
            netAPayerUSD,
            isTotal: true,
            customTotalDisplay: totalAffiche,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double prixUSD, {
    bool isTotal = false,
    String? customTotalDisplay,
    Color? customColor,
  }) {
    // Calcul automatique du montant dans la devise sélectionnée pour les lignes de détails
    // On utilise le taux appliqué stocké dans la facture
    double montantAffiche = (deviseSelectionnee == "USD") 
        ? prixUSD 
        : (prixUSD * facture.tauxApplique);

    String symbole = (deviseSelectionnee == "USD") ? "\$ " : "FC ";
    
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isTotal
            ? (deviseSelectionnee == "USD"
                ? const Color(0xFF0D47A1)
                : Colors.green.shade800)
            : Colors.transparent,
        borderRadius: isTotal
            ? const BorderRadius.vertical(bottom: Radius.circular(14))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.white : (customColor ?? Colors.black87),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 11.5 : 12.5,
            ),
          ),
          Text(
            customTotalDisplay ??
                (montantAffiche < 0
                    ? "- $symbole${UIUtils.formatPrice(montantAffiche.abs())}"
                    : "$symbole${UIUtils.formatPrice(montantAffiche)}"),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isTotal ? Colors.white : (customColor ?? Colors.black),
              fontSize: isTotal ? 18 : 14,
            ),
          )
        ],
      ),
    );
  }
}