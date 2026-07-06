import 'package:flutter/material.dart';

class UpsellTabWidget extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final VoidCallback onAddService;
  final Function(int) onRemoveService;
  final Function(int, bool) onTogglePercentage;

  final List<String> famillesDisponibles = [
    'MAIN',
    'BOOST',
    'ALERTE',
    'ENTRETIEN',
    'DEMENAGEMENT',
    'PACK_DEMENAGEMENT',
  ];

  UpsellTabWidget({
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
              const Expanded(
                child: Text(
                  "Catalogue des services optionnels (Upsell)",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: onAddService,
                icon: const Icon(Icons.add),
                label: const Text("Ajouter un Service"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (services.isEmpty)
            const Center(
              child: Text("Aucun service configuré."),
            )
          else
            ...services.asMap().entries.map((entry) {
              final index = entry.key;
              final ctrl = entry.value;

              final nomCtrl =
                  (ctrl['nom'] as TextEditingController?) ??
                      TextEditingController();

              final prixCtrl =
                  (ctrl['prix'] as TextEditingController?) ??
                      TextEditingController();

              final familleCtrl =
                  (ctrl['famille'] as TextEditingController?) ??
                      TextEditingController();

              final descCtrl =
                  (ctrl['description'] as TextEditingController?) ??
                      TextEditingController();

              ctrl['nom'] ??= nomCtrl;
              ctrl['prix'] ??= prixCtrl;
              ctrl['famille'] ??= familleCtrl;
              ctrl['description'] ??= descCtrl;

              final bool isPercentage =
                  ctrl['is_percentage'] ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildAdaptiveField(
                        nomCtrl,
                        "Nom du service",
                        Icons.label,
                        250,
                      ),

                      _buildAdaptiveField(
                        prixCtrl,
                        "Prix ou %",
                        Icons.attach_money,
                        120,
                        isNumeric: true,
                      ),

                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: famillesDisponibles.contains(familleCtrl.text)
                              ? familleCtrl.text
                              : 'ENTRETIEN',
                          decoration: const InputDecoration(
                            labelText: "Famille",
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                          items: famillesDisponibles
                              .map(
                                (f) => DropdownMenuItem<String>(
                                  value: f,
                                  child: Text(
                                    f,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              familleCtrl.text = value;
                            }
                          },
                        ),
                      ),

                      _buildAdaptiveField(
                        descCtrl,
                        "Description",
                        Icons.description,
                        350,
                      ),

                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Est-ce un % ?",
                            style: TextStyle(fontSize: 12),
                          ),
                          Switch(
                            value: isPercentage,
                            onChanged: (v) =>
                                onTogglePercentage(index, v),
                          ),
                        ],
                      ),

                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                        ),
                        onPressed: () => onRemoveService(index),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildAdaptiveField(
    TextEditingController controller,
    String label,
    IconData icon,
    double maxWidth, {
    bool isNumeric = false,
  }) {
    return SizedBox(
      width: maxWidth,
      child: TextFormField(
        controller: controller,
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
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