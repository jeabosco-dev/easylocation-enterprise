// lib/web_admin/finance_module.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/export_service.dart';

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

  /// MISE À JOUR : Utilise maintenant la collection 'utilisateurs' pour l'identité
  Future<void> _loadCurrentAdminInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('utilisateurs') // Harmonisé avec le Login
            .doc(user.uid)
            .get();
            
        if (doc.exists && mounted) {
          final data = doc.data() as Map<String, dynamic>;
          final prenom = data['prenom'] ?? "Admin"; // Structure simplifiée
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

  // --- ACTIONS : REJET ET VALIDATION ---

  void _rejeterPaiement(String docId) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Motif du rejet"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: "Ex: Image floue ou montant incorrect...",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              try {
                await FirebaseFirestore.instance.collection('factures').doc(docId).update({
                  'paymentStatus': 'rejected',
                  'motifRejet': reasonController.text.trim(),
                  'adminRejector': _adminSignature, 
                  'dateActionAdmin': FieldValue.serverTimestamp(),
                });
                if (!mounted) return;
                Navigator.pop(context); // Ferme le dialogue de motif
                Navigator.pop(context); // Ferme le dialogue de preuve
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Rejeté par $_adminSignature"), backgroundColor: Colors.red),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("CONFIRMER LE REJET", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _voirPreuvePaiement(Map<String, dynamic> data, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Vérification - ${data['nomClient'] ?? 'Client'}"),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 300, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: data['urlPreuve'] != null 
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        data['urlPreuve'], 
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 50),
                      ),
                    )
                  : const Icon(Icons.image_not_supported, size: 80),
              ),
              const SizedBox(height: 15),
              Text("Montant attendu : ${data['totalUSD'] ?? 0} USD", 
                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => _rejeterPaiement(docId), child: const Text("REJETER", style: TextStyle(color: Colors.red))),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('factures').doc(docId).update({
                  'paymentStatus': 'completed',
                  'adminValidator': _adminSignature, 
                  'dateValidationAdmin': FieldValue.serverTimestamp(),
                });
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Validé par $_adminSignature"), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Erreur lors de la validation : $e"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("VALIDER LE PAIEMENT", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- INTERFACE PRINCIPALE ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('factures').orderBy('dateCreation', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Erreur de chargement"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['paymentStatus'] ?? 'pending').toString().toLowerCase();
            
            bool matchesStatus = _filterStatus == 'tous' || 
                (_filterStatus == 'en attente' ? (status == 'pending' || status == 'waiting') : status == _filterStatus);
            
            String prov = (data['province'] ?? 'toutes').toString().toLowerCase();
            bool matchesProvince = _selectedProvince == 'toutes' || prov == _selectedProvince.toLowerCase();

            DateTime dateDoc = _parseDate(data['dateCreation'] ?? Timestamp.now());
            bool matchesDate = _selectedDateRange == null || 
                (dateDoc.isAfter(_selectedDateRange!.start) && dateDoc.isBefore(_selectedDateRange!.end.add(const Duration(days: 1))));

            return matchesStatus && matchesProvince && matchesDate;
          }).toList();

          double totalE = 0; double totalC = 0;
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['paymentStatus'] == 'completed') {
              totalE += (data['totalUSD'] ?? 0).toDouble();
              totalC += ((data['loyer'] ?? 0) * (data['comLocatairePercent'] ?? 0.05)).toDouble();
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(docs),
                const SizedBox(height: 20),
                _buildTauxControl(), 
                const SizedBox(height: 25),
                _buildStats(totalE, totalC),
                const SizedBox(height: 32),
                _buildFilterBar(),
                const SizedBox(height: 16),
                _buildTable(docs),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTauxControl() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('app_config').snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final double currentTaux = (data?['taux_usd_cdf'] ?? 2500.0).toDouble();
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.currency_exchange, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text("Taux : 1 USD = ${currentTaux.toStringAsFixed(0)} CDF", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: 15, runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActionChip(
          onPressed: _selectDateRange,
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: Text(_selectedDateRange == null ? "Date" : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}"),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedProvince,
              items: ['toutes', 'Kinshasa', 'Lualaba', 'Haut-Katanga'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (val) => setState(() => _selectedProvince = val!),
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: ['tous', 'completed', 'en attente', 'rejected'].map((s) => ChoiceChip(
            label: Text(s.toUpperCase(), style: const TextStyle(fontSize: 11)),
            selected: _filterStatus == s,
            onSelected: (val) => setState(() => _filterStatus = s),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildTable(List<QueryDocumentSnapshot> docs) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('DATE')),
              DataColumn(label: Text('CLIENT & CONTACT')),
              DataColumn(label: Text('MONTANT')),
              DataColumn(label: Text('VALIDÉ PAR')),
              DataColumn(label: Text('ACTION')),
            ],
            rows: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = (data['paymentStatus'] ?? 'pending').toString().toLowerCase();
              final isDone = status == 'completed';
              final isRejected = status == 'rejected';

              return DataRow(cells: [
                DataCell(Text(DateFormat('dd/MM/yy').format(_parseDate(data['dateCreation'] ?? Timestamp.now())))),
                DataCell(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(data['nomClient'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(data['telClient'] ?? '-', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  ],
                )),
                DataCell(Text("${data['totalUSD']}\$", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                DataCell(Text(data['adminValidator'] ?? (isRejected ? "REJETÉ" : "-"), style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic))),
                DataCell(isDone || isRejected 
                  ? Icon(isDone ? Icons.check_circle : Icons.cancel, color: isDone ? Colors.green : Colors.red)
                  : ElevatedButton(
                      onPressed: () => _voirPreuvePaiement(data, doc.id), 
                      child: const Text("Vérifier")
                    )
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(List<QueryDocumentSnapshot> docs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Finances", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
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
        _statCard("TOTAL ENCAISSÉ", currencyFormat.format(e), Icons.monetization_on, Colors.green),
        _statCard("COMMISSIONS", currencyFormat.format(c), Icons.account_balance_wallet, Colors.blue),
      ],
    );
  }

  Widget _statCard(String t, String v, IconData icon, Color col) {
    return Container(
      width: 250, padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Icon(icon, color: col),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      fileName: "Finance_Global", 
      sheetName: "Transactions",
      headers: ['DATE', 'CLIENT', 'TELEPHONE', 'TOTAL USD', 'STATUT', 'VALIDE PAR'],
      keys: ['dateCreation', 'nomClient', 'telClient', 'totalUSD', 'paymentStatus', 'adminValidator'],
    );
  }
}
