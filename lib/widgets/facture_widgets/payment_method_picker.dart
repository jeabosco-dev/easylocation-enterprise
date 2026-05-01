import 'package:flutter/material.dart';

class PaymentMethodPicker extends StatelessWidget {
  final Function(String) onMethodSelected;

  const PaymentMethodPicker({super.key, required this.onMethodSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Petite barre de drag pour le design
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text("Mode de règlement du complément", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 24),
          
          _buildOption(
            icon: Icons.credit_card,
            color: Colors.blue,
            title: "MaxiCash (Paiement en ligne)",
            subtitle: "Cartes bancaires, Visa, Mobile Money - Instantané",
            onTap: () => onMethodSelected("Maxicash"), // Correspond à votre logique de FacturePage
          ),
          const SizedBox(height: 12),
          
          _buildOption(
            icon: Icons.phone_android,
            color: Colors.green,
            title: "Mobile Money Direct",
            subtitle: "Transfert Manuel - Vérification (5-30 min)",
            onTap: () => onMethodSelected("Manuel"), // Correspond à votre logique de FacturePage
          ),
          const SizedBox(height: 12),
          
          _buildOption(
            icon: Icons.payments_outlined,
            color: Colors.orange,
            title: "Paiement Cash",
            subtitle: "Validation physique à notre bureau",
            onTap: () => onMethodSelected("Cash"), // Correspond à votre logique de FacturePage
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon, 
    required Color color, 
    required String title, 
    required String subtitle, 
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: Colors.grey.shade200)
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1), 
              child: Icon(icon, color: color, size: 22)
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                ]
              )
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}