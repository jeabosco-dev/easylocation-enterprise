// lib/widgets/transaction_card_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/facture_model.dart';
import '../models/payment_target.dart';
import '../services/pdf_service.dart';
import '../constants/all_constants.dart';

class TransactionCardWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final dynamic config; // ConfigService
  final bool isService;
  final bool isTarget;
  final Function(Map<String, dynamic> data, String docId, PaymentTarget target) onOpenPayment;

  const TransactionCardWidget({
    super.key,
    required this.data,
    required this.docId,
    required this.config,
    required this.isService,
    required this.isTarget,
    required this.onOpenPayment,
  });

  @override
  State<TransactionCardWidget> createState() => _TransactionCardWidgetState();
}

class _TransactionCardWidgetState extends State<TransactionCardWidget> {
  bool _isProcessing = false;

  Future<void> _confirmerEtSupprimer(BuildContext context) async {
    final bool? confirmer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer la transaction"),
        content: const Text("Voulez-vous vraiment supprimer cette facture de votre historique ? Cette action est irréversible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmer == true) {
      try {
        final collectionName = widget.isService ? FirestoreCollections.services : FirestoreCollections.factures;
        await FirebaseFirestore.instance.collection(collectionName).doc(widget.docId).delete();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Facture supprimée avec succès."), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur lors de la suppression : $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _formatDate(dynamic rawDate) {
    try {
      if (rawDate == null) return "Date inconnue";
      if (rawDate is Timestamp) {
        return DateFormat('dd/MM/yyyy HH:mm').format(rawDate.toDate());
      }
      return "---";
    } catch (e) {
      return "---";
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = (widget.data[FactureFields.paymentStatus] ?? '').toString().toLowerCase();
    final String? urlPreuve = widget.data[FactureFields.urlPreuve] ?? widget.data['urlPreuvePaiement'];
    
    final bool isValidated = ['paid', 'validé', 'valide', 'completed', 'success'].contains(status);
    final bool isRejected = status.contains('reject') || status.contains('rejeté') || status.contains('failed');
    final bool isWaitingForPayment = status == 'pending' && (urlPreuve == null || urlPreuve.isEmpty);
    final bool isUnderReview = status == 'pending' && (urlPreuve != null && urlPreuve.isNotEmpty);

    Color statusColor = Colors.orange;
    String statusLabel = "EN ATTENTE";
    IconData statusIcon = Icons.access_time_rounded;

    if (isValidated) {
      statusColor = Colors.green;
      statusLabel = "VALIDÉ";
      statusIcon = Icons.verified_rounded;
    } else if (isRejected) {
      statusColor = Colors.red;
      statusLabel = "REJETÉ";
      statusIcon = Icons.error_outline_rounded;
    } else if (isWaitingForPayment) {
      statusColor = Colors.blueGrey;
      statusLabel = "À PAYER";
      statusIcon = Icons.pending_actions_rounded;
    }

    IconData typeIcon = widget.isService ? Icons.build_circle_outlined : Icons.home_work_outlined;
    
    double montantAffiche = (widget.data['totalNetUSD'] ?? (widget.data[FactureFields.totalUSD] ?? (widget.data['montantTotal'] ?? 0.0))).toDouble();
    double cashback = (widget.data[FactureFields.montantCashback] ?? 0.0).toDouble();

    BorderSide cardBorder = widget.isTarget 
        ? const BorderSide(color: Colors.amber, width: 2.5) 
        : BorderSide(color: widget.isService ? Colors.blue.shade100 : Colors.grey.shade200, width: widget.isService ? 1.5 : 1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: widget.isTarget ? [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)] : [],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: widget.isTarget ? 3 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: cardBorder),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.isService ? Colors.blue.shade700 : Colors.blueGrey.shade700,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Icon(typeIcon, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(widget.isService ? "SERVICE" : "LOYER", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Text(_formatDate(widget.data[FactureFields.dateCreation]), style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusBadge(statusColor, statusIcon, statusLabel),
                      const SizedBox(width: 4),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade500),
                        tooltip: "Supprimer la facture",
                        onPressed: () => _confirmerEtSupprimer(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${montantAffiche.toStringAsFixed(2)} \$ USD", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                        if (cashback > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text("-${cashback.toStringAsFixed(2)} \$ (Bonus)", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(height: 4),
                        Text(widget.isService ? "Prestation : ${widget.data['serviceType'] ?? 'Service divers'}" : "Période : ${widget.data['periodePaiement'] ?? 'N/A'}", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 13)),
                        Text("Réf : ${widget.data[FactureFields.refMaison] ?? widget.data['commandeRef'] ?? 'N/A'}", style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (isValidated && !widget.isService)
                    TextButton.icon(
                      onPressed: _isProcessing ? null : () async {
                        setState(() => _isProcessing = true);
                        try {
                          final facture = FactureModel.fromMap(widget.data, widget.docId);
                          PdfService.afficherOptionsFacture(context, facture, widget.config.companyInfo);
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur PDF: $e")));
                        } finally {
                          if (mounted) setState(() => _isProcessing = false);
                        }
                      },
                      icon: _isProcessing ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)) : const Icon(Icons.description_outlined, color: Colors.green, size: 18),
                      label: const Text("REÇU PDF", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: TextButton.styleFrom(backgroundColor: Colors.green.shade50, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                ],
              ),
              if (isRejected) _buildRejectionSection(context, widget.data, widget.docId, widget.isService ? PaymentTarget.service : PaymentTarget.location),
              if (isUnderReview) _buildPendingSection(),
              if (isWaitingForPayment) ...[
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => widget.onOpenPayment(widget.data, widget.docId, widget.isService ? PaymentTarget.service : PaymentTarget.location),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text("PAYER MAINTENANT"),
                    style: ElevatedButton.styleFrom(backgroundColor: widget.isService ? Colors.blue.shade900 : const Color(0xFF1A237E), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text("Vérification en cours par nos agents.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.orange, fontSize: 11))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildRejectionSection(BuildContext context, Map<String, dynamic> data, String docId, PaymentTarget target) {
    return Column(
      children: [
        const SizedBox(height: 15),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade100)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Motif du rejet :", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12)),
              const SizedBox(height: 4),
              Text(data[FactureFields.motifRejet] ?? "Preuve non conforme.", style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => widget.onOpenPayment(data, docId, target),
            icon: const Icon(Icons.edit_document, size: 18),
            label: const Text("CORRIGER ET RENVOYER"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ),
      ],
    );
  }
}