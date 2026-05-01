import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/service_journal.dart';
import '../constants/constants.dart'; // ✅ Import ajouté pour l'harmonisation

class ActivitesRecentesBailleurWidget extends StatelessWidget {
  final String bailleurId;

  const ActivitesRecentesBailleurWidget({
    super.key,
    required this.bailleurId,
  });

  @override
  Widget build(BuildContext context) {
    if (bailleurId.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Activités Récentes",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          // ✅ Utilisation de la constante centralisée
          stream: FirebaseFirestore.instance
              .collection(FirestoreCollections.activityLog)
              .where('userId', isEqualTo: bailleurId)
              .orderBy('timestamp', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text("Erreur de chargement des activités");
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return _buildEtatVide();
            }

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final activiteData = doc.data() as Map<String, dynamic>;
                  final String id = doc.id;

                  return Dismissible(
                    key: Key(id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) => _showDeleteConfirmation(context),
                    onDismissed: (direction) {
                      ServiceJournal.supprimerActivite(id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Activité retirée")),
                      );
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_sweep, color: Colors.white),
                    ),
                    child: _buildListTile(context, id, activiteData),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildListTile(BuildContext context, String id, Map<String, dynamic> activite) {
    IconData iconeData = Icons.info_outline;
    Color iconeCouleur = Colors.blue;

    String activiteBrute = activite['activity'] ?? 'Activité';
    String desc = activiteBrute.toLowerCase();
    String type = activite['type'] ?? '';

    // --- LOGIQUE DE SÉCURITÉ ANTI "UNE PR" ---
    String titreAffiche = activiteBrute;
    
    if (activiteBrute.contains(':')) {
      List<String> parts = activiteBrute.split(':');
      String action = parts[0].trim();
      String detail = parts[1].trim();

      // On ne transforme en "Réf:" QUE si c'est un ID technique (pas d'espaces)
      if (!detail.contains(' ') && detail.length > 5) {
        String idBrut = detail.contains('-') ? detail.split('-').last : detail;
        String idPrefix = idBrut.length >= 6 
            ? idBrut.substring(0, 6).toUpperCase() 
            : idBrut.toUpperCase();
            
        titreAffiche = "$action : Réf: $idPrefix";
      } else if (detail.contains('Maison N°')) {
        String idBrut = detail.replaceAll('Maison N°', '').trim();
        if (idBrut.contains('-')) idBrut = idBrut.split('-').last;
        String idPrefix = idBrut.length >= 6 ? idBrut.substring(0, 6).toUpperCase() : idBrut.toUpperCase();
        titreAffiche = "$action : Réf: $idPrefix";
      }
    }

    if (type == 'creation' || desc.contains('publié')) {
      iconeData = Icons.add_business_outlined;
      iconeCouleur = Colors.green;
    } else if (type == 'modification' || desc.contains('mis à jour') || desc.contains('réussie')) {
      iconeData = Icons.edit_note;
      iconeCouleur = Colors.orange;
    } else if (desc.contains('visite')) {
      iconeData = Icons.calendar_month;
      iconeCouleur = Colors.purple;
    }

    final timestamp = activite['timestamp'] as Timestamp?;
    final dateFormatee = timestamp != null
        ? DateFormat('dd MMM, HH:mm').format(timestamp.toDate())
        : 'À l\'instant';

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: iconeCouleur.withOpacity(0.1),
        child: Icon(iconeData, color: iconeCouleur, size: 18),
      ),
      title: Text(
        titreAffiche,
        style: const TextStyle(
          fontSize: 13, 
          fontWeight: FontWeight.bold,
          color: Color(0xFF0D47A1),
        ),
      ),
      subtitle: Text(dateFormatee, style: const TextStyle(fontSize: 11)),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 16, color: Colors.grey),
        onPressed: () async {
          bool confirm = await _showDeleteConfirmation(context);
          if (confirm) {
            await ServiceJournal.supprimerActivite(id);
          }
        },
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Supprimer ?", style: TextStyle(fontSize: 18)),
            content: const Text("Voulez-vous retirer cette activité de l'historique ?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("ANNULER"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("SUPPRIMER", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildEtatVide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.history, color: Colors.grey.shade400, size: 30),
          const SizedBox(height: 8),
          Text(
            'Aucune activité pour le moment.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}