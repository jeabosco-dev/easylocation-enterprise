// lib/screens/demande_de_visite_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Importez intl pour le formatage de la date
// 🛑 CORRECTION 1 : Importez le service qui contient la méthode
import 'package:easylocation_mvp/services/firestore_service.dart';

class DemandeDeVisitePage extends StatefulWidget {
  final String proprieteId;
  final String bailleurId;
  final String proprieteTitre;
  // NOUVEAU: Ajoutez les informations du locataire
  final String? locatairePrenom;
  final String? locataireNom;

  const DemandeDeVisitePage({
    super.key,
    required this.proprieteId,
    required this.bailleurId,
    required this.proprieteTitre,
    this.locatairePrenom,
    this.locataireNom,
  });

  @override
  State<DemandeDeVisitePage> createState() => _DemandeDeVisitePageState();
}

class _DemandeDeVisitePageState extends State<DemandeDeVisitePage> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _selectedDate; // Utilisé pour stocker la date sélectionnée

  // 🛑 CORRECTION 2 : Instanciez le service qui contient la méthode
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2028),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Veuillez vous connecter pour envoyer une demande.')),
          );
        }
        return;
      }
      
      // Vérifiez si la date a été sélectionnée
      if (_selectedDate == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Veuillez sélectionner une date de visite.')),
          );
        }
        return;
      }

      try {
        await FirebaseFirestore.instance.collection('demandes_de_visite').add({
          'proprieteId': widget.proprieteId,
          'bailleurId': widget.bailleurId,
          'locataireId': user.uid,
          'locatairePrenom': widget.locatairePrenom, // Utilisez la propriété passée
          'locataireNom': widget.locataireNom, // Utilisez la propriété passée
          'message': _messageController.text,
          'dateSouhaitee': Timestamp.fromDate(_selectedDate!), // Stockez la date comme un Timestamp
          'statut': 'en_attente_confirmation_bailleur',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 🛑 CORRECTION 3 : Appelez la méthode via l'instance du service
        await _firestoreService.logBailleurActivity(
          widget.bailleurId,
          "Nouvelle demande de visite pour votre propriété '${widget.proprieteTitre}'."
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Demande de visite envoyée avec succès !')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'envoi : $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demander une visite'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Propriété : ${widget.proprieteTitre}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _dateController,
                readOnly: true, // Empêche l'édition manuelle
                decoration: InputDecoration(
                  labelText: 'Date de visite souhaitée',
                  hintText: 'Sélectionner une date',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context),
                  ),
                ),
                validator: (value) {
                  if (_selectedDate == null) {
                    return 'Veuillez proposer une date de visite.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message au bailleur (optionnel)',
                  hintText: 'Laissez un message pour le bailleur...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitRequest,
                  icon: const Icon(Icons.send),
                  label: const Text('Envoyer la demande'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

