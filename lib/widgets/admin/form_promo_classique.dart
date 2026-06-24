// lib/widgets/admin/form_promo_classique.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; 
import 'package:easylocation_mvp/constants/property_constants.dart';
import 'package:easylocation_mvp/services/location_service.dart';
import 'package:easylocation_mvp/services/config_service.dart'; 
import 'package:easylocation_mvp/models/service_model.dart'; 

class FormPromoClassique extends StatefulWidget {
  const FormPromoClassique({super.key});

  @override
  State<FormPromoClassique> createState() => _FormPromoClassiqueState();
}

class _FormPromoClassiqueState extends State<FormPromoClassique> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locService = LocationService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _valeurController = TextEditingController();

  String? _selectedProvince;
  String? _selectedVille;
  String? _selectedCommune;
  
  List<String> _provincesDisponibles = [];
  List<String> _villesDisponibles = [];
  List<String> _communesDisponibles = [];

  String _selectedBeneficiaire = AppBeneficiaires.tous;
  final List<String> _selectedServices = []; 
  final List<String> _selectedCategories = [];

  bool _isActive = false;
  bool _isPercentage = true;
  DateTimeRange? _selectedDateRange;
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

  Future<void> _savePromo() async {
    if (!_formKey.currentState!.validate() || _selectedDateRange == null) {
      _showSnackBar("Veuillez remplir tous les champs requis et choisir les dates", Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String code = _codeController.text.trim().toUpperCase();
      
      final List<String> pList = (_selectedProvince != null && _selectedProvince != 'tous') ? [_selectedProvince!] : [];
      final List<String> vList = (_selectedVille != null && _selectedVille != 'tous') ? [_selectedVille!] : [];
      final List<String> cList = (_selectedCommune != null && _selectedCommune != 'tous') ? [_selectedCommune!] : [];

      await _firestore.collection('promotions').doc(code).set({
        'titre': _titreController.text.trim(),
        'description': _descController.text.trim(),
        'code': code,
        'valeur': double.tryParse(_valeurController.text) ?? 0.0,
        'type': _isPercentage ? 'pourcentage' : 'montantFixe',
        'date_debut': Timestamp.fromDate(_selectedDateRange!.start),
        'date_fin': Timestamp.fromDate(_selectedDateRange!.end),
        'statut': _isActive ? 'actif' : 'inactif',
        'beneficiaire': _selectedBeneficiaire,
        'provinces': pList,
        'villes': vList,
        'communes': cList,
        'servicesEligibles': _selectedServices,
        'categoriesEligibles': _selectedCategories,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSnackBar("Promotion enregistrée avec succès !", Colors.green);
      _clearForm();
    } catch (e) {
      _showSnackBar("Erreur : $e", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _formKey.currentState!.reset();
    _titreController.clear();
    _descController.clear();
    _codeController.clear();
    _valeurController.clear();
    setState(() {
      _selectedDateRange = null;
      _selectedProvince = null;
      _selectedVille = null;
      _selectedCommune = null;
      _villesDisponibles = [];
      _communesDisponibles = [];
      _selectedBeneficiaire = AppBeneficiaires.tous;
      _selectedServices.clear();
      _selectedCategories.clear();
      _isActive = false;
    });
  }

  void _showSnackBar(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigService>();
    final List<ServiceModel> services = config.servicesDisponibles;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _formKey,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Nouvelle Promotion", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(height: 30),
                    
                    SwitchListTile(title: const Text("Activer"), value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
                    _buildInput(_titreController, "Titre", Icons.campaign, isRequired: true),
                    const SizedBox(height: 10),
                    _buildInput(_descController, "Description", Icons.description),
                    const SizedBox(height: 10),
                    
                    Row(
                      children: [
                        Expanded(child: _buildInput(_codeController, "CODE PROMO", Icons.vpn_key, isRequired: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput(_valeurController, "Valeur", Icons.add_chart, isNum: true, isRequired: true)),
                        Checkbox(value: _isPercentage, onChanged: (v) => setState(() => _isPercentage = v!)),
                        const Text("%")
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // --- SÉLECTION GÉOGRAPHIQUE DYNAMIQUE ---
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Province", border: OutlineInputBorder()),
                      value: _selectedProvince,
                      items: [
                        const DropdownMenuItem(value: 'tous', child: Text("Toutes les provinces")),
                        ..._provincesDisponibles.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase())))
                      ],
                      onChanged: _onProvinceChanged,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Ville", border: OutlineInputBorder()),
                      value: _selectedVille,
                      items: [
                        const DropdownMenuItem(value: 'tous', child: Text("Toutes les villes")),
                        ..._villesDisponibles.map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      ],
                      onChanged: _onVilleChanged,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Commune", border: OutlineInputBorder()),
                      value: _selectedCommune,
                      items: [
                        const DropdownMenuItem(value: 'tous', child: Text("Toutes les communes")),
                        ..._communesDisponibles.map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      ],
                      onChanged: (v) => setState(() => _selectedCommune = v),
                    ),
                    
                    const SizedBox(height: 20),
                    const Text("Services éligibles", style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 10,
                      children: services.map((s) => FilterChip(
                        label: Text(s.nomAffichage), 
                        selected: _selectedServices.contains(s.typeService),
                        onSelected: (v) => setState(() => v ? _selectedServices.add(s.typeService) : _selectedServices.remove(s.typeService))
                      )).toList(),
                    ),
                    
                    const SizedBox(height: 20),
                    const Text("Catégories éligibles", style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 10,
                      children: config.categoriesImmo.map((c) => FilterChip(
                        label: Text(c), 
                        selected: _selectedCategories.contains(c), 
                        onSelected: (v) => setState(() => v ? _selectedCategories.add(c) : _selectedCategories.remove(c))
                      )).toList(),
                    ),
                    
                    const SizedBox(height: 20),
                    // --- AJOUT CHAMP BÉNÉFICIAIRE ---
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Bénéficiaire cible", 
                        border: OutlineInputBorder(), 
                        prefixIcon: Icon(Icons.people_outline)
                      ),
                      value: _selectedBeneficiaire,
                      items: AppBeneficiaires.liste.map((b) => DropdownMenuItem(
                        value: b, 
                        child: Text(b.toUpperCase())
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedBeneficiaire = v!),
                    ),
                    const SizedBox(height: 20),

                    _buildDatePicker(),
                    
                    const SizedBox(height: 30),
                    SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isSaving ? null : _savePromo, child: Text(_isSaving ? "CHARGEMENT..." : "ENREGISTRER"))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() => ListTile(
      tileColor: Colors.grey[100], 
      leading: const Icon(Icons.calendar_today), 
      title: Text(_selectedDateRange == null ? "Choisir les dates" : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}"), 
      onTap: () async { final res = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2030)); if (res != null) setState(() => _selectedDateRange = res); }
  );

  Widget _buildInput(TextEditingController c, String l, IconData i, {bool isNum = false, bool isRequired = false}) => TextFormField(controller: c, keyboardType: isNum ? TextInputType.number : TextInputType.text, validator: isRequired ? (v) => v!.isEmpty ? "Champ requis" : null : null, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), border: const OutlineInputBorder()));
}