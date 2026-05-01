import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FormPromoPremierArrive extends StatefulWidget {
  const FormPromoPremierArrive({super.key});

  @override
  State<FormPromoPremierArrive> createState() => _FormPromoPremierArriveState();
}

class _FormPromoPremierArriveState extends State<FormPromoPremierArrive> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final TextEditingController _titreCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _valeurCtrl = TextEditingController();
  final TextEditingController _limitCtrl = TextEditingController(text: "100");

  // ✅ CONFIGURATION GÉOGRAPHIQUE
  final List<String> _villesDisponibles = ["Bukavu", "Goma", "Kinshasa", "Lubumbashi", "Kisangani"];
  List<String> _villesSelectionnees = [];

  bool _isActive = false;
  DateTimeRange? _dateRange;
  bool _isSaving = false;

  // ✅ LIBÉRATION DES RESSOURCES (Important pour éviter les erreurs de console)
  @override
  void dispose() {
    _titreCtrl.dispose();
    _descCtrl.dispose();
    _codeCtrl.dispose();
    _valeurCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String code = _codeCtrl.text.trim().toUpperCase();

    if (code.isEmpty || _dateRange == null || _villesSelectionnees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le code, les dates et AU MOINS UNE VILLE sont obligatoires"), 
          backgroundColor: Colors.orange
        )
      );
      return;
    }
    
    setState(() => _isSaving = true);
    try {
      await _firestore.collection('promotions').doc(code).set({
        'titre': _titreCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'code': code,
        'valeur': double.tryParse(_valeurCtrl.text) ?? 0.0,
        'type': 'pourcentage',
        'target': 'commission',
        'date_debut': Timestamp.fromDate(_dateRange!.start),
        'date_fin': Timestamp.fromDate(_dateRange!.end),
        'statut': _isActive ? 'actif' : 'inactif',
        'usage_limit': int.tryParse(_limitCtrl.text) ?? 100, 
        'usage_count': 0, 
        'villes': _villesSelectionnees, 
        'scope': _villesSelectionnees.length == _villesDisponibles.length ? 'national' : 'local',
        'last_updated': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offre limitée déployée avec succès !"), backgroundColor: Colors.green)
      );
      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red)
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _titreCtrl.clear();
    _descCtrl.clear();
    _codeCtrl.clear();
    _valeurCtrl.clear();
    _limitCtrl.text = "100";
    setState(() {
      _dateRange = null;
      _isActive = false;
      _villesSelectionnees = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isAllSelected = _villesSelectionnees.length == _villesDisponibles.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Configuration Offre Limitée (FOMO)", 
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                      ),
                      const Text(
                        "Ciblez précisément les villes de lancement (Goma, Bukavu, Kin...)",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const Divider(height: 40),

                      // ✅ SECTION : CIBLAGE GÉOGRAPHIQUE
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("1. Ciblage Géographique", style: TextStyle(fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                if (isAllSelected) {
                                  _villesSelectionnees = [];
                                } else {
                                  _villesSelectionnees = List.from(_villesDisponibles);
                                }
                              });
                            },
                            icon: Icon(isAllSelected ? Icons.deselect : Icons.select_all, size: 20),
                            label: Text(isAllSelected ? "Tout déselectionner" : "Tout sélectionner"),
                            style: TextButton.styleFrom(foregroundColor: Colors.blue[800]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _villesDisponibles.map((ville) {
                          final isSelected = _villesSelectionnees.contains(ville);
                          return FilterChip(
                            label: Text(ville),
                            selected: isSelected,
                            selectedColor: Colors.blue.withOpacity(0.2),
                            checkmarkColor: Colors.blue,
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) {
                                  _villesSelectionnees.add(ville);
                                } else {
                                  _villesSelectionnees.remove(ville);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 30),
                      const Text("2. Détails de l'Offre", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      
                      _buildField(_titreCtrl, "Titre de l'opération (ex: Promo Est RDC)", Icons.campaign),
                      const SizedBox(height: 20),
                      
                      Row(
                        children: [
                          Expanded(flex: 2, child: _buildField(_codeCtrl, "CODE PROMO", Icons.vpn_key)),
                          const SizedBox(width: 15),
                          Expanded(flex: 1, child: _buildField(_limitCtrl, "Places", Icons.people, isNum: true)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      _buildField(_valeurCtrl, "Remise (en % sur la commission)", Icons.percent, isNum: true),
                      const SizedBox(height: 25),
                      
                      const Text("3. Validité et Statut", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Activer l'offre immédiatement"),
                        subtitle: const Text("Rendre le code utilisable par les clients"),
                        value: _isActive,
                        activeColor: Colors.blue[800],
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      ListTile(
                        tileColor: Colors.blue.withOpacity(0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        leading: const Icon(Icons.calendar_month, color: Colors.blue),
                        title: Text(_dateRange == null 
                          ? "Définir les dates de validité" 
                          : "Valide du ${DateFormat('dd/MM').format(_dateRange!.start)} au ${DateFormat('dd/MM').format(_dateRange!.end)}"),
                        trailing: const Icon(Icons.edit, size: 18),
                        onTap: _selectDateRange,
                      ),

                      const SizedBox(height: 40),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.rocket_launch),
                          label: Text(_isSaving ? "TRAITEMENT..." : "DÉPLOYER L'OFFRE"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800], 
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final res = await showDateRangePicker(
      context: context, 
      firstDate: DateTime.now(), 
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue[800]!),
          ),
          child: child!,
        );
      },
    );
    if (res != null) setState(() => _dateRange = res);
  }

  Widget _buildField(TextEditingController c, String l, IconData i, {bool isNum = false}) {
    return TextFormField(
      controller: c,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: l, 
        prefixIcon: Icon(i), 
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}