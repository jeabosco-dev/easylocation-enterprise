// lib/views/visites/decision_visite_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
// Importez la page d'upsell
import 'package:easylocation_mvp/screens/upsell_selection_page.dart'; 

class DecisionVisitePage extends StatefulWidget {
  final String factureId;
  final String propertyRef;
  final String? propertyId;   

  const DecisionVisitePage({
    super.key, 
    required this.factureId, 
    required this.propertyRef,
    this.propertyId, 
  });

  @override
  State<DecisionVisitePage> createState() => _DecisionVisitePageState();
}

class _DecisionVisitePageState extends State<DecisionVisitePage> {
  bool _isLoader = false;
  String _selectedMotif = "Le bien ne correspond pas aux photos";
  final TextEditingController _autreMotifController = TextEditingController();

  @override
  void dispose() {
    _autreMotifController.dispose();
    super.dispose();
  }

  // --- ACTION : VALIDER LA LOCATION ---
  Future<void> _confirmerLocation() async {
    setState(() => _isLoader = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      final factureRef = FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(widget.factureId);
      batch.update(factureRef, {
        FactureFields.confirmationLocataire: 'valide',
        'dateConfirmationLocataire': FieldValue.serverTimestamp(),
        FactureFields.etapeDossier: FactureFields.etapeVisiteTerminee, 
        'issueVisite': 'VALIDE', 
        if (widget.propertyId != null) 'propertyId': widget.propertyId,
      });

      await batch.commit();
      
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          UpsellSelectionPage.routeName, 
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      _showError("Erreur lors de la validation : $e");
    } finally {
      if (mounted) setState(() => _isLoader = false);
    }
  }

  // --- ACTION : REFUSER LA LOCATION ---
  Future<void> _refuserLocation() async {
    // Déterminer le motif final
    final motifFinal = (_selectedMotif == "Autre raison") 
        ? _autreMotifController.text.trim() 
        : _selectedMotif;

    // Validation si "Autre raison" est vide
    if (_selectedMotif == "Autre raison" && motifFinal.isEmpty) {
      _showError("Veuillez préciser votre motif.");
      return;
    }

    setState(() => _isLoader = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final factureRef = FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(widget.factureId);
      
      batch.update(factureRef, {
        FactureFields.confirmationLocataire: 'refuse',
        FactureFields.motifRejet: motifFinal,
        'dateRefusLocataire': FieldValue.serverTimestamp(),
        FactureFields.etapeDossier: FactureFields.etapeVisiteTerminee,
        'issueVisite': 'REFUSEE',
        if (widget.propertyId != null) 'propertyId': widget.propertyId,
      });

      await batch.commit();
      
      if (mounted) {
        Navigator.pop(context); // Ferme le dialogue de motif
        _showSuccessDialog(
          "Dossier enregistré", 
          "Nous regrettons que ce bien n'ait pas répondu à vos attentes. Soyez assuré(e) que votre dossier est entre nos mains. Nous mettons tout en œuvre pour vous trouver un logement qui vous correspond."
        );
      }
    } catch (e) {
      _showError("Erreur lors du refus : $e");
    } finally {
      if (mounted) setState(() => _isLoader = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Verdict de votre visite", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoader 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView( 
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.house_siding_rounded, size: 100, color: Color(0xFF0D47A1)),
                const SizedBox(height: 30),
                Text(
                  "La propriété\n${widget.propertyRef}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  "En confirmant, vous acceptez l'état actuel du bien et déclenchez la remise des clés.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
                const SizedBox(height: 60),
                _buildActionButton(
                  label: "OUI, JE PRENDS LA MAISON",
                  icon: Icons.check_circle,
                  color: Colors.green.shade700,
                  onPressed: _confirmerLocation,
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  label: "NON, JE REFUSE",
                  icon: Icons.cancel,
                  color: Colors.red.shade700,
                  isOutlined: true,
                  onPressed: _showMotifRefusDialog,
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildActionButton({
    required String label, 
    required IconData icon, 
    required Color color, 
    required VoidCallback onPressed, 
    bool isOutlined = false
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: isOutlined 
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          )
        : ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
    );
  }

  void _showMotifRefusDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( 
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Pourquoi refusez-vous ?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _motifOption("Le bien ne correspond pas aux photos", setDialogState),
                  _motifOption("Problème de propreté / état", setDialogState),
                  _motifOption("Le quartier ne me convient pas", setDialogState),
                  _motifOption("Autre raison", setDialogState),
                  
                  if (_selectedMotif == "Autre raison")
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: _autreMotifController,
                        decoration: const InputDecoration(
                          hintText: "Précisez votre raison...",
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
              ElevatedButton(
                onPressed: _refuserLocation,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("CONFIRMER LE REFUS", style: TextStyle(color: Colors.white)),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _motifOption(String text, StateSetter setDialogState) {
    return RadioListTile<String>(
      title: Text(text, style: const TextStyle(fontSize: 14)),
      value: text,
      groupValue: _selectedMotif,
      activeColor: Colors.red,
      onChanged: (val) {
        setDialogState(() => _selectedMotif = val!);
      },
    );
  }

  void _showSuccessDialog(String title, String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), 
            child: const Text("OK")
          )
        ],
      ),
    );
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.red)
  );
}