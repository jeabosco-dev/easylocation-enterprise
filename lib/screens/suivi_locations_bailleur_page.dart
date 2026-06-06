// lib/screens/suivi_locations_bailleur_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import '../utils/ui_utils.dart';

class SuiviLocationsBailleurPage extends StatefulWidget {
  final String? contractId; // Paramètre optionnel pour la navigation profonde
  const SuiviLocationsBailleurPage({super.key, this.contractId});

  @override
  State<SuiviLocationsBailleurPage> createState() => _SuiviLocationsBailleurPageState();
}

class _SuiviLocationsBailleurPageState extends State<SuiviLocationsBailleurPage> {
  
  @override
  void initState() {
    super.initState();
    // Si un contractId est reçu, on attend le premier frame pour ouvrir le détail
    if (widget.contractId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ouvrirDossierAutomatiquement(widget.contractId!);
      });
    }
  }

  void _ouvrirDossierAutomatiquement(String id) {
    FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(id).get().then((doc) {
      if (doc.exists && mounted) {
        _showDossierDetails(context, doc.data() as Map<String, dynamic>);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Utilisateur non connecté.")),
      );
    }

    // REQUÊTE CORRIGÉE : Utilisation de dateCreation pour éviter l'exclusion des documents
    final locationsStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.factures) 
        .where('bailleurId', isEqualTo: currentUser.uid)
        .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPaid)
        .orderBy(FactureFields.dateCreation, descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Suivi de mes Locations', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: locationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Aucune réservation ou paiement encaissé pour le moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final dossiers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: dossiers.length,
            itemBuilder: (context, index) {
              final dossierData = dossiers[index].data() as Map<String, dynamic>;
              
              final locataireNomComplet = dossierData['nomClient'] ?? dossierData['clientName'] ?? 'Locataire';
              final proprieteIdentifiant = dossierData['refMaison'] ?? dossierData['propertyRef'] ?? 'Propriété';
              final etapeDossier = dossierData[FactureFields.etapeDossier] ?? FactureFields.etapePaye;

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
                    backgroundColor: _getStatusColor(etapeDossier).withOpacity(0.1),
                    child: Icon(Icons.home_work, color: _getStatusColor(etapeDossier)),
                  ),
                  title: Text(
                    "Réf : $proprieteIdentifiant",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black87, fontSize: 14),
                        children: [
                          TextSpan(text: 'Locataire : $locataireNomComplet\n'),
                          const TextSpan(text: 'Statut : ', style: TextStyle(color: Colors.grey)),
                          TextSpan(
                            text: _formatStatut(etapeDossier),
                            style: TextStyle(color: _getStatusColor(etapeDossier), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    _showDossierDetails(context, dossierData);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String etape) {
    switch (etape) {
      case FactureFields.etapeVisiteTerminee: 
      case FactureFields.etapeValide:
      case FactureFields.etapeCloture: // Ajout pour le statut clôturé
        return Colors.green;
      case FactureFields.etapePaye: 
        return Colors.orange;
      case FactureFields.etapeAnnule: 
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _formatStatut(String etape) {
    switch (etape) {
      case FactureFields.etapePaye: 
        return "Réservation validée (En attente de visite)";
      case FactureFields.etapeVisiteTerminee: 
        return "Visite effectuée sur le terrain";
      case FactureFields.etapeValide:
        return "Location Confirmée";
      case FactureFields.etapeCloture:
        return "Location Clôturée";
      case FactureFields.etapeAnnule: 
        return "Logement Refusé après visite";
      default:
        return "En cours de traitement";
    }
  }

  void _showDossierDetails(BuildContext context, Map<String, dynamic> dossier) {
    final locataireNomComplet = dossier['nomClient'] ?? dossier['clientName'] ?? 'Inconnu';
    final proprieteIdentifiant = dossier['refMaison'] ?? dossier['propertyRef'] ?? 'Inconnu';
    final acompteViaApp = (dossier['commissionBailleur'] as num?)?.toDouble() ?? 0.0;
    final loyer = (dossier['loyer'] as num?)?.toDouble() ?? 0.0;
    final nbMois = (dossier['nbMoisGarantie'] as num?)?.toInt() ?? 0;
    final garantieTotale = loyer * nbMois;
    final netARecevoir = garantieTotale - acompteViaApp;
    final etapeDossier = dossier[FactureFields.etapeDossier] ?? FactureFields.etapePaye;

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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStatusColor(etapeDossier).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _formatStatut(etapeDossier).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: _getStatusColor(etapeDossier),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildInfoRow("Maison Réf", proprieteIdentifiant),
                _buildInfoRow("Locataire", locataireNomComplet),
                const Divider(height: 40),
                const Text("RÉCAPITULATIF FINANCIER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                const SizedBox(height: 12),
                _buildFinanceRow("Garantie Totale ($nbMois mois)", "${UIUtils.formatPrice(garantieTotale)}\$"),
                _buildFinanceRow("Acompte déjà perçu par l'App", "- ${UIUtils.formatPrice(acompteViaApp)}\$", color: Colors.orange),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: _buildFinanceRow("NET À PERCEVOIR CASH", "${UIUtils.formatPrice(netARecevoir)}\$", isTotal: true),
                ),
                const SizedBox(height: 20),
                const Text("Note : Les frais d'agence de l'application ont été déduits de l'acompte initial. Le locataire doit vous verser le montant NET ci-dessus directement pour officialiser l'occupation.",
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("COMPRIS", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
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
        Text(label, style: TextStyle(fontSize: isTotal ? 13 : 12, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? Colors.green.shade900 : Colors.black87)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isTotal ? Colors.green.shade700 : (color ?? Colors.black), fontSize: isTotal ? 18 : 13)),
      ],
    );
  }
}