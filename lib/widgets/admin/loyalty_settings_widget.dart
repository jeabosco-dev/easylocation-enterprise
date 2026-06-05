import 'package:flutter/material.dart';

class LoyaltySettingsWidget extends StatelessWidget {
  final bool isActive;
  final TextEditingController locataireController;
  final TextEditingController bailleurController;
  final Function(bool) onToggle;

  const LoyaltySettingsWidget({
    super.key,
    required this.isActive,
    required this.locataireController,
    required this.bailleurController,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "💎 Programme de Fidélité (EasyCredit)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          "Récompensez les utilisateurs à chaque transaction validée (Rented).",
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
                  title: const Text("Activer le système de points"),
                  subtitle: Text(
                    isActive 
                      ? "Le programme est ACTIF" 
                      : "Le programme est DÉSACTIVÉ",
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  value: isActive,
                  onChanged: onToggle,
                ),
                const Divider(),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    _buildInternalField(
                      locataireController,
                      "Cashback Locataire (% sur sa part)",
                      Icons.stars,
                      300,
                    ),
                    _buildInternalField(
                      bailleurController,
                      "Cashback Bailleur (% sur sa part)",
                      Icons.account_balance_wallet,
                      300,
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 15),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Note : Ces points (EasyCredit) sont non-retirables et seront déduits des frais lors de la prochaine transaction.",
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            color: Colors.orange,
                          ),
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

  Widget _buildInternalField(
    TextEditingController controller,
    String label,
    IconData icon,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixText: "%",
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }
}