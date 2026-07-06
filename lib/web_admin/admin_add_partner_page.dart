// lib/web_admin/admin_add_partner_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/utils/phone_utils.dart';
// IMPORT CORRIGÉ SELON TON CHEMIN RÉEL
import 'package:easylocation_mvp/widgets/admin/qr_partner_widget.dart'; 

class AdminAddPartnerPage extends StatefulWidget {
  const AdminAddPartnerPage({super.key});

  @override
  _AdminAddPartnerPageState createState() => _AdminAddPartnerPageState();
}

class _AdminAddPartnerPageState extends State<AdminAddPartnerPage> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _idController = TextEditingController(); 
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(); 
  final TextEditingController _rateController = TextEditingController(text: "0.05"); 
  final TextEditingController _uidController = TextEditingController(); 
  final TextEditingController _autrePrecisionController = TextEditingController();

  String _selectedType = 'Eglise';
  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _nomController.dispose();
    _phoneController.dispose();
    _rateController.dispose();
    _uidController.dispose();
    _autrePrecisionController.dispose();
    super.dispose();
  }

  // --- FONCTION : SAUVEGARDE ET GÉNÉRATION ---
  Future<void> _processPartner() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      String partnerIdFinal = "PART-${_idController.text.trim().toUpperCase()}";
      String typeFinal = (_selectedType == 'Autre') 
          ? _autrePrecisionController.text.trim() 
          : _selectedType;

      String? phoneFinal = _phoneController.text.trim().isNotEmpty 
          ? normalizePhoneNumber(_phoneController.text.trim()) 
          : null;

      try {
        await FirebaseFirestore.instance.collection('partenaires').doc(partnerIdFinal).set({
          'nom': _nomController.text.trim(),
          'telephone': phoneFinal,
          'type': typeFinal,
          'commission_rate': double.parse(_rateController.text),
          'is_active': true,
          'status': 'active',
          'solde_commission': 0.0,
          'total_conversions': 0,
          'linked_uid': _uidController.text.trim().isEmpty ? null : _uidController.text.trim(),
          'created_at': FieldValue.serverTimestamp(),
        });

        if (_uidController.text.trim().isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('utilisateurs')
              .doc(_uidController.text.trim())
              .update({'partner_linked_id': partnerIdFinal});
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Partenaire B2B configuré avec succès !"), backgroundColor: Colors.green),
        );

        // Appel du widget QR Code
        _showQRCodeDialog(context, partnerIdFinal, _nomController.text.trim());

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erreur de configuration : $e"), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- AFFICHAGE DU WIDGET QR CODE ---
  void _showQRCodeDialog(BuildContext context, String partnerId, String partnerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => QrPartnerWidget(
        partnerId: partnerId,
        partnerName: partnerName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nouveau Partenaire B2B")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      TextFormField(
                        controller: _idController,
                        decoration: const InputDecoration(
                          labelText: "ID Unique (ex: RADIO-MAENDELEO)",
                          helperText: "L'app ajoutera 'PART-' automatiquement",
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? "L'ID est obligatoire" : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: "Nom officiel du partenaire",
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? "Le nom est obligatoire" : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: "Numéro WhatsApp / Téléphone",
                          hintText: "09XXXXXXXX",
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        items: ['Eglise', 'Entreprise', 'Media', 'Individuel', 'Autre']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedType = val;
                              if (_selectedType != 'Autre') _autrePrecisionController.clear();
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: "Type de structure",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      if (_selectedType == 'Autre') ...[
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _autrePrecisionController,
                          decoration: const InputDecoration(
                            labelText: "Précisez le type",
                            hintText: "Ex: ONG, Association, École...",
                            prefixIcon: Icon(Icons.edit, color: Colors.orange),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (_selectedType == 'Autre' && (v == null || v.trim().isEmpty)) 
                              ? "Veuillez préciser le type de structure" : null,
                        ),
                      ],

                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: "Taux de commission (ex: 0.10 pour 10%)",
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? "Le taux est obligatoire" : null,
                      ),
                      const SizedBox(height: 25),
                      const Divider(),
                      const Text("LIAISON COMPTE (OPTIONNEL)", 
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _uidController,
                        decoration: const InputDecoration(
                          labelText: "UID Firebase du Partenaire",
                          helperText: "Laisse vide si le partenaire n'a pas encore de compte app",
                          icon: Icon(Icons.link),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _processPartner,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 60),
                          backgroundColor: const Color(0xFF1E5D8F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("ACTIVER LE PARTENARIAT PRO", 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
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
}