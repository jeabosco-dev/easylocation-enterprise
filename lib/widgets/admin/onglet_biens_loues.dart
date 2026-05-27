// lib/widgets/admin/onglet_biens_loues.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/widgets/admin/property_details_panel.dart';
import 'package:intl/intl.dart'; 

class OngletBiensLoues extends StatefulWidget {
  const OngletBiensLoues({super.key});

  @override
  State<OngletBiensLoues> createState() => _OngletBiensLouesState();
}

class _OngletBiensLouesState extends State<OngletBiensLoues> {
  String _selectedCommune = 'Toutes';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        title: _buildCommuneFilter(),
      ),
      body: _buildPropertyStream(),
    );
  }

  Widget _buildCommuneFilter() {
    final communes = ['Toutes', 'Ibanda', 'Kadutu', 'Bagira'];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: communes.length,
        itemBuilder: (context, index) {
          final c = communes[index];
          final isSelected = _selectedCommune == c;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black)),
              selected: isSelected,
              selectedColor: Colors.indigo[700],
              onSelected: (val) => setState(() => _selectedCommune = c),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPropertyStream() {
    // 🎯 Uniquement les biens réellement loués ou occupés
    Query query = FirebaseFirestore.instance
        .collection(FirestoreCollections.properties)
        .where(FirestoreFields.isVerified, isEqualTo: true)
        .where(FirestoreFields.status, whereIn: const ['rented', 'occupied']); 

    if (_selectedCommune != 'Toutes') {
      query = query.where('commune', isEqualTo: _selectedCommune);
    }

    query = query.orderBy('updatedAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Erreur de flux : ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final property = Property.fromMap(data, docs[index].id);
            
            // ✅ MODIFICATION : On transmet l'index (+1) à la fonction de création de la carte
            return _buildEnterpriseCard(property, data, index + 1);
          },
        );
      },
    );
  }

  // ✅ MODIFICATION : Ajout du paramètre 'int numeroLigne'
  Widget _buildEnterpriseCard(Property p, Map<String, dynamic> rawData, int numeroLigne) {
    final DateTime? dateReservation = (rawData['reservedAt'] as Timestamp?)?.toDate();
    final String dateFormatee = dateReservation != null 
        ? DateFormat('dd/MM/yyyy').format(dateReservation) 
        : "N/A";
    
    final int garantie = rawData['garantieIdeale'] ?? rawData['garantieMinimale'] ?? 0;
    final String adresseComplete = "${p.quartier ?? 'Quartier N/A'}, Av. ${rawData['avenue'] ?? 'N/A'}";

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        // ✅ MODIFICATION : Remplacement de l'icône brute par le badge numérique dynamique
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade50,
          radius: 18,
          child: Text(
            "$numeroLigne",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade900,
              fontSize: 13,
            ),
          ),
        ),
        // ✅ AJOUT VISUEL : L'icône originale est basculée proprement dans le titre à côté du texte
        title: Row(
          children: [
            Icon(Icons.home_work_outlined, color: Colors.indigo.shade700, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                "${p.typeBien} • ${p.commune}", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("📍 $adresseComplete", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text("${p.price}\$ / mois", style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      "OCCUPÉ", 
                      style: TextStyle(fontSize: 9, color: Colors.green.shade800, fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SECTION CONTRAT ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetaInfo("Date Réservation", dateFormatee, Icons.calendar_today_outlined),
                    _buildMetaInfo("Garantie payée", "$garantie Mois", Icons.security_outlined),
                    _buildMetaInfo("Réf Bien", p.referenceUnique ?? "N/A", Icons.tag),
                  ],
                ),
                const SizedBox(height: 16),
                
                // --- SECTION ACTEURS ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Infos Bailleur
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("PROPRIÉTAIRE (BAILLEUR)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text("${p.prenomProprietaire ?? ''} ${p.postnomProprietaire ?? ''}".toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(p.telephoneProprietaire ?? "Pas de téléphone", style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                          Text(rawData['emailProprietaire'] ?? "Pas d'email", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 20),
                    // Infos Locataire
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("LOCATAIRE ACTUEL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(rawData['lastLocataireName'] ?? "Client EasyLocation", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(rawData['lastLocatairePhone'] ?? "Voir Facture", style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // --- BOUTONS D'ACTION ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _ouvrirDetails(p.id!, rawData),
                      icon: const Icon(Icons.fullscreen, size: 18),
                      label: const Text("Fiche Complète"),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfo(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      ],
    );
  }

  void _ouvrirDetails(String id, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: PropertyDetailsPanel(
          property: Property.fromMap(data, id),
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_meeting_room, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text("Aucun bien actuellement loué", style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}