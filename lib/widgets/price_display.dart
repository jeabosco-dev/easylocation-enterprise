import 'package:flutter/material.dart';

class PriceDisplay extends StatelessWidget {
  final double prixNormal;
  final double prixPromo;

  const PriceDisplay({
    super.key,
    required this.prixNormal,
    required this.prixPromo,
  });

  @override
  Widget build(BuildContext context) {
    // Calcul de l'économie
    final double economie = prixNormal - prixPromo;
    final bool aUnePromo = prixPromo < prixNormal && prixPromo > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (aUnePromo)
          Text(
            "${prixNormal.toStringAsFixed(0)} \$",
            style: const TextStyle(
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
              fontSize: 14,
            ),
          ),
        
        Text(
          prixPromo <= 0 ? "Gratuit" : "${prixPromo.toStringAsFixed(0)} \$",
          style: TextStyle(
            color: aUnePromo ? Colors.deepPurple : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),

        if (aUnePromo)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "Économie : ${economie.toStringAsFixed(0)} \$",
                style: const TextStyle(
                  color: Colors.green, 
                  fontSize: 10, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),
      ],
    );
  }
}