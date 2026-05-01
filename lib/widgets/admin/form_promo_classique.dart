import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FormPromoClassique extends StatefulWidget {
  const FormPromoClassique({super.key});

  @override
  State<FormPromoClassique> createState() => _FormPromoClassiqueState();
}

class _FormPromoClassiqueState extends State<FormPromoClassique> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _valeurController = TextEditingController();

  bool _isActive = false;
  bool _isPercentage = true;
  DateTimeRange? _selectedDateRange;
  bool _isSaving = false;

  Future<void> _savePromo() async {
    final String code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty || _selectedDateRange == null) {
      _showSnackBar("Code et dates obligatoires", Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _firestore.collection('promotions').doc(code).set({
        'titre': _titreController.text.trim(),
        'description': _descController.text.trim(),
        'code': code,
        'valeur': double.tryParse(_valeurController.text) ?? 0.0,
        'type': _isPercentage ? 'pourcentage' : 'montantFixe',
        'target': 'commission', // Fixé sur commission pour ce formulaire
        'date_debut': Timestamp.fromDate(_selectedDateRange!.start),
        'date_fin': Timestamp.fromDate(_selectedDateRange!.end),
        'statut': _isActive ? 'actif' : 'inactif',
        'usage_limit': 0, // 0 = Illimité pour les promos classiques
        'usage_count': 0,
        'last_updated': FieldValue.serverTimestamp(),
      });

      _showSnackBar("Promotion classique déployée !", Colors.green);
      _clearForm();
    } catch (e) {
      _showSnackBar("Erreur : $e", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _titreController.clear();
    _descController.clear();
    _codeController.clear();
    _valeurController.clear();
    setState(() {
      _selectedDateRange = null;
      _isActive = false;
    });
  }

  void _showSnackBar(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Nouvelle Promotion Standard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(height: 30),
                  
                  SwitchListTile(
                    title: const Text("Activer maintenant"),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  
                  const SizedBox(height: 20),
                  _buildInput(_titreController, "Titre (ex: Promo Vacances)", Icons.campaign),
                  const SizedBox(height: 15),
                  _buildInput(_descController, "Description", Icons.description, maxLines: 2),
                  
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildInput(_codeController, "CODE PROMO", Icons.vpn_key)),
                      const SizedBox(width: 15),
                      Expanded(child: _buildInput(_valeurController, "Valeur", Icons.add_chart, isNum: true)),
                      const SizedBox(width: 10),
                      _buildTypeToggle(),
                    ],
                  ),
                  
                  const SizedBox(height: 25),
                  _buildDatePicker(),
                  
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _savePromo,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[800], foregroundColor: Colors.white),
                      child: Text(_isSaving ? "CHARGEMENT..." : "ENREGISTRER"),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      tileColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: const Icon(Icons.calendar_today),
      title: Text(_selectedDateRange == null 
        ? "Choisir les dates" 
        : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}"),
      onTap: () async {
        final res = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2030));
        if (res != null) setState(() => _selectedDateRange = res);
      },
    );
  }

  Widget _buildTypeToggle() {
    return Column(
      children: [
        const Text("%", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        Checkbox(value: _isPercentage, onChanged: (v) => setState(() => _isPercentage = v!)),
      ],
    );
  }

  Widget _buildInput(TextEditingController c, String l, IconData i, {int maxLines = 1, bool isNum = false}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), border: const OutlineInputBorder()),
    );
  }
}