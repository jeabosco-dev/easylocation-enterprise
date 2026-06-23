import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/promotion_model.dart';
import '../../models/facture_model.dart';
import '../../models/user_model.dart'; // Import corrigé
import '../../services/config_service.dart';
import '../../services/promotion_validation_service.dart';
import '../../utils/ui_utils.dart';

class FacturePromoWidget extends StatefulWidget {
  final double totalBase;
  final FactureModel facture;
  final UserModel utilisateur; // Type corrigé
  final Function(double newTotal, PromotionModel? promo) onPromoApplied;

  const FacturePromoWidget({
    super.key,
    required this.totalBase,
    required this.facture,
    required this.utilisateur,
    required this.onPromoApplied,
  });

  @override
  State<FacturePromoWidget> createState() => _FacturePromoWidgetState();
}

class _FacturePromoWidgetState extends State<FacturePromoWidget> {
  final TextEditingController _promoController = TextEditingController();
  PromotionModel? _appliedPromo;
  bool _isValidating = false;

  void _applyPromo() async {
    if (_promoController.text.isEmpty) return;

    setState(() => _isValidating = true);
    
    // 1. Récupération simple de la promo depuis le service config
    final config = context.read<ConfigService>();
    final promo = await config.checkSpecificPromo(_promoController.text);

    if (promo != null) {
      // 2. Validation métier déléguée au service dédié
      final validation = PromotionValidationService.verifierPromotion(
        promotion: promo,
        facture: widget.facture,
        utilisateur: widget.utilisateur,
      );

      if (validation.estValide) {
        // 3. Calcul de la remise via la méthode du modèle
        double reduction = promo.calculerRemise(widget.totalBase);
        reduction = reduction > widget.totalBase ? widget.totalBase : reduction;

        setState(() => _appliedPromo = promo);
        widget.onPromoApplied(widget.totalBase - reduction, promo);
        UIUtils.showSnackBar(context, "Code promo appliqué avec succès !");
      } else {
        // Affichage du message spécifique renvoyé par la validation métier
        UIUtils.showSnackBar(context, validation.message, isError: true);
      }
    } else {
      UIUtils.showSnackBar(context, "Code promo inexistant.", isError: true);
    }
    
    setState(() => _isValidating = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_appliedPromo != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Code ${_appliedPromo!.code} appliqué",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() => _appliedPromo = null);
                widget.onPromoApplied(widget.totalBase, null);
              },
            )
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: TextField(
              controller: _promoController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: "Code promo",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isValidating ? null : _applyPromo,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E5D8F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isValidating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Appliquer"),
          ),
        ),
      ],
    );
  }
}