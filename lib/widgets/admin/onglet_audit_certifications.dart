// lib/widgets/admin/onglet_audit_certifications.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Utilisation de tes constantes pour une robustesse maximale
import 'package:easylocation_mvp/constants/all_constants.dart';

class OngletAuditCertifications extends StatefulWidget {
  const OngletAuditCertifications({super.key});

  @override
  State<OngletAuditCertifications> createState() => _OngletAuditCertificationsState();
}

class _OngletAuditCertificationsState extends State<OngletAuditCertifications> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    // ✅ Utilisation de la constante centralisée pour la collection de logs
    Query query = FirebaseFirestore.instance.collection(FirestoreCollections.adminLogs);

    // 🔒 Filtrage par type d'action pour cet onglet spécifique
    query = query.where('typeAction', isEqualTo: 'CERTIFICATION');

    // Application du filtre par date si l'agent en sélectionne une
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
            // Tri par date décroissante pour voir les dernières actions en haut
            // ⚠️ C'est cette ligne qui va générer le lien d'index dans ton terminal
            stream: query.orderBy('dateAction', descending: true).limit(100).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.blueGrey, letterSpacing: 1.1)),
              Text("Certifications Biens", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
            ],
          ),
          // Bouton de filtrage par date
          ActionChip(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: _selectedDate != null ? Colors.blue : Colors.white,
            side: BorderSide(color: Colors.blue.shade200),
            avatar: Icon(Icons.calendar_month, 
              size: 16, 
              color: _selectedDate != null ? Colors.white : Colors.blue),
            label: Text(
              _selectedDate == null ? "Filtrer" : DateFormat('dd/MM/yyyy').format(_selectedDate!),
              style: TextStyle(color: _selectedDate != null ? Colors.white : Colors.blue, fontSize: 12),
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
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.verified_user_rounded, color: Colors.green, size: 22),
      ),
      title: Text(
        "${data['adminName'] ?? 'Agent'} a certifié",
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            "Réf: ${data['propertyRef'] ?? 'N/A'}",
            style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
          ),
          Text(
            "Propriétaire: ${data['nomProprietaire'] ?? 'Inconnu'}",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormat('dd MMM').format(date),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            DateFormat('HH:mm').format(date),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: "SÉLECTIONNER UNE DATE D'AUDIT",
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.assignment_turned_in_outlined, size: 60, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text("Aucune certification enregistrée", 
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        if (_selectedDate != null)
          TextButton(
            onPressed: () => setState(() => _selectedDate = null),
            child: const Text("Effacer le filtre"),
          )
      ],
    ),
  );

  Widget _buildErrorState(String error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text("Erreur de flux : $error", 
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
      ),
    ));
}