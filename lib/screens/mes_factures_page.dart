import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; 
import 'package:rxdart/rxdart.dart'; 
import '../models/facture_model.dart';
import '../widgets/manuel_payment_sheet.dart';
import '../services/pdf_service.dart';
import '../services/config_service.dart';
import '../constants/all_constants.dart'; // Import des constantes

class MesFacturesPage extends StatefulWidget {
  final String? contractId;

  const MesFacturesPage({super.key, this.contractId});

  @override
  State<MesFacturesPage> createState() => _MesFacturesPageState();
}

class _MesFacturesPageState extends State<MesFacturesPage> {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  final ScrollController _scrollController = ScrollController();
  
  final Map<String, GlobalKey> _cardKeys = {};
  
  bool _isProcessing = false;
  String? _highlightedId;

  @override
  void initState() {
    super.initState();
    _highlightedId = widget.contractId;

    if (_highlightedId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTargetCard());
      
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _highlightedId = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTargetCard() {
    final targetKey = _cardKeys[widget.contractId];
    if (targetKey != null && targetKey.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey.currentContext!,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _ouvrirPaiement(Map<String, dynamic> data, String docId, PaymentTarget target) {
    final facture = (target == PaymentTarget.service)
        ? FactureModel.fromServiceMap(data, docId)
        : FactureModel.fromMap(data, docId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManuelPaymentSheet(
        facture: facture,
        montantFinal: (data[FactureFields.totalUSD] ?? (data['montantTotal'] ?? 0)).toDouble(),
        devise: "USD",
        docId: docId,
        target: target,
      ),
    );
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

  // ✅ Stream corrigé avec les constantes
  Stream<List<QueryDocumentSnapshot>> getCombinedStream() {
    var streamFactures = FirebaseFirestore.instance
        .collection(FirestoreCollections.factures)
        .where(FactureFields.clientId, isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs);

    var streamServices = FirebaseFirestore.instance
        .collection(FirestoreCollections.services)
        .where(FactureFields.clientId, isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs);

    return CombineLatestStream.combine2(
      streamFactures,
      streamServices,
      (List<QueryDocumentSnapshot> factures, List<QueryDocumentSnapshot> services) {
        List<QueryDocumentSnapshot> combined = [...factures, ...services];
        
        combined.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;
          Timestamp t1 = (dataA[FactureFields.dateCreation] as Timestamp?) ?? Timestamp.now();
          Timestamp t2 = (dataB[FactureFields.dateCreation] as Timestamp?) ?? Timestamp.now();
          return t2.compareTo(t1);
        });
        return combined;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigService>();

    if (userId == null) {
      return const Scaffold(body: Center(child: Text("Connectez-vous pour voir votre historique")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Tableau de Bord Paiements",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: getCombinedStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final allDocs = snapshot.data!;

          if (widget.contractId != null && _cardKeys.containsKey(widget.contractId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTargetCard());
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: allDocs.length,
            itemBuilder: (context, index) {
              final doc = allDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              bool isService = doc.reference.path.contains(FirestoreCollections.services);
              
              final String currentDocId = doc.id;
              final String? currentContractId = data['contractId']?.toString();
              
              final String targetIdentifier = currentContractId ?? currentDocId;
              final cardKey = _cardKeys.putIfAbsent(targetIdentifier, () => GlobalKey());

              bool isTarget = (_highlightedId != null && 
                  (_highlightedId == currentContractId || _highlightedId == currentDocId));

              return Container(
                key: cardKey,
                child: _buildTransactionCard(data, currentDocId, config, isService, isTarget),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> data, String docId, ConfigService config, bool isService, bool isTarget) {
    final String status = (data[FactureFields.paymentStatus] ?? '').toString().toLowerCase();
    final String? urlPreuve = data[FactureFields.urlPreuve] ?? data['urlPreuvePaiement'];
    
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

    IconData typeIcon = isService ? Icons.build_circle_outlined : Icons.home_work_outlined;
    double montantAffiche = (data[FactureFields.totalUSD] ?? (data['montantTotal'] ?? 0.0)).toDouble();
    double cashback = (data[FactureFields.montantCashback] ?? 0.0).toDouble();

    BorderSide cardBorder;
    if (isTarget) {
      cardBorder = const BorderSide(color: Colors.amber, width: 2.5);
    } else {
      cardBorder = BorderSide(color: isService ? Colors.blue.shade100 : Colors.grey.shade200, width: isService ? 1.5 : 1);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: isTarget ? [
          BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)
        ] : [],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: isTarget ? 3 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: cardBorder,
        ),
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
                      color: isService ? Colors.blue.shade700 : Colors.blueGrey.shade700,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Icon(typeIcon, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          isService ? "SERVICE" : "LOYER",
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Text(_formatDate(data[FactureFields.dateCreation]),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  _buildStatusBadge(statusColor, statusIcon, statusLabel),
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
                        Text("${montantAffiche.toStringAsFixed(2)} \$ USD",
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                        
                        if (cashback > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text("-${cashback.toStringAsFixed(2)} \$ (Bonus)", 
                                 style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),

                        const SizedBox(height: 4),
                        Text(isService 
                          ? "Prestation : ${data['serviceType'] ?? 'Service divers'}" 
                          : "Période : ${data['periodePaiement'] ?? 'N/A'}",
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 13)),
                        Text("Réf : ${data[FactureFields.refMaison] ?? data['commandeRef'] ?? 'N/A'}",
                            style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                  
                  if (isValidated && !isService)
                    TextButton.icon(
                      onPressed: _isProcessing ? null : () {
                        setState(() => _isProcessing = true);
                        try {
                          final facture = FactureModel.fromMap(data, docId);
                          PdfService.afficherOptionsFacture(context, facture, config.companyInfo);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur PDF: $e")));
                          }
                        } finally {
                          if (mounted) setState(() => _isProcessing = false);
                        }
                      },
                      icon: _isProcessing 
                          ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                          : const Icon(Icons.description_outlined, color: Colors.green, size: 18),
                      label: const Text("REÇU PDF", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.green.shade50,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),

              if (isRejected) _buildRejectionSection(data, docId, isService ? PaymentTarget.service : PaymentTarget.location),
              if (isUnderReview) _buildPendingSection(data[FactureFields.methodePaiement] ?? 'manuel'),
              
              if (isWaitingForPayment) ...[
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _ouvrirPaiement(data, docId, isService ? PaymentTarget.service : PaymentTarget.location),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text("PAYER MAINTENANT"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isService ? Colors.blue.shade900 : const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingSection(String method) {
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

  Widget _buildRejectionSection(Map<String, dynamic> data, String docId, PaymentTarget target) {
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
            onPressed: () => _ouvrirPaiement(data, docId, target),
            icon: const Icon(Icons.edit_document, size: 18),
            label: const Text("CORRIGER ET RENVOYER"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, 
              foregroundColor: Colors.white, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("Aucune transaction trouvée.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}