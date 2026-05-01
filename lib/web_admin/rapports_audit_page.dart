import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/export_service.dart';
import '../constants/constants.dart';

class RapportsAuditPage extends StatefulWidget {
  const RapportsAuditPage({super.key});

  @override
  State<RapportsAuditPage> createState() => _RapportsAuditPageState();
}

class _RapportsAuditPageState extends State<RapportsAuditPage> {
  DateTimeRange? _selectedDateRange;
  String _adminSignature = "Admin";
  final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$ ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    // Par défaut, on affiche les 30 derniers jours
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
  }

  Future<void> _loadAdminInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
      if (doc.exists) {
        setState(() => _adminSignature = "${doc.data()?['prenom']} (${user.email})");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('refund_requests')
            .where('status', isEqualTo: 'paye')
            .orderBy('paidAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Erreur de chargement des données d'audit"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Filtrage par date côté client pour plus de flexibilité
          final allPaidDocs = snapshot.data!.docs;
          final filteredDocs = allPaidDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['paidAt'] == null) return false;
            DateTime paidDate = (data['paidAt'] as Timestamp).toDate();
            return paidDate.isAfter(_selectedDateRange!.start) && 
                   paidDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
          }).toList();

          double totalSortie = 0;
          for (var doc in filteredDocs) {
            totalSortie += (doc['amount'] ?? 0).toDouble();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(filteredDocs),
                const SizedBox(height: 25),
                _buildStats(totalSortie, filteredDocs.length),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Historique immuable des décaissements", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    _buildDateFilter(),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                _buildAuditTable(filteredDocs),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(List<QueryDocumentSnapshot> docs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Rapports & Audit Financier", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text("Généré par : $_adminSignature", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _exportAudit(docs),
          icon: const Icon(Icons.file_download),
          label: const Text("Exporter l'Audit (Excel)"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[800],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ],
    );
  }

  Widget _buildStats(double total, int count) {
    return Wrap(
      spacing: 16,
      children: [
        _statCard("TOTAL DÉCAISSÉ (PÉRIODE)", currencyFormat.format(total), Icons.account_balance_wallet, Colors.redAccent),
        _statCard("NOMBRE DE REMBOURSEMENTS", count.toString(), Icons.receipt_long, Colors.blue),
      ],
    );
  }

  Widget _statCard(String t, String v, IconData icon, Color col) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: col.withOpacity(0.1), child: Icon(icon, color: col)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    return ActionChip(
      onPressed: () async {
        final picked = await showDateRangePicker(
          context: context, 
          firstDate: DateTime(2024), 
          lastDate: DateTime.now()
        );
        if (picked != null) setState(() => _selectedDateRange = picked);
      },
      backgroundColor: Colors.white,
      avatar: const Icon(Icons.calendar_month, size: 16),
      label: Text("${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}"),
    );
  }

  Widget _buildAuditTable(List<QueryDocumentSnapshot> docs) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
        columns: const [
          DataColumn(label: Text('DATE PAIEMENT')),
          DataColumn(label: Text('BÉNÉFICIAIRE')),
          DataColumn(label: Text('MÉTHODE')),
          DataColumn(label: Text('MONTANT')),
          DataColumn(label: Text('VALIDÉ PAR')),
        ],
        rows: docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return DataRow(cells: [
            DataCell(Text(DateFormat('dd/MM/yyyy HH:mm').format((data['paidAt'] as Timestamp).toDate()))),
            DataCell(Text(data['userName'] ?? 'Client')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(data['paymentMethod'] == 'office' ? Icons.business : Icons.phone_android, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                Text(data['paymentMethod'] == 'office' ? "Caisse Bureau" : "Mobile Money"),
              ],
            )),
            DataCell(Text("${data['amount']} \$", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
            DataCell(Text(data['processedBy'] ?? 'Automatique', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 11))),
          ]);
        }).toList(),
      ),
    );
  }

  void _exportAudit(List<QueryDocumentSnapshot> docs) {
    ExportService.exportPropertiesToExcel(
      docs: docs,
      fileName: "Audit_Decaissements_EasyLocation_${DateFormat('dd_MM_yyyy').format(DateTime.now())}",
      sheetName: "Remboursements Payés",
      headers: ['DATE PAIEMENT', 'NOM CLIENT', 'MONTANT USD', 'METHODE', 'RESPONSABLE'],
      keys: ['paidAt', 'userName', 'amount', 'paymentMethod', 'processedBy'],
    );
  }
}