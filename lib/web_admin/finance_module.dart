// lib/web_admin/finance_module.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; 
import '../../services/config_service.dart'; 
import '../../services/export_service.dart';
import '../constants/constants.dart';
// Importation du nouveau widget de remboursement
import '../widgets/admin/demandes_remboursement_widget.dart';

class FinanceModule extends StatefulWidget {
  const FinanceModule({super.key});

  @override
  State<FinanceModule> createState() => _FinanceModuleState();
}

class _FinanceModuleState extends State<FinanceModule> {
  // --- ÉTAT ET FILTRES ---
  String _filterStatus = 'tous';
  String _selectedProvince = 'toutes';
  DateTimeRange? _selectedDateRange;
  
  final ScrollController _horizontalScrollController = ScrollController();
  final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$ ', decimalDigits: 2);
  
  String _adminSignature = "Admin Inconnu";

  @override
  void initState() {
    super.initState();
    _loadCurrentAdminInfo();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAdminInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.utilisateurs)
            .doc(user.uid)
            .get();
            
        if (doc.exists && mounted) {
          final data = doc.data() as Map<String, dynamic>;
          final prenom = data['prenom'] ?? "Admin";
          final email = user.email ?? "";
          setState(() => _adminSignature = "$prenom ($email)");
        }
      } catch (e) {
        debugPrint("Erreur chargement admin info: $e");
      }
    }
  }

  DateTime _parseDate(dynamic rawDate) {
    if (rawDate is Timestamp) return rawDate.toDate();
    if (rawDate is String) return DateTime.tryParse(rawDate) ?? DateTime.now();
    return DateTime.now();
  }

  // --- ACTION : VALIDATION (ARCHITECTURE EVENT-DRIVEN) ---
  Future<void> _validerPaiement(String factureId) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.factures)
          .doc(factureId)
          .update({
        FactureFields.paymentStatus: FactureFields.statusPaid, 
        FactureFields.statut: 'validated',
        FactureFields.adminValidator: _adminSignature, 
        FactureFields.dateValidationAdmin: FieldValue.serverTimestamp(),
        FactureFields.dateActionAdmin: FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Paiement validé par $_adminSignature. Le système verrouille le bien..."), 
          backgroundColor: Colors.green
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur lors de la validation: $e")));
    }
  }

  void _rejeterPaiement(String docId) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Motif du rejet"),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Ex: Image illisible ou montant incorrect...",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              try {
                await FirebaseFirestore.instance
                    .collection(FirestoreCollections.factures)
                    .doc(docId)
                    .update({
                  FactureFields.paymentStatus: FactureFields.statusRejected,
                  FactureFields.statut: 'rejected',
                  FactureFields.motifRejet: reasonController.text.trim(),
                  FactureFields.adminRejector: _adminSignature, 
                  FactureFields.dateActionAdmin: FieldValue.serverTimestamp(),
                });
                if (!mounted) return;
                Navigator.pop(ctx); 
                Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Rejeté par $_adminSignature"), backgroundColor: Colors.red),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
              }
            },
            child: const Text("CONFIRMER LE REJET", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _voirPreuvePaiement(Map<String, dynamic> data, String docId) {
    final String cadeauAffiche = data['cadeauId'] ?? data[FactureFields.cadeauChoisi] ?? data['cadeau'] ?? "Aucun";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Vérification - ${data[FactureFields.nomClient] ?? 'Client'}"),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 350, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: data[FactureFields.urlPreuve] != null 
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        data[FactureFields.urlPreuve], 
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 50),
                      ),
                    )
                  : const Icon(Icons.image_not_supported, size: 80),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Montant : ${data[FactureFields.totalUSD] ?? 0} USD", 
                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                  Text(data[FactureFields.methodePaiement] ?? "Manuel", style: const TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
              const Divider(),
              _buildDetailRow(Icons.phone, "Contact", data[FactureFields.telClient] ?? "Non renseigné"),
              _buildDetailRow(Icons.card_giftcard, "Cadeau", cadeauAffiche),
              if (data[FactureFields.refMaison] != null) 
                _buildDetailRow(Icons.home, "Réf Maison", data[FactureFields.refMaison]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => _rejeterPaiement(docId), child: const Text("REJETER", style: TextStyle(color: Colors.red))),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => _validerPaiement(docId), 
            child: const Text("VALIDER LE PAIEMENT", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text("$label : ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configService = Provider.of<ConfigService>(context);
    final double currentTaux = configService.tauxUsdCdf;
    final double globalComPercent = configService.commissionRate;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(FirestoreCollections.factures)
            .orderBy(FactureFields.dateCreation, descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Erreur de chargement"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final allDocs = snapshot.data!.docs;
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data[FactureFields.paymentStatus] ?? FactureFields.statusPending).toString();
            
            bool matchesStatus = _filterStatus == 'tous' || 
                (_filterStatus == 'en attente' ? (status == FactureFields.statusPending) : status == _filterStatus);
            
            String prov = (data[FactureFields.province] ?? 'toutes').toString().toLowerCase();
            bool matchesProvince = _selectedProvince == 'toutes' || prov == _selectedProvince.toLowerCase();

            DateTime dateDoc = _parseDate(data[FactureFields.dateCreation]);
            bool matchesDate = _selectedDateRange == null || 
                (dateDoc.isAfter(_selectedDateRange!.start) && dateDoc.isBefore(_selectedDateRange!.end.add(const Duration(days: 1))));

            return matchesStatus && matchesProvince && matchesDate;
          }).toList();

          double totalE = 0; double totalC = 0;
          for (var doc in filteredDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final pStatus = data[FactureFields.paymentStatus];
            
            if (pStatus == FactureFields.statusPaid || pStatus == FactureFields.statusCompleted) {
              totalE += (data[FactureFields.totalUSD] ?? 0).toDouble();
              double loyer = (data['loyer'] ?? 0).toDouble();
              double comPercent = (data['comLocatairePercent'] ?? globalComPercent).toDouble();
              totalC += (loyer * comPercent);
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(filteredDocs),
                const SizedBox(height: 20),
                _buildTauxControl(currentTaux), 
                const SizedBox(height: 25),
                _buildStats(totalE, totalC),
                const SizedBox(height: 32),
                
                // --- SECTION REMBOURSEMENTS ---
                // Ajout du widget ici pour qu'il apparaisse avant l'historique général
                const DemandesRemboursementWidget(),
                
                const SizedBox(height: 40),
                const Text("Historique des Factures de Services", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const Divider(),
                const SizedBox(height: 16),
                _buildFilterBar(),
                const SizedBox(height: 16),
                _buildTable(filteredDocs),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTauxControl(double taux) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.currency_exchange, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Text("Taux Actuel : 1 USD = ${taux.toStringAsFixed(0)} CDF", style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: 15, runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActionChip(
          onPressed: _selectDateRange,
          backgroundColor: Colors.white,
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: Text(_selectedDateRange == null ? "Période" : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}"),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedProvince,
              items: ['toutes', 'Kinshasa', 'Lualaba', 'Haut-Katanga', 'Sud-Kivu'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (val) => setState(() => _selectedProvince = val!),
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            _choiceTab('tous', 'tous'),
            _choiceTab(FactureFields.statusPaid, 'VALIDÉS'),
            _choiceTab('en attente', 'PENDING'),
            _choiceTab(FactureFields.statusRejected, 'REJETÉS'),
          ],
        ),
      ],
    );
  }

  Widget _choiceTab(String value, String label) {
    return ChoiceChip(
      label: Text(label.toUpperCase(), style: const TextStyle(fontSize: 11)),
      selected: _filterStatus == value,
      onSelected: (val) => setState(() => _filterStatus = value),
    );
  }

  Widget _buildTable(List<QueryDocumentSnapshot> docs) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Scrollbar(
        controller: _horizontalScrollController, 
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalScrollController, 
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('DATE')),
              DataColumn(label: Text('CLIENT & CONTACT')),
              DataColumn(label: Text('MONTANT')),
              DataColumn(label: Text('STATUT')),
              DataColumn(label: Text('ACTION / VALIDATEUR')),
            ],
            rows: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = (data[FactureFields.paymentStatus] ?? FactureFields.statusPending).toString();
              final isDone = status == FactureFields.statusPaid || status == FactureFields.statusCompleted;
              final isRejected = status == FactureFields.statusRejected;

              return DataRow(cells: [
                DataCell(Text(DateFormat('dd/MM/yy').format(_parseDate(data[FactureFields.dateCreation])))),
                DataCell(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(data[FactureFields.nomClient] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(data[FactureFields.telClient] ?? '-', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  ],
                )),
                DataCell(Text("${data[FactureFields.totalUSD]}\$", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                DataCell(_buildStatusChip(status)),
                DataCell(isDone || isRejected 
                  ? Text(data[FactureFields.adminValidator] ?? data[FactureFields.adminRejector] ?? "-", style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic))
                  : ElevatedButton.icon(
                      onPressed: () => _voirPreuvePaiement(data, doc.id), 
                      icon: const Icon(Icons.remove_red_eye, size: 14),
                      label: const Text("Vérifier"),
                    )
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.orange;
    if (status == FactureFields.statusPaid || status == FactureFields.statusCompleted) color = Colors.green;
    if (status == FactureFields.statusRejected) color = Colors.red;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildHeader(List<QueryDocumentSnapshot> docs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Suivi des Finances", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ElevatedButton.icon(
          onPressed: () => _export(docs),
          icon: const Icon(Icons.download),
          label: const Text("Exporter Excel"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
        ),
      ],
    );
  }

  Widget _buildStats(double e, double c) {
    return Wrap(
      spacing: 16, runSpacing: 16,
      children: [
        _statCard("TOTAL ENCAISSÉ (VALIDÉ)", currencyFormat.format(e), Icons.monetization_on, Colors.green),
        _statCard("ESTIMATION COMMISSIONS", currencyFormat.format(c), Icons.account_balance_wallet, Colors.blue),
      ],
    );
  }

  Widget _statCard(String t, String v, IconData icon, Color col) {
    return Container(
      width: 280, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: col.withOpacity(0.1), child: Icon(icon, color: col)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context, 
      firstDate: DateTime(2024), 
      lastDate: DateTime.now().add(const Duration(days: 1))
    );
    if (picked != null) setState(() => _selectedDateRange = picked);
  }

  void _export(List<QueryDocumentSnapshot> docs) {
    ExportService.exportPropertiesToExcel(
      docs: docs, 
      fileName: "Rapport_Finance_${DateFormat('dd_MM_yyyy').format(DateTime.now())}", 
      sheetName: "Transactions",
      headers: ['DATE', 'CLIENT', 'TELEPHONE', 'TOTAL USD', 'STATUT', 'ADMIN'],
      keys: [
        FactureFields.dateCreation, 
        FactureFields.nomClient, 
        FactureFields.telClient, 
        FactureFields.totalUSD, 
        FactureFields.paymentStatus, 
        FactureFields.adminValidator
      ],
    );
  }
}