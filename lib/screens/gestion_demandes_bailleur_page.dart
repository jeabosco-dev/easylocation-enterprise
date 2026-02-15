// lib/screens/gestion_demandes_bailleur_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GestionDemandesBailleurPage extends StatelessWidget {
  const GestionDemandesBailleurPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Utilisateur non connecté.")),
      );
    }

    final demandesStream = FirebaseFirestore.instance
        .collection('demandes_de_visite')
        .where('bailleurId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer Mes Demandes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: demandesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Aucune demande reçue pour le moment.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final demandes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: demandes.length,
            itemBuilder: (context, index) {
              final demande = demandes[index].data() as Map<String, dynamic>;
              // Récupérer le nom complet du locataire
              final locataireNomComplet = "${demande['locatairePrenom'] ?? ''} ${demande['locataireNom'] ?? 'Locataire inconnu'}";
              final proprieteIdentifiant = demande['proprieteIdentifiant'] ?? 'Propriété inconnue';
              final statut = demande['statut'] ?? 'en_attente';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(
                    'Demande de $locataireNomComplet',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pour : $proprieteIdentifiant'),
                      Text('Statut : ${statut.toUpperCase()}'),
                    ],
                  ),
                  trailing: _buildStatusIcon(statut),
                  onTap: () {
                    _showDemandeDetails(context, demande, demandes[index].id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusIcon(String statut) {
    switch (statut) {
      case 'en_attente_confirmation_bailleur':
        return const Icon(Icons.pending, color: Colors.orange);
      case 'confirme':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'refusee':
        return const Icon(Icons.cancel, color: Colors.red);
      default:
        return const Icon(Icons.info_outline, color: Colors.grey);
    }
  }

  void _showDemandeDetails(BuildContext context, Map<String, dynamic> demande, String demandeId) {
    final locataireNomComplet = "${demande['locatairePrenom'] ?? ''} ${demande['locataireNom'] ?? 'inconnu'}";
    final proprieteIdentifiant = demande['proprieteIdentifiant'] ?? 'inconnu';
    final dateVisite = demande['dateVisite'] is Timestamp
        ? (demande['dateVisite'] as Timestamp).toDate()
        : null;
    final commissionPayeeParLocataire = (demande['commissionPayee'] as num?)?.toDouble() ?? 0.0;
    final garantieDemandee = (demande['garantieDemandee'] as num?)?.toDouble() ?? 0.0;
    final montantRestantARecevoir = garantieDemandee - commissionPayeeParLocataire;
    final statut = demande['statut'] ?? 'en_attente_confirmation_bailleur';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Détails de la demande"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Le locataire $locataireNomComplet a payé tous les frais pour prendre en location votre maison.",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "Il aimerait visiter la propriété $proprieteIdentifiant.",
                ),
                Text(
                  "Notre équipe a validé les détails par téléphone.",
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 15),
                Text(
                  "Informations de la demande :",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Divider(),
                if (dateVisite != null)
                  Text('Date de visite : ${DateFormat('dd MMMM yyyy à HH:mm').format(dateVisite)}'),
                Text('Montant de la commission payée par le locataire pour vous : ${commissionPayeeParLocataire.toStringAsFixed(2)} \$'),
                Text('Garantie que vous demandez : ${garantieDemandee.toStringAsFixed(2)} \$'),
                const Divider(),
                Text(
                  'Il vous reste à recevoir du locataire : ${montantRestantARecevoir.toStringAsFixed(2)} \$',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 20),
                if (statut == 'en_attente_confirmation_bailleur')
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('demandes_de_visite').doc(demandeId).update({
                              'statut': 'confirme',
                              'reponse_bailleur': 'Confirme',
                            });
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Demande confirmée ! Une notification a été envoyée au locataire.')),
                            );
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Confirmer la date', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            // Redirection vers le support
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Veuillez contacter notre support pour modifier la demande.')),
                            );
                            // Idéalement, ici vous redirigez vers une page de contact ou affichez les infos de support
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Contacter l\'entreprise pour modifier'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Fermer"),
            ),
          ],
        );
      },
    );
  }
}
