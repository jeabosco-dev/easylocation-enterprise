// lib/screens/gestion_demandes_bailleur_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ✅ Importation de ton utilitaire harmonisé
import '../utils/ui_utils.dart';

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

    // Le stream récupère les demandes liées au bailleur connecté
    final demandesStream = FirebaseFirestore.instance
        .collection('demandes_de_visite')
        .where('bailleurId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi de mes Locations', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
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
                'Aucune activité pour le moment.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final demandes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: demandes.length,
            itemBuilder: (context, index) {
              final demande = demandes[index].data() as Map<String, dynamic>;
              final locataireNomComplet = "${demande['locatairePrenom'] ?? ''} ${demande['locataireNom'] ?? 'Locataire'}";
              final proprieteIdentifiant = demande['proprieteIdentifiant'] ?? 'Propriété';
              final statut = demande['statut'] ?? 'en_attente';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(statut).withOpacity(0.1),
                    child: Icon(Icons.home_work, color: _getStatusColor(statut)),
                  ),
                  title: Text(
                    proprieteIdentifiant,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Client : $locataireNomComplet\nÉtat : ${_formatStatut(statut)}'),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    _showDemandeDetails(context, demande);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- LOGIQUE DE COULEURS ---
  Color _getStatusColor(String statut) {
    switch (statut) {
      case 'confirme': return Colors.green;
      case 'en_attente_confirmation_bailleur': return Colors.orange;
      case 'refusee': return Colors.red;
      default: return Colors.blue;
    }
  }

  String _formatStatut(String statut) {
    switch (statut) {
      case 'confirme': return "Visite validée / En cours";
      case 'en_attente_confirmation_bailleur': return "Dossier en analyse";
      case 'refusee': return "Annulé";
      default: return "En attente";
    }
  }

  // --- DIALOGUE DE TRANSPARENCE FINANCIÈRE (LOGIQUE EASYLOCATION ENTERPRISE) ---
  void _showDemandeDetails(BuildContext context, Map<String, dynamic> demande) {
    final locataireNomComplet = "${demande['locatairePrenom'] ?? ''} ${demande['locataireNom'] ?? 'inconnu'}";
    final proprieteIdentifiant = demande['proprieteIdentifiant'] ?? 'inconnu';
    
    // LOGIQUE DE CALCUL CONFORME À TA STRATÉGIE DE DÉDUCTION
    final acompteViaApp = (demande['commissionBailleurUSD'] as num?)?.toDouble() ?? 0.0;
    final loyer = (demande['loyer'] as num?)?.toDouble() ?? 0.0;
    final nbMois = (demande['nbMoisGarantie'] as num?)?.toInt() ?? 0;
    
    final garantieTotale = loyer * nbMois;
    final netARecevoir = garantieTotale - acompteViaApp;
    
    final statut = demande['statut'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Détails du Dossier", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge d'état
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStatusColor(statut).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _formatStatut(statut).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: _getStatusColor(statut),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildInfoRow("Propriété", proprieteIdentifiant),
                _buildInfoRow("Locataire", locataireNomComplet),
                const Divider(height: 40),
                
                // Section Financière (Logique de déduction de commission)
                const Text("RÉCAPITULATIF FINANCIER", 
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                const SizedBox(height: 12),
                
                _buildFinanceRow(
                  "Garantie Totale ($nbMois mois)", 
                  "${UIUtils.formatPrice(garantieTotale)}\$"
                ),
                _buildFinanceRow(
                  "Acompte payé sur l'App", 
                  "- ${UIUtils.formatPrice(acompteViaApp)}\$", 
                  color: Colors.orange
                ),
                
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: _buildFinanceRow(
                    "NET À PERCEVOIR", 
                    "${UIUtils.formatPrice(netARecevoir)}\$", 
                    isTotal: true
                  ),
                ),
                
                const SizedBox(height: 20),
                const Text(
                  "Note : La commission d'agence a été déduite de la garantie. Le montant net ci-dessus est ce que le locataire doit vous remettre en main propre.",
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("FERMER", 
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 13),
          children: [
            TextSpan(text: "$label : ", style: const TextStyle(color: Colors.grey)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceRow(String label, String value, {bool isTotal = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontSize: isTotal ? 13 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.green.shade900 : Colors.black87
          )
        ),
        Text(
          value, 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isTotal ? Colors.green.shade700 : (color ?? Colors.black),
            fontSize: isTotal ? 18 : 13,
          ),
        ),
      ],
    );
  }
}