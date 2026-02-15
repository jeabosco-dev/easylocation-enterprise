import 'package:flutter/material.dart';
import 'package:easylocation_mvp/models/property_model.dart';

class SectionAdressePropriete extends StatelessWidget {
  final Property property;
  const SectionAdressePropriete({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne 1 : Titre et Ville/Province alignés
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.location_on, size: 16, color: primary),
                const SizedBox(width: 4),
                Text("Localisation", 
                  style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 13)),
              ]),
              Text("${property.ville}, ${property.province}", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const Divider(height: 16),
          
          // Ligne 2 : Commune et Quartier condensés
          Text("Commune : ${property.commune} • Quartier : ${property.quartier}", 
            style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          
          // Ligne 3 : Avenue et N° Masqués
          Row(children: [
            Text("Avenue : •••••, N° : •••", 
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(width: 6),
            Icon(Icons.lock_rounded, size: 12, color: Colors.grey.shade400),
          ]),
          const SizedBox(height: 8),
          
          // Ligne 4 : Information de sécurité discrète
          Text(
            "🔒 Avenue et N° masqués par sécurité", 
            style: TextStyle(
              fontSize: 10, 
              color: Colors.blueGrey.shade600, 
              fontWeight: FontWeight.w500, 
              fontStyle: FontStyle.italic
            ),
          ),
        ],
      ),
    );
  }
}
