import 'package:flutter/material.dart';

class WidgetDePiedDePage extends StatelessWidget {
  const WidgetDePiedDePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: theme.colorScheme.primary, // Utilisation de la couleur principale du thème
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '© 2025 EasyLocation SARLU. Tous droits réservés.',
            style: TextStyle(color: Colors.white, fontSize: 12.0),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8.0),
          const Text(
            'N° Impôt : A2301893J | N° RCCM : CD/BKV/RCCM/22-B-03012 | Id. Nat. : 22-F4300-N24678A',
            style: TextStyle(color: Colors.white, fontSize: 10.0),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4.0),
          const Text(
            'RDC',
            style: TextStyle(color: Colors.white, fontSize: 10.0),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.phone,
                color: Colors.white,
                size: 16.0,
              ),
              const SizedBox(width: 4.0),
              const Text(
                '+243 972 129 520',
                style: TextStyle(color: Colors.white, fontSize: 12.0),
              ),
              const SizedBox(width: 12.0),
              const Icon(
                Icons.email,
                color: Colors.white,
                size: 16.0,
              ),
              const SizedBox(width: 4.0),
              const Text(
                'contact@easylocationrdc.com',
                style: TextStyle(color: Colors.white, fontSize: 12.0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

