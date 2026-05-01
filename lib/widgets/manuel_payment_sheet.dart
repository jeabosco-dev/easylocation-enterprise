import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/facture_model.dart';
import '../services/config_service.dart';
import 'package:easylocation_mvp/constants/constants.dart';

/// Définit si le paiement concerne une location immobilière ou un service ponctuel
enum PaymentTarget { location, service }

class ManuelPaymentSheet extends StatefulWidget {
  final FactureModel facture;
  final double montantFinal; // Reste à payer après déduction wallet
  final String devise;
  final String? docId;
  final double portionWallet;
  final PaymentTarget target; 

  const ManuelPaymentSheet({
    super.key,
    required this.facture,
    required this.montantFinal,
    required this.devise,
    this.portionWallet = 0.0,
    this.docId,
    this.target = PaymentTarget.location, 
  });

  @override
  State<ManuelPaymentSheet> createState() => _ManuelPaymentSheetState();
}

class _ManuelPaymentSheetState extends State<ManuelPaymentSheet> {
  File? _imageFile;
  bool _isUploading = false;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? "unknown";

  // --- ACTIONS ---

  void _copyToClipboard(String number, String provider) {
    Clipboard.setData(ClipboardData(text: number));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Numéro $provider copié !"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

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
      // 1. Définition du dossier Storage selon la cible
      String folder = widget.target == PaymentTarget.location ? 'preuves_locations' : 'preuves_services';
      String timestampStr = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = '$folder/$_userId/${timestampStr}.jpg';

      // 2. Upload vers Firebase Storage
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(_imageFile!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // 3. Préparation des données Firestore (Clés agnostiques pour la compatibilité)
      final Map<String, dynamic> updateData = {
        'urlPreuve': downloadUrl,
        'paymentStatus': 'pending',
        'statut': widget.target == PaymentTarget.service ? 'COMMANDE' : 'pending',
        'methodePaiement': 'manuel (mobile money)',
        'dateUpdate': FieldValue.serverTimestamp(),
        'montantWallet': widget.portionWallet,
        'montantExterne': widget.montantFinal,
      };

      // 4. Choix de la collection cible
      String collectionTarget = widget.target == PaymentTarget.location 
          ? FirestoreCollections.factures 
          : FirestoreCollections.services; 

      if (widget.docId != null) {
        // Mise à jour directe (Cas des Services ou Factures avec ID connu)
        await FirebaseFirestore.instance
            .collection(collectionTarget)
            .doc(widget.docId)
            .update(updateData);
      } else if (widget.target == PaymentTarget.location) {
        // Recherche par critères (Spécifique aux locations sans ID direct)
        final querySnapshot = await FirebaseFirestore.instance
            .collection(collectionTarget)
            .where('propertyId', isEqualTo: widget.facture.propertyId)
            .where('clientId', isEqualTo: _userId)
            .where('paymentStatus', isEqualTo: 'pending')
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // Mise à jour de la facture existante
          await querySnapshot.docs.first.reference.update(updateData);
        } else {
          // ✅ CRÉATION FORCÉE (SÉCURISÉE POUR LES STATS)
          // On injecte explicitement les données de localisation dans le copyWith
          final Map<String, dynamic> dataMap = widget.facture.copyWith(
            urlPreuve: downloadUrl,
            paymentStatus: 'pending',
            ville: widget.facture.ville,
            commune: widget.facture.commune,
            villeSpecifique: widget.facture.villeSpecifique,
            communeSpecifique: widget.facture.communeSpecifique,
          ).toMap();

          dataMap['clientId'] = _userId;
          await FirebaseFirestore.instance.collection(collectionTarget).add(dataMap);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigService>(context);
    final accounts = config.paymentAccounts;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))
                ),
                const SizedBox(height: 15),
                Text(
                  widget.target == PaymentTarget.location ? "Paiement Loyer/Caution" : "Paiement de Service",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                const SizedBox(height: 15),

                _buildInstructionStep("1", "Envoyez exactement ${widget.montantFinal.toStringAsFixed(2)} ${widget.devise}"),

                if (widget.portionWallet > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 4),
                    child: Text(
                      "(Votre Wallet couvre déjà ${widget.portionWallet.toStringAsFixed(2)} ${widget.devise})",
                      style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),

                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade900, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Pensez à inclure les frais d'envoi pour que nous recevions le montant net.",
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                ...accounts.entries.map((entry) {
                  String network = entry.key;
                  String number = entry.value['number'] ?? "";
                  String name = entry.value['name'] ?? "";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(network.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 12)),
                              Text(number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(name, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20, color: Color(0xFF0D47A1)),
                          onPressed: () => _copyToClipboard(number, network),
                          tooltip: "Copier",
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 15),
                _buildInstructionStep("2", "Capturez le SMS de confirmation."),
                const SizedBox(height: 15),
                _buildInstructionStep("3", "Chargez la capture d'écran :"),
                const SizedBox(height: 10),

                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: _imageFile == null ? Colors.grey.shade300 : Colors.green.shade400, width: 2),
                    ),
                    child: _imageFile == null
                        ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.grey),
                        Text("Cliquer pour choisir l'image", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.file(_imageFile!, fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: (_imageFile == null || _isUploading) ? null : _envoyerPreuve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("VALIDER MON PAIEMENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        content: Text(widget.target == PaymentTarget.service 
          ? "Votre demande de service a été transmise.\n\nUn administrateur va valider votre transaction sous peu."
          : "Votre preuve de paiement a été transmise.\n\nUn administrateur va valider votre transaction sous peu."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).popUntil((r) => r.isFirst),
              child: const Text("OK")
          )
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String step, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10, backgroundColor: const Color(0xFF0D47A1),
          child: Text(step, style: const TextStyle(fontSize: 10, color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
      ],
    );
  }
}