import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/community_goal_model.dart';

class FormCrowdDiscount extends StatefulWidget {
  const FormCrowdDiscount({super.key});

  @override
  State<FormCrowdDiscount> createState() => _FormCrowdDiscountState();
}

class _FormCrowdDiscountState extends State<FormCrowdDiscount> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final TextEditingController _titreCtrl = TextEditingController();
  final TextEditingController _goalCtrl = TextEditingController(text: "50");
  final TextEditingController _rewardCtrl = TextEditingController(text: "20");

  MissionType _selectedType = MissionType.reservations;
  String _selectedVille = "Goma";
  final List<String> _villes = ["Bukavu", "Goma", "Kinshasa", "National"];
  
  DateTimeRange? _dateRange;
  bool _isSaving = false;

  @override
  void dispose() {
    _titreCtrl.dispose();
    _goalCtrl.dispose();
    _rewardCtrl.dispose();
    super.dispose();
  }

  String _getDynamicMessage() {
    String action = "";
    switch (_selectedType) {
      case MissionType.inscriptions: action = "nouveaux locataires rejoignent"; break;
      case MissionType.reservations: action = "réservations sont effectuées"; break;
      case MissionType.publications: action = "biens sont publiés"; break;
    }
    
    String lieu = _selectedVille == "National" ? "en RDC" : "à $_selectedVille";
    String dateStr = _dateRange != null 
        ? "avant le ${DateFormat('dd/MM').format(_dateRange!.end)}" 
        : "prochainement";

    return "Objectif $lieu : Si ${_goalCtrl.text} $action $dateStr, -${_rewardCtrl.text}% de remise pour tout le monde !";
  }

  /// ✅ SAUVEGARDE ET SYNCHRONISATION AUTOMATIQUE
  Future<void> _saveGoal() async {
    if (_titreCtrl.text.isEmpty || _dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Titre et dates de validité obligatoires"), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // 1. Création du challenge dans la collection dédiée
      DocumentReference docRef = await _firestore.collection('community_goals').add({
        'titre': _titreCtrl.text.trim(),
        'ville': _selectedVille,
        'type': _selectedType.toString().split('.').last,
        'goal_value': int.tryParse(_goalCtrl.text) ?? 50,
        'current_value': 0,
        'reward_value': double.tryParse(_rewardCtrl.text) ?? 0.0,
        'date_debut': Timestamp.fromDate(_dateRange!.start),
        'deadline': Timestamp.fromDate(_dateRange!.end), 
        'statut': 'en_cours',
        'created_at': FieldValue.serverTimestamp(),
      });

      // 2. ⚡ SYNCHRONISATION : On met à jour l'ID actif dans la config globale
      // Cela permet au ConfigService (Front-office) de détecter le nouveau challenge sans action manuelle.
      await _firestore.collection('settings').doc('app_config').update({
        'active_community_goal_id': docRef.id,
        'last_updated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Challenge lancé et synchronisé !"), backgroundColor: Colors.green)
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _titreCtrl.clear();
    setState(() {
      _dateRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // --- APERÇU DYNAMIQUE ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange[700]!, Colors.deepOrange]),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10)],
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text("APERÇU CLIENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _getDynamicMessage(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
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
                  
                  TextField(
                    controller: _titreCtrl,
                    decoration: const InputDecoration(labelText: "Nom de l'opération (ex: Rush Goma)", prefixIcon: Icon(Icons.edit)),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedVille,
                          decoration: const InputDecoration(labelText: "Ville cible"),
                          items: _villes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                          onChanged: (v) => setState(() => _selectedVille = v!),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: DropdownButtonFormField<MissionType>(
                          value: _selectedType,
                          decoration: const InputDecoration(labelText: "Action requise"),
                          items: MissionType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
                          onChanged: (t) => setState(() => _selectedType = t!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(child: _buildNumField(_goalCtrl, "Objectif total", Icons.group)),
                      const SizedBox(width: 15),
                      Expanded(child: _buildNumField(_rewardCtrl, "Remise finale (%)", Icons.redeem)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ListTile(
                    tileColor: Colors.orange.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.orange.withOpacity(0.2))),
                    leading: const Icon(Icons.calendar_today, color: Colors.orange),
                    title: Text(_dateRange == null 
                      ? "Définir la durée du challenge" 
                      : "Du ${DateFormat('dd/MM').format(_dateRange!.start)} au ${DateFormat('dd/MM').format(_dateRange!.end)}"),
                    trailing: const Icon(Icons.edit, size: 18),
                    onTap: _selectDateRange,
                  ),

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveGoal,
                      icon: const Icon(Icons.flash_on),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800], 
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                      label: Text(_isSaving ? "LANCEMENT..." : "LANCER LE CHALLENGE"),
                    ),
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
    final res = await showDateRangePicker(
      context: context, 
      firstDate: DateTime.now(), 
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.orange[800]!),
          ),
          child: child!,
        );
      },
    );
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