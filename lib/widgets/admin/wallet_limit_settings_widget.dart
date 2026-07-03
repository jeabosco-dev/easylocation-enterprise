import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletLimitSettingsWidget extends StatefulWidget {
  const WalletLimitSettingsWidget({super.key});

  @override
  State<WalletLimitSettingsWidget> createState() => _WalletLimitSettingsWidgetState();
}

class _WalletLimitSettingsWidgetState extends State<WalletLimitSettingsWidget> {
  final TextEditingController _limitController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          // Lecture de la valeur stockée ou défaut à 0.25 (25%)
          _limitController.text = (data['wallet_limit_percentage'] ?? 0.25).toString();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Erreur chargement config: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('app_config').update({
        'wallet_limit_percentage': double.tryParse(_limitController.text) ?? 0.25,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Limite Wallet mise à jour avec succès"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Configuration Financière (Wallet)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _limitController,
              decoration: const InputDecoration(
                labelText: "Pourcentage limite Wallet (ex: 0.15 pour 15%)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.percent),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveData,
                child: const Text("Enregistrer la limite"),
              ),
            )
          ],
        ),
      ),
    );
  }
}