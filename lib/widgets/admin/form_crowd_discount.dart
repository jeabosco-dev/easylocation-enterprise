// lib/widgets/admin/form_crowd_discount.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; 
import '../../models/community_goal_model.dart';
import 'package:easylocation_mvp/constants/property_constants.dart';
import 'package:easylocation_mvp/services/location_service.dart';
import 'package:easylocation_mvp/services/config_service.dart'; 
import 'package:easylocation_mvp/models/service_model.dart'; 

class FormCrowdDiscount extends StatefulWidget {
  const FormCrowdDiscount({super.key});

  @override
  State<FormCrowdDiscount> createState() => _FormCrowdDiscountState();
}

class _FormCrowdDiscountState extends State<FormCrowdDiscount> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locService = LocationService();

  final TextEditingController _titreCtrl = TextEditingController();
  final TextEditingController _goalCtrl = TextEditingController(text: "50");
  final TextEditingController _rewardCtrl = TextEditingController(text: "20");

  MissionType _selectedType = MissionType.reservations;
  
  String? _selectedProvince;
  String? _selectedVille;
  String? _selectedCommune;
  List<String> _provincesDisponibles = [];
  List<String> _villesDisponibles = [];
  List<String> _communesDisponibles = [];

  String _selectedBeneficiaire = AppBeneficiaires.tous;
  final List<String> _selectedServices = []; 
  final List<String> _selectedCategories = []; // ✅ AJOUT

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

  @override
  void dispose() {
    _titreCtrl.dispose();
    _goalCtrl.dispose();
    _rewardCtrl.dispose();
    super.dispose();
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

  String _getDynamicMessage() {
    String action = "";
    switch (_selectedType) {
      case MissionType.inscriptions: action = "nouveaux locataires rejoignent"; break;
      case MissionType.reservations: action = "réservations sont effectuées"; break;
      case MissionType.publications: action = "biens sont publiés"; break;
    }

    String lieu = (_selectedProvince == null || _selectedProvince == 'tous') 
        ? "en RDC" 
        : "à ${_selectedVille ?? _selectedProvince}";
        
    String dateStr = _dateRange != null 
        ? "avant le ${DateFormat('dd/MM').format(_dateRange!.end)}" 
        : "prochainement";

    return "Objectif $lieu pour les ${_selectedBeneficiaire.toUpperCase()} : Si ${_goalCtrl.text} $action $dateStr, -${_rewardCtrl.text}% de remise !";
  }

  Future<void> _saveGoal() async {
    if (_titreCtrl.text.isEmpty || _dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Titre et dates de validité obligatoires"), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final pList = (_selectedProvince != null && _selectedProvince != 'tous') ? [_selectedProvince!] : [];
      final vList = (_selectedVille != null && _selectedVille != 'tous') ? [_selectedVille!] : [];
      final cList = (_selectedCommune != null && _selectedCommune != 'tous') ? [_selectedCommune!] : [];

      DocumentReference docRef = await _firestore.collection('community_goals').add({
        'titre': _titreCtrl.text.trim(),
        'provinces': pList,
        'villes': vList,
        'communes': cList,
        'beneficiaire': _selectedBeneficiaire,
        'servicesEligibles': _selectedServices,
        'categoriesEligibles': _selectedCategories, // ✅ SAUVEGARDE DYNAMIQUE
        'type': _selectedType.toString().split('.').last,
        'goal_value': int.tryParse(_goalCtrl.text) ?? 50,
        'current_value': 0,
        'reward_value': double.tryParse(_rewardCtrl.text) ?? 0.0,
        'date_debut': Timestamp.fromDate(_dateRange!.start),
        'deadline': Timestamp.fromDate(_dateRange!.end),
        'statut': 'en_cours',
        'created_at': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('settings').doc('app_config').update({
        'active_community_goal_id': docRef.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Challenge lancé !"), backgroundColor: Colors.green));
        _clearForm();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _titreCtrl.clear();
    setState(() {
      _dateRange = null;
      _selectedProvince = null;
      _selectedVille = null;
      _selectedCommune = null;
      _villesDisponibles = [];
      _communesDisponibles = [];
      _selectedBeneficiaire = AppBeneficiaires.tous;
      _selectedServices.clear();
      _selectedCategories.clear(); // ✅ RESET DYNAMIQUE
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigService>();
    final List<ServiceModel> services = config.servicesDisponibles;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orange[700]!, Colors.deepOrange]), borderRadius: BorderRadius.circular(15)),
            child: Text(_getDynamicMessage(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),
          const SizedBox(height: 30),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Paramètres du Challenge", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  TextField(controller: _titreCtrl, decoration: const InputDecoration(labelText: "Nom de l'opération", prefixIcon: Icon(Icons.edit))),
                  const SizedBox(height: 20),

                  // --- SÉLECTION GÉOGRAPHIQUE ---
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
                      onSelected: (bool selected) {
                        setState(() => selected ? _selectedServices.add(s.typeService) : _selectedServices.remove(s.typeService));
                      },
                    )).toList(),
                  ),

                  // ✅ SECTION CATÉGORIES DYNAMIQUE
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
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Bénéficiaire cible", border: OutlineInputBorder(), prefixIcon: Icon(Icons.people_outline)),
                    value: _selectedBeneficiaire,
                    items: AppBeneficiaires.liste.map((b) => DropdownMenuItem(value: b, child: Text(b.toUpperCase()))).toList(),
                    onChanged: (v) => setState(() => _selectedBeneficiaire = v!),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<MissionType>(
                    value: _selectedType,
                    decoration: const InputDecoration(labelText: "Action requise", border: OutlineInputBorder()),
                    items: MissionType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
                    onChanged: (t) => setState(() => _selectedType = t!),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _buildNumField(_goalCtrl, "Objectif total", Icons.group)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildNumField(_rewardCtrl, "Remise (%)", Icons.redeem)),
                  ]),
                  const SizedBox(height: 20),
                  ListTile(
                    tileColor: Colors.orange.withOpacity(0.05),
                    leading: const Icon(Icons.calendar_today, color: Colors.orange),
                    title: Text(_dateRange == null ? "Définir la durée" : "${DateFormat('dd/MM').format(_dateRange!.start)} - ${DateFormat('dd/MM').format(_dateRange!.end)}"),
                    onTap: _selectDateRange,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(onPressed: _isSaving ? null : _saveGoal, child: Text(_isSaving ? "LANCEMENT..." : "LANCER LE CHALLENGE")),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final res = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2030));
    if (res != null) setState(() => _dateRange = res);
  }

  Widget _buildNumField(TextEditingController c, String l, IconData i) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), border: const OutlineInputBorder()),
    );
  }
}