// lib/widgets/service_payment_sheet.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_model.dart';
import '../models/facture_model.dart';
import '../services/maxicash_service.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import '../utils/ui_utils.dart';
import 'manuel_payment_sheet.dart'; 
import 'cash_payment_instruction_sheet.dart';

class ServicePaymentSheet extends StatefulWidget {
  final ServiceModel commande; // La commande déjà créée dans Firestore
  final String serviceName;

  const ServicePaymentSheet({
    super.key, 
    required this.commande, 
    required this.serviceName
  });

  @override
  State<ServicePaymentSheet> createState() => _ServicePaymentSheetState();
}

class _ServicePaymentSheetState extends State<ServicePaymentSheet> {
  bool _isProcessing = false;

  /// Met à jour le statut de la commande de service dans Firestore
  Future<void> _updateStatus(String status, String etape) async {
    await FirebaseFirestore.instance
        .collection(FirestoreCollections.services) 
        .doc(widget.commande.id)
        .update({
      'statut': status,
      'etapeDossier': etape,
      'dateUpdate': FieldValue.serverTimestamp(),
    });
  }

  void _handlePayment(String methode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      if (methode == "maxicash") {
        // --- OPTION 1 : MAXICASH (Automatique) ---
        await MaxicashService.encaisserAcompte(
          context: context,
          telephone: widget.commande.locataireTel ?? "", 
          referenceCommande: widget.commande.id,
          montant: widget.commande.prix,
          // ✅ DYNAMIQUE : Utilise la ville de la commande ou la ville par défaut du projet
          ville: widget.commande.ville ?? AppLocations.defaultCity, 
          onSuccess: () async {
            await _updateStatus('PAYE', 'confirmé');
            if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          },
          onCancel: () => setState(() => _isProcessing = false),
        );
      } 
      else if (methode == "manuel") {
        // --- OPTION 2 : MANUEL (Mobile Money / Screenshot) ---
        if (mounted) Navigator.pop(context);
        
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ManuelPaymentSheet(
            propertyId: widget.commande.id, // 👈 ID DE LA COMMANDE UTILISÉ
            facture: FactureModel(
              propertyId: widget.commande.id, 
              refMaison: widget.serviceName,
              clientId: widget.commande.locataireId, 
              nomClient: widget.commande.nomClient ?? "Client Service", 
              telClient: widget.commande.locataireTel ?? "N/A",
              nomOffre: "Prestation : ${widget.serviceName}",
              loyer: widget.commande.prix,
              comLocatairePercent: 0,
              comBailleurPercent: 0,
            ), 
            montantFinal: widget.commande.prix,
            devise: "USD",
            docId: widget.commande.id,
            target: PaymentTarget.service,
          ),
        );
      } 
      else if (methode == "cash") {
        // --- OPTION 3 : CASH (Au bureau) ---
        await _updateStatus('COMMANDE', 'en_attente_cash');
        if (mounted) {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => CashPaymentInstructionSheet(
              // ✅ Passage de l'objet facture complet via toFacture()
              facture: widget.commande.toFacture(
                propertyId: null, // Service externe
                nomClient: widget.commande.nomClient,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) UIUtils.showSnackBar(context, "Erreur de traitement : $e", isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4, 
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))
          ),
          const Text("Règlement du service", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            "${widget.serviceName} : ${widget.commande.prix.toStringAsFixed(2)} \$", 
            style: const TextStyle(color: Color(0xFF0D47A1), fontSize: 16, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 24),
          
          if (_isProcessing) 
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: CircularProgressIndicator(),
            )
          else ...[
            _buildOption(
              Icons.bolt, 
              Colors.blue, 
              "MaxiCash (Recommandé)", 
              "Paiement automatique & instantané", 
              () => _handlePayment("maxicash")
            ),
            const SizedBox(height: 12),
            _buildOption(
              Icons.phone_android, 
              Colors.green, 
              "Mobile Money", 
              "Envoyer une preuve (M-Pesa, Airtel, Orange)", 
              () => _handlePayment("manuel")
            ),
            const SizedBox(height: 12),
            _buildOption(
              Icons.payments, 
              Colors.orange, 
              "Paiement Cash", 
              "Passer au bureau EasyLocation", 
              () => _handlePayment("cash")
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildOption(IconData icon, Color color, String title, String sub, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade100), 
        borderRadius: BorderRadius.circular(15)
      ),
      tileColor: Colors.grey.shade50,
    );
  }
}