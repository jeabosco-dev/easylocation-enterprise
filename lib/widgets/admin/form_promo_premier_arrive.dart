// lib/widgets/admin/form_promo_premier_arrive.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; 
import 'package:easylocation_mvp/services/location_service.dart';
import 'package:easylocation_mvp/services/config_service.dart'; 
import 'package:easylocation_mvp/models/service_model.dart'; 

class FormPromoPremierArrive extends StatefulWidget {
  const FormPromoPremierArrive({super.key});

  @override
  State<FormPromoPremierArrive> createState() => _FormPromoPremierArriveState();
}

class _FormPromoPremierArriveState extends State<FormPromoPremierArrive> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locService = LocationService();

  final TextEditingController _titreCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _valeurCtrl = TextEditingController();
  final TextEditingController _limitCtrl = TextEditingController(text: "100");

  String? _selectedProvince;
  String? _selectedVille;
  String? _selectedCommune;
  List<String> _provincesDisponibles = [];
  List<String> _villesDisponibles = [];
  List<String> _communesDisponibles = [];

  final List<String> _selectedServices = []; 
  final List<String> _selectedCategories = []; // ✅ Ajout pour ciblage par catégorie

  bool _isActive = false;
  DateTimeRange? _dateRange;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  Future<void> _loadProvinces() async {
    final provinces = await _locService.getProvinces();
    setState(() => _provincesDisponibles = provinces);
  }

  Future<void> _onProvinceChanged(String? val) async {
    setState(() {
      _selectedProvince = val;
      _selectedVille = null;
      _selectedCommune = null;
      _villesDisponibles = [];
      _communesDisponibles = [];
    });
    if (val != null && val != 'tous') {
      final villes = await _locService.getVilles(val);
      setState(() => _villesDisponibles = villes);
    }
  }

  Future<void> _onVilleChanged(String? val) async {
    setState(() {
      _selectedVille = val;
      _selectedCommune = null;
      _communesDisponibles = [];
    });
    if (val != null && val != 'tous' && _selectedProvince != null) {
      final communes = await _locService.getCommunes(_selectedProvince!, val);
      setState(() => _communesDisponibles = communes);
    }
  }

  Future<void> _save() async {
    final String code = _codeCtrl.text.trim().toUpperCase();

    if (code.isEmpty || _dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le code et les dates sont obligatoires"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final pList = (_selectedProvince != null && _selectedProvince != 'tous') ? [_selectedProvince!] : [];
      final vList = (_selectedVille != null && _selectedVille != 'tous') ? [_selectedVille!] : [];
      final cList = (_selectedCommune != null && _selectedCommune != 'tous') ? [_selectedCommune!] : [];

      await _firestore.collection('promotions').doc(code).set({
        'titre': _titreCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'code': code,
        'valeur': double.tryParse(_valeurCtrl.text) ?? 0.0,
        'type': 'pourcentage',
        'beneficiaire': 'tous',
        'provinces': pList,
        'villes': vList,
        'communes': cList,
        'servicesEligibles': _selectedServices,
        'categoriesEligibles': _selectedCategories, // ✅ Sauvegarde dynamique
        'date_debut': Timestamp.fromDate(_dateRange!.start),
        'date_fin': Timestamp.fromDate(_dateRange!.end),
        'statut': _isActive ? 'actif' : 'inactif',
        'usage_limit': int.tryParse(_limitCtrl.text) ?? 100,
        'usage_count': 0,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offre déployée avec succès !"), backgroundColor: Colors.green),
      );
      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
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
      _selectedProvince = null;
      _selectedVille = null;
      _selectedCommune = null;
      _villesDisponibles = [];
      _communesDisponibles = [];
      _selectedServices.clear();
      _selectedCategories.clear(); // ✅ Reset dynamique
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigService>();
    final List<ServiceModel> services = config.servicesDisponibles;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Configuration Offre (Ciblage)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(height: 40),

                  // (Note: Tes Dropdowns Province/Ville/Commune vont ici)

                  const SizedBox(height: 20),
                  const Text("Services éligibles (Optionnel)", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: services.map((s) => FilterChip(
                      label: Text(s.nomAffichage),
                      selected: _selectedServices.contains(s.typeService),
                      onSelected: (v) => setState(() => v ? _selectedServices.add(s.typeService) : _selectedServices.remove(s.typeService))
                    )).toList(),
                  ),

                  const SizedBox(height: 20),
                  const Text("Catégories éligibles (Optionnel)", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    // ✅ Utilisation de la liste dynamique depuis Firestore
                    children: config.categoriesImmo.map((c) => FilterChip(
                      label: Text(c),
                      selected: _selectedCategories.contains(c),
                      onSelected: (v) => setState(() => v ? _selectedCategories.add(c) : _selectedCategories.remove(c))
                    )).toList(),
                  ),

                  const SizedBox(height: 20),
                  _buildField(_titreCtrl, "Titre de l'opération", Icons.campaign),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildField(_codeCtrl, "CODE PROMO", Icons.vpn_key)),
                      const SizedBox(width: 15),
                      Expanded(child: _buildField(_limitCtrl, "Places", Icons.people, isNum: true)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildField(_valeurCtrl, "Remise (%)", Icons.percent, isNum: true),
                  
                  const SizedBox(height: 25),
                  SwitchListTile(
                    title: const Text("Activer l'offre"),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: Text(_dateRange == null ? "Sélectionner les dates" : "Du ${DateFormat('dd/MM').format(_dateRange!.start)} au ${DateFormat('dd/MM').format(_dateRange!.end)}"),
                    onTap: _selectDateRange,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: Text(_isSaving ? "Traitement..." : "DÉPLOYER"),
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

  Future<void> _selectDateRange() async {
    final res = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2030));
    if (res != null) setState(() => _dateRange = res);
  }

  Widget _buildField(TextEditingController c, String l, IconData i, {bool isNum = false}) {
    return TextFormField(
      controller: c,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), border: const OutlineInputBorder()),
    );
  }
}