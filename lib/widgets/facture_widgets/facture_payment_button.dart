import 'package:flutter/material.dart';
import '../../providers/booking_timer_provider.dart';

class FacturePaymentButton extends StatelessWidget {
  final BookingTimerProvider timer;
  final bool isProcessing;
  final double netAPayerUSD;
  final VoidCallback onActionPressed;

  const FacturePaymentButton({
    super.key,
    required this.timer,
    required this.isProcessing,
    required this.netAPayerUSD,
    required this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Détermination du libellé selon le montant restant
    final bool isWalletFullPayment = netAPayerUSD <= 0;
    
    String labelBouton = isWalletFullPayment
        ? "VALIDER AVEC MON WALLET"
        : "CHOISIR MON MODE DE PAIEMENT";

    bool isButtonDisabled = timer.isExpired || isProcessing;

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          // Si c'est un paiement 100% Wallet, on met une couleur de succès (Vert)
          // Sinon le bleu standard
          backgroundColor: isButtonDisabled 
              ? Colors.grey 
              : (isWalletFullPayment ? Colors.green.shade700 : const Color(0xFF0D47A1)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isButtonDisabled ? 0 : 2,
        ),
        onPressed: isButtonDisabled ? null : onActionPressed,
        child: isProcessing
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                labelBouton,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}