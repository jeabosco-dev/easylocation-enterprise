import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OngletAuditFinancier extends StatefulWidget {
  const OngletAuditFinancier({super.key});

  @override
  State<OngletAuditFinancier> createState() => _OngletAuditFinancierState();
}

class _OngletAuditFinancierState extends State<OngletAuditFinancier> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    // On cible la collection des logs administratifs (ventes, paiements, etc.)
    Query query = FirebaseFirestore.instance.collection('admin_logs');

    if (_selectedDate != null) {
      DateTime startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      
      query = query
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay));
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.orderBy('timestamp', descending: true).limit(100).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return _buildEmptyState();

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return _buildAuditTile(data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "AUDIT FINANCIER", 
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: 0.5),
          ),
          FilterChip(
            selected: _selectedDate != null,
            label: Text(
              _selectedDate == null ? "Filtrer date" : DateFormat('dd MMM yyyy').format(_selectedDate!),
              style: TextStyle(fontSize: 12, color: _selectedDate != null ? Colors.blue : Colors.black87),
            ),
            onSelected: (bool selected) => _pickDate(),
            onDeleted: _selectedDate != null ? () => setState(() => _selectedDate = null) : null,
            deleteIconColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTile(Map<String, dynamic> data) {
    // 1️⃣ Sécurité sur l'action et la date
    final String action = data['actionType'] ?? 'INCONNUE';
    final DateTime date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    // 2️⃣ Sécurité sur le montant (conversion forcée en double pour éviter les erreurs de type)
    final double amount = (data['amount'] ?? 0).toDouble();

    // 3️⃣ Sécurité sur le nom du bien
    final String property = data['propertyName'] ?? 'Bien non spécifié';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200), 
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFF1F5F9), 
          child: Icon(Icons.account_balance_wallet, color: Colors.blueGrey, size: 20),
        ),
        title: Text(
          "${data['adminName'] ?? 'Admin'} • $action", 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "Bien: $property | Montant: ${amount.toStringAsFixed(2)}\$",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        trailing: Text(
          DateFormat('HH:mm').format(date), 
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, 
      initialDate: _selectedDate ?? DateTime.now(), 
      firstDate: DateTime(2024), 
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Widget _buildEmptyState() => const Center(
    child: Padding(
      padding: EdgeInsets.all(20.0),
      child: Text("Aucun log financier trouvé pour cette période.", style: TextStyle(color: Colors.grey)),
    ),
  );

  Widget _buildErrorState(String error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text("Erreur de chargement: $error", style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
    ),
  );
}
