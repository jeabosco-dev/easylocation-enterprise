import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OngletAuditCertifications extends StatefulWidget {
  const OngletAuditCertifications({super.key});

  @override
  State<OngletAuditCertifications> createState() => _OngletAuditCertificationsState();
}

class _OngletAuditCertificationsState extends State<OngletAuditCertifications> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    // On cible la collection métier
    Query query = FirebaseFirestore.instance.collection('audit_logs');

    // 🔒 Verrouillage du scope : on ne veut QUE les certifications ici
    query = query.where('typeAction', isEqualTo: 'CERTIFICATION');

    // Application du filtre par date si sélectionnée
    if (_selectedDate != null) {
      DateTime startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      
      query = query
          .where('dateAction', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('dateAction', isLessThan: Timestamp.fromDate(endOfDay));
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Note : Firestore demandera la création d'un index composite 
            // (typeAction + dateAction) lors du premier test de filtrage.
            stream: query.orderBy('dateAction', descending: true).limit(100).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return _buildEmptyState();

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return _buildCertificationTile(data);
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
        color: Colors.blue.shade50.withOpacity(0.3),
        border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("AUDIT MÉTIER", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
              Text("Certifications Biens", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
            ],
          ),
          ActionChip(
            backgroundColor: _selectedDate != null ? Colors.blue : Colors.white,
            avatar: Icon(Icons.calendar_today, 
              size: 14, 
              color: _selectedDate != null ? Colors.white : Colors.blue),
            label: Text(
              _selectedDate == null ? "Date" : DateFormat('dd/MM/yyyy').format(_selectedDate!),
              style: TextStyle(color: _selectedDate != null ? Colors.white : Colors.blue),
            ),
            onPressed: _pickDate,
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationTile(Map<String, dynamic> data) {
    final DateTime date = (data['dateAction'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE8F5E9),
        child: Icon(Icons.verified, color: Colors.green, size: 20),
      ),
      title: Text(
        "${data['adminName'] ?? 'Agent'} a certifié",
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          "Réf: ${data['propertyRef'] ?? 'N/A'}\nProprio: ${data['nomProprietaire'] ?? 'Inconnu'}",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ),
      trailing: Text(
        DateFormat('dd/MM\nHH:mm').format(date),
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w500),
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
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.fact_check_outlined, size: 40, color: Colors.grey),
        SizedBox(height: 8),
        Text("Aucun log de certification trouvé.", style: TextStyle(color: Colors.grey)),
      ],
    ),
  );

  Widget _buildErrorState(String error) => Center(
    child: Text("Erreur : $error", style: const TextStyle(color: Colors.red)));
}
