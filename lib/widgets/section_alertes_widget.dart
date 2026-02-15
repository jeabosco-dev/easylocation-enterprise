import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../screens/details_propriete_page.dart';
import '../screens/alerte_chasseur_premium_page.dart';

class SectionAlertesWidget extends StatefulWidget {
  final String userId;

  const SectionAlertesWidget({super.key, required this.userId});

  @override
  State<SectionAlertesWidget> createState() => _SectionAlertesWidgetState();
}

class _SectionAlertesWidgetState extends State<SectionAlertesWidget> {
  // ✅ Variable pour stocker le flux (stream) et éviter les reconstructions infinies
  late Stream<QuerySnapshot> _alerteStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    // ✅ On initialise le stream une seule fois ici
    _alerteStream = FirebaseFirestore.instance
        .collection('utilisateurs')
        .doc(widget.userId)
        .collection('alertes')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _marquerCommeLue(String alertId) async {
    try {
      await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(widget.userId)
          .collection('alertes')
          .doc(alertId)
          .update({'lu': true});
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour de l\'alerte : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Mes Alertes de Recherche",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // ✅ BANDEAU PREMIUM
        _buildPremiumBanner(context),

        StreamBuilder<QuerySnapshot>(
          stream: _alerteStream, // ✅ Utilisation du stream stable stocké dans le State
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('Aucune nouvelle alerte pour le moment. 🔔'),
                ),
              );
            }

            final alerteDocs = snapshot.data!.docs;
            final alertesNonLues = alerteDocs.where((doc) => doc['lu'] == false).toList();
            final alertesLues = alerteDocs.where((doc) => doc['lu'] == true).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (alertesNonLues.isNotEmpty) ...[
                  const Text('Nouveautés',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  ...alertesNonLues.map((doc) => _buildAlerteTile(context, doc)),
                ],
                if (alertesNonLues.isNotEmpty && alertesLues.isNotEmpty)
                  const SizedBox(height: 15),
                if (alertesLues.isNotEmpty) ...[
                  const Text('Historique',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 5),
                  ...alertesLues
                      .take(5) // On garde les 5 dernières alertes lues
                      .map((doc) => _buildAlerteTile(context, doc)),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // --- UI HELPER : BANDEAU PREMIUM ---
  Widget _buildPremiumBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.userId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Chargement de votre profil..."),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlerteChasseurPremiumPage(userId: widget.userId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20, top: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade100, Colors.orange.shade50],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.stars_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Devenir Prioritaire VIP",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown),
                  ),
                  Text(
                    "Soyez alerté avant tout le monde pour 1\$",
                    style: TextStyle(fontSize: 11, color: Colors.brown),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.brown),
          ],
        ),
      ),
    );
  }

  // --- UI HELPER : TUILE D'ALERTE ---
  Widget _buildAlerteTile(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bool isRead = data['lu'] ?? false;
    final String propertyId = data['propertyId'] ?? '';
    final String time = DateFormat('dd MMM yyyy, HH:mm')
        .format((data['timestamp'] as Timestamp).toDate());

    return Card(
      elevation: isRead ? 0.5 : 2,
      color: isRead ? Colors.white : Colors.blue.shade50,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        leading: Icon(
          isRead ? Icons.notifications_none : Icons.notifications_active,
          color: isRead ? Colors.grey : Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          data['message'] ?? 'Nouvelle propriété',
          style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
        ),
        subtitle: Text(time),
        onTap: () async {
          if (!isRead) await _marquerCommeLue(doc.id);
          if (propertyId.isNotEmpty && context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  DetailsProprietePage(propertiesIds: [propertyId], initialIndex: 0),
            ));
          }
        },
      ),
    );
  }
}
