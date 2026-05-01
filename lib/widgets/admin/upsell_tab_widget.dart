import 'package:flutter/material.dart';

class UpsellTabWidget extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final VoidCallback onAddService;
  final Function(int) onRemoveService;
  final Function(int, bool) onTogglePercentage;

  const UpsellTabWidget({
    super.key,
    required this.services,
    required this.onAddService,
    required this.onRemoveService,
    required this.onTogglePercentage,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Catalogue des services optionnels (Upsell)", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: onAddService, 
                icon: const Icon(Icons.add), 
                label: const Text("Ajouter un Service"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  foregroundColor: Colors.white
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          if (services.isEmpty)
            const Center(child: Text("Aucun service configuré."))
          else
            ...services.asMap().entries.map((entry) {
              int index = entry.key;
              var ctrl = entry.value;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Wrap(
                    spacing: 15, runSpacing: 15,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildInlineField(ctrl['nom'], "Nom du service", Icons.label, 250),
                      _buildInlineField(ctrl['prix'], "Prix ou %", Icons.attach_money, 120, isNumeric: true),
                      _buildInlineField(ctrl['description'], "Description", Icons.description, 350),
                      Column(
                        children: [
                          const Text("Est-ce un % ?", style: TextStyle(fontSize: 12)),
                          Switch(
                            value: ctrl['is_percentage'], 
                            onChanged: (val) => onTogglePercentage(index, val),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => onRemoveService(index),
                      )
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildInlineField(TextEditingController controller, String label, IconData icon, double width, {bool isNumeric = false}) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
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