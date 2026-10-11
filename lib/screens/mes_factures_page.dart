// lib/screens/mes_factures_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; 
import 'package:rxdart/rxdart.dart'; 
import '../models/facture_model.dart';
import '../models/payment_target.dart';
import '../widgets/manuel_payment_sheet.dart';
import '../widgets/transaction_card_widget.dart'; // ✅ Import du nouveau widget
import '../services/config_service.dart';
import '../constants/all_constants.dart';

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
        propertyId: facture.propertyId,
        facture: facture,
        montantFinal: (data['totalNetUSD'] ?? (data[FactureFields.totalUSD] ?? (data['montantTotal'] ?? 0))).toDouble(),
        devise: "USD",
        docId: docId,
        target: target,
      ),
    );
  }

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
                child: TransactionCardWidget(
                  data: data,
                  docId: currentDocId,
                  config: config,
                  isService: isService,
                  isTarget: isTarget,
                  onOpenPayment: _ouvrirPaiement,
                ),
              );
            },
          );
        },
      ),
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