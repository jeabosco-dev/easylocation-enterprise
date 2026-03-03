import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour les champs de texte
  final TextEditingController _tauxUsdController = TextEditingController();
  
  // Maps pour stocker les contrôleurs des taux d'expertise dynamiquement
  Map<String, TextEditingController> bailleurControllers = {};
  Map<String, TextEditingController> locataireControllers = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    try {
      DocumentSnapshot doc = await _firestore.collection('settings').doc('app_config').get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        setState(() {
          _tauxUsdController.text = data['taux_usd_cdf'].toString();
          
          Map<String, dynamic> expertise = data['taux_expertise'];
          expertise.forEach((niveau, taux) {
            bailleurControllers[niveau] = TextEditingController(text: taux['bailleur'].toString());
            locataireControllers[niveau] = TextEditingController(text: taux['locataire'].toString());
          });
          
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur de chargement: $e")));
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Reconstruire la map taux_expertise
      Map<String, dynamic> updatedExpertise = {};
      bailleurControllers.forEach((niveau, controller) {
        updatedExpertise[niveau] = {
          "bailleur": double.parse(controller.text),
          "locataire": double.parse(locataireControllers[niveau]!.text),
        };
      });

      await _firestore.collection('settings').doc('app_config').set({
        'taux_usd_cdf': double.parse(_tauxUsdController.text),
        'taux_expertise': updatedExpertise,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configuration mise à jour avec succès !")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur lors de la sauvegarde: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text("Configuration Système")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Taux de Change"),
              SizedBox(
                width: 200,
                child: TextFormField(
                  controller: _tauxUsdController,
                  decoration: const InputDecoration(labelText: "1 USD = ? CDF", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle("Taux de Commission Expertise (%)"),
              const Text("Modifiez les taux pour chaque catégorie de bien.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              
              // Génération dynamique des lignes Bronze, Silver, Gold, Diamond
              Table(
                columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2)},
                children: [
                  const TableRow(children: [
                    Padding(padding: EdgeInsets.all(8), child: Text("Niveau", style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8), child: Text("Bailleur (%)", style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8), child: Text("Locataire (%)", style: TextStyle(fontWeight: FontWeight.bold))),
                  ]),
                  ...bailleurControllers.keys.map((niveau) {
                    return TableRow(children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text(niveau.toUpperCase())),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextFormField(controller: bailleurControllers[niveau], keyboardType: TextInputType.number),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextFormField(controller: locataireControllers[niveau], keyboardType: TextInputType.number),
                      ),
                    ]);
                  }).toList(),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text("Enregistrer les modifications"),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }
}