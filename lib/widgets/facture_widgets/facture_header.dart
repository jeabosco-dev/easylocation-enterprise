import 'package:flutter/material.dart';

/// Un widget réutilisable pour l'en-tête des documents de facturation
/// de EasyLocation Enterprise.
class FactureHeader extends StatelessWidget {
  const FactureHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: const [
            Text(
              "EasyLocation Enterprise",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFF0D47A1), // Bleu officiel EasyLocation
              ),
            ),
            Text(
              "Gestion immobilière & Services",
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const Icon(
          Icons.verified_user_rounded,
          size: 40,
          color: Color(0xFF0D47A1),
        ),
      ],
    );
  }
}