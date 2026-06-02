// lib/views/visites/decision_visite_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:easylocation_mvp/widgets/services_carousel_widget.dart'; 

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

  // --- ACTION : VALIDER LA LOCATION ---
  Future<void> _confirmerLocation() async {
    setState(() => _isLoader = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Mise à jour unifiée de la facture
      final factureRef = FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(widget.factureId);
      batch.update(factureRef, {
        FactureFields.confirmationLocataire: 'valide',
        'dateConfirmationLocataire': FieldValue.serverTimestamp(),
        FactureFields.etapeDossier: FactureFields.etapeVisiteTerminee, 
        'issueVisite': 'VALIDE', // Stocké directement dans le dossier principal
        if (widget.propertyId != null) 'propertyId': widget.propertyId,
      });

      await batch.commit();
      
      if (mounted) {
        _showUpsellDialog();
      }
    } catch (e) {
      _showError("Erreur lors de la validation : $e");
    } finally {
      if (mounted) setState(() => _isLoader = false);
    }
  }

  // --- ACTION : REFUSER LA LOCATION ---
  Future<void> _refuserLocation() async {
    setState(() => _isLoader = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Enregistrement du refus directement sur la facture
      final factureRef = FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(widget.factureId);
      batch.update(factureRef, {
        FactureFields.confirmationLocataire: 'refuse',
        FactureFields.motifRejet: _selectedMotif,
        'dateRefusLocataire': FieldValue.serverTimestamp(),
        FactureFields.etapeDossier: FactureFields.etapeVisiteTerminee,
        'issueVisite': 'REFUSEE', 
        if (widget.propertyId != null) 'propertyId': widget.propertyId,
      });

      await batch.commit();
      
      if (mounted) {
        Navigator.pop(context); 
        _showSuccessDialog(
          "Information enregistrée", 
          "Nous sommes désolés. Notre équipe administrative a été notifiée et va traiter votre dossier rapidement."
        );
      }
    } catch (e) {
      _showError("Erreur lors du refus : $e");
    } finally {
      if (mounted) setState(() => _isLoader = false);
    }
  }

  // --- DIALOGUE D'UPSELLING SÉCURISÉ ---
  void _showUpsellDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        contentPadding: EdgeInsets.zero, 
        content: Column(
          mainAxisSize: MainAxisSize.min, // Indique à la colonne de s'adapter à la taille de ses enfants
          children: [
            const SizedBox(height: 30),
            const Icon(Icons.celebration, size: 70, color: Colors.orangeAccent),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
              child: Text(
                "Félicitations pour votre nouveau logement !",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Text(
              "Souhaitez-vous préparer votre emménagement ?",
              style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            
            // 🎯 CORRECTIF DE DIMENSIONNEMENT : Contraintes strictes pour éviter l'erreur de dimensions intrinsèques
            SizedBox(
              height: 200, // Hauteur contrôlée pour le carrousel horizontal
              width: double.maxFinite, // Force l'occupation maximale sur la largeur disponible de la boîte
              child: const ServicesCarouselWidget(provenance: 'POST_RESERVATION'),
            ),
            
            const SizedBox(height: 10),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), 
                child: const Text("PLUS TARD", style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), 
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                child: const Text("TERMINER", style: TextStyle(color: Colors.white))
              ),
            ],
          )
        ],
      ),
    );
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _motifOption("Le bien ne correspond pas aux photos", setDialogState),
                _motifOption("Problème de propreté / état", setDialogState),
                _motifOption("Le quartier ne me convient pas", setDialogState),
                _motifOption("Autre raison", setDialogState),
              ],
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