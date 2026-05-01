import 'package:flutter/material.dart';

class ReferralSettingsWidget extends StatelessWidget {
  final bool isActive;
  final TextEditingController referrerController;
  final TextEditingController refereeController;
  final Function(bool) onToggle;

  const ReferralSettingsWidget({
    super.key,
    required this.isActive,
    required this.referrerController,
    required this.refereeController,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "🤝 Programme de Parrainage (Win-Win)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          "Gérez les récompenses distribuées lors de l'invitation de nouveaux membres.",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Activer le parrainage"),
                  subtitle: Text(isActive 
                      ? "Le programme est actuellement ACTIF" 
                      : "Le programme est actuellement SUSPENDU"),
                  value: isActive,
                  onChanged: onToggle,
                  activeColor: Colors.blue,
                ),
                const Divider(),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    _buildSmallField(
                      referrerController, 
                      "Prime Parrain (\$)", 
                      Icons.person_add,
                    ),
                    _buildSmallField(
                      refereeController, 
                      "Prime Filleul (\$)", 
                      Icons.card_membership,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Note : Les bonus sont crédités automatiquement dans les Wallets après le premier paiement réussi du filleul.",
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallField(TextEditingController controller, String label, IconData icon) {
    return SizedBox(
      width: 250,
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}