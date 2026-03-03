import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/facture_model.dart';
import 'package:easylocation_mvp/constants/constants.dart';

class ManuelPaymentSheet extends StatefulWidget {
  final FactureModel facture;
  final double montantFinal;
  final String devise;
  final String? docId; // Toujours utile pour la correction de rejet

  const ManuelPaymentSheet({
    super.key,
    required this.facture,
    required this.montantFinal,
    required this.devise,
    this.docId,
  });

  @override
  State<ManuelPaymentSheet> createState() => _ManuelPaymentSheetState();
}

class _ManuelPaymentSheetState extends State<ManuelPaymentSheet> {
  File? _imageFile;
  bool _isUploading = false;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? "unknown";

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60, 
      maxWidth: 1080, 
    );
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _envoyerPreuve() async {
    if (_imageFile == null) return;

    setState(() => _isUploading = true);

    try {
      // 1. Upload de l'image
      String timestampStr = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = 'preuves/$_userId/${timestampStr}_${widget.facture.refMaison}.jpg';
      
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(_imageFile!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      const String statutInitial = 'pending';

      // 2. Recherche du document existant ou création
      // On cherche si une facture pour ce bien et ce client existe déjà en 'pending'
      final querySnapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.factures)
          .where('propertyId', isEqualTo: widget.facture.propertyId)
          .where('clientId', isEqualTo: _userId)
          .where(FactureFields.statut, isEqualTo: 'pending')
          .limit(1)
          .get();

      if (widget.docId != null || querySnapshot.docs.isNotEmpty) {
        // --- CAS A : MISE À JOUR (Facture déjà créée par FacturePage ou correction) ---
        String idToUpdate = widget.docId ?? querySnapshot.docs.first.id;
        
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.factures)
            .doc(idToUpdate)
            .update({
          FactureFields.urlPreuve: downloadUrl,
          FactureFields.statut: statutInitial,
          FactureFields.paymentStatus: statutInitial,
          'methodePaiement': 'Manuel (Mobile Money)',
          'dateUpdate': FieldValue.serverTimestamp(),
          FactureFields.motifRejet: FieldValue.delete(), 
        });
      } else {
        // --- CAS B : SECURITÉ (Si jamais la facture n'a pas été créée avant) ---
        final Map<String, dynamic> factureMap = widget.facture.copyWith(
          clientId: _userId,
          statut: statutInitial,
          urlPreuve: downloadUrl,
          methodePaiement: 'Manuel (Mobile Money)',
          dateCreation: FieldValue.serverTimestamp(),
        ).toMap();

        factureMap[FactureFields.paymentStatus] = statutInitial;

        await FirebaseFirestore.instance
            .collection(FirestoreCollections.factures)
            .add(factureMap);
      }

      if (mounted) {
        Navigator.pop(context); 
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'envoi : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text("Demande envoyée"),
          ],
        ),
        content: const Text(
          "Votre preuve de paiement a été transmise.\n\n"
          "Un administrateur va valider votre transaction sous peu. Vous recevrez une notification.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("RETOUR À L'ACCUEIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // On garde ton interface actuelle qui est parfaite
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 15),
              Text(
                widget.docId != null ? "Mettre à jour la preuve" : "Paiement Mobile Money",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const SizedBox(height: 15),
              _buildInstructionStep("1", "Envoyez ${widget.montantFinal.toStringAsFixed(2)} ${widget.devise} au numéro :"),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50, 
                  borderRadius: BorderRadius.circular(10), 
                  border: Border.all(color: Colors.blue.shade100)
                ),
                child: const SelectableText(
                  "M-Pesa : +243 97 21 29 520\nOrange : +243 89 00 00 000", 
                  textAlign: TextAlign.center, 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D47A1)),
                ),
              ),
              _buildInstructionStep("2", "Prenez une capture d'écran nette de la confirmation reçue par SMS."),
              const SizedBox(height: 15),
              _buildInstructionStep("3", "Chargez l'image ici :"),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _imageFile == null ? Colors.grey.shade300 : Colors.green.shade400, 
                      width: 2,
                    ),
                  ),
                  child: _imageFile == null 
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text("Cliquer pour choisir l'image", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.file(_imageFile!, fit: BoxFit.contain),
                      ),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: (_imageFile == null || _isUploading) ? null : _envoyerPreuve,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isUploading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : Text(
                        widget.docId != null ? "METTRE À JOUR LA PREUVE" : "VALIDER MON PAIEMENT", 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String step, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10, 
          backgroundColor: const Color(0xFF0D47A1), 
          child: Text(step, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.2))),
      ],
    );
  }
}