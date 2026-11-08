// lib/widgets/espace_partenaire_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Importation des 4 widgets de l'entonnoir de performance
import 'partenaire/stat_visites_card.dart';
import 'partenaire/stat_installations_card.dart';
import 'partenaire/stat_comptes_card.dart';
import 'partenaire/stat_convertis_card.dart';

class EspacePartenaireWidget extends StatelessWidget {
  const EspacePartenaireWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('utilisateurs').doc(uid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox.shrink();

        var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        
        // --- RESOLUTION DYNAMIQUE DU PARTNER ID ---
        String? partnerId = userData?['partner_linked_id'];
        
        List<dynamic> roles = userData?['roles'] ?? [];
        String mainRole = userData?['role'] ?? '';
        bool isAgentOrStaff = roles.contains('AGENT') || 
                             roles.contains('agent') || 
                             roles.contains('operations') || 
                             mainRole == 'agent';

        if ((partnerId == null || partnerId.isEmpty) && isAgentOrStaff) {
          partnerId = uid;
        }

        // --- MESSAGE POUR LES NON-PARTENAIRES ---
        if (partnerId == null || partnerId.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 50, color: Colors.orangeAccent),
                const SizedBox(height: 20),
                const Text(
                  "Espace réservé aux partenaires",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Cet espace est réservé aux partenaires certifiés et agents d'EasyLocation. "
                  "Vous souhaitez nous rejoindre et booster vos revenus ? "
                  "N'hésitez pas à passer nous voir au bureau pour en discuter !",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E5D8F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      "OK, COMPRIS",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // --- ESPACE PARTENAIRE / AGENT ---
        final String safePartnerId = partnerId; // Garanti non-null ici

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('partenaires').doc(safePartnerId).snapshots(),
          builder: (context, partnerSnapshot) {
            if (partnerSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            var partData = partnerSnapshot.hasData && partnerSnapshot.data!.data() != null 
                ? partnerSnapshot.data!.data() as Map<String, dynamic> 
                : <String, dynamic>{};

            double solde = (partData['solde_commission'] ?? userData?['commission_credit'] ?? 0.0).toDouble();
            int totalConv = partData['total_conversions'] ?? 0;
            String nomPartenaire = partData['nom'] ?? 
                "${userData?['prenom'] ?? ''} ${userData?['nom'] ?? ''}".trim();

            if (nomPartenaire.isEmpty) nomPartenaire = "Partenaire";

            int visites = partData['stats_visites'] ?? 0;
            int installations = partData['stats_installations'] ?? 0;
            int comptesCrees = partData['stats_comptes'] ?? 0;
            int clientsConvertis = partData['stats_convertis'] ?? totalConv;

            double tauxConversion = visites > 0 ? (clientsConvertis / visites) * 100 : 0.0;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFF1E5D8F), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nomPartenaire.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1E5D8F),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Text(
                                "EASYLOCATION ENTERPRISE - BUSINESS",
                                style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    
                    // --- AFFICHAGE SOLDE ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${solde.toStringAsFixed(2)} \$",
                              style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                            ),
                            Text(
                              "$totalConv locations via votre code",
                              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- ENTONNOIR DE PERFORMANCE ---
                    const Text(
                      "SUIVI DE VOTRE ACTIVITÉ",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        StatVisitesCard(count: visites),
                        const SizedBox(width: 8),
                        StatInstallationsCard(count: installations),
                        const SizedBox(width: 8),
                        StatComptesCard(count: comptesCrees),
                        const SizedBox(width: 8),
                        StatConvertisCard(count: clientsConvertis),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Taux de conversion global", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E5D8F))),
                          Text("${tauxConversion.toStringAsFixed(1)} %", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E5D8F))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- HISTORIQUE DES FILLEULS ---
                    const Text(
                      "HISTORIQUE DE MON RÉSEAU",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),

                    // CORRECTION ICI : on passe safePartnerId (String non-null)
                    _buildFilleulsList(partnerId: safePartnerId, userUid: uid),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilleulsList({required String partnerId, required String userUid}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('partenaires')
          .doc(partnerId)
          .collection('filleuls')
          .orderBy('date', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshotPartenaire) {
        if (snapshotPartenaire.hasData && snapshotPartenaire.data!.docs.isNotEmpty) {
          return _renderFilleulsDocs(snapshotPartenaire.data!.docs);
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('utilisateurs')
              .where('referrerId', isEqualTo: userUid)
              .limit(5)
              .snapshots(),
          builder: (context, snapshotUsers) {
            if (!snapshotUsers.hasData || snapshotUsers.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text("Aucun filleul enregistré pour le moment.", style: TextStyle(color: Colors.grey, fontSize: 12)),
              );
            }

            return _renderUsersAsFilleulsDocs(snapshotUsers.data!.docs);
          },
        );
      },
    );
  }

  Widget _renderFilleulsDocs(List<QueryDocumentSnapshot> docs) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        var data = docs[index].data() as Map<String, dynamic>;
        String maskedName = data['masked_name'] ?? "Utilisateur ••${1000 + index}";
        String statut = data['statut'] ?? "Inscrit";
        Timestamp? ts = data['date'] as Timestamp?;
        String dateStr = ts != null ? "${ts.toDate().day.toString().padLeft(2, '0')}/${ts.toDate().month.toString().padLeft(2, '0')}/${ts.toDate().year}" : "--/--/----";

        return _buildFilleulTile(maskedName, statut, dateStr);
      },
    );
  }

  Widget _renderUsersAsFilleulsDocs(List<QueryDocumentSnapshot> docs) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        var data = docs[index].data() as Map<String, dynamic>;
        String prenom = data['prenom'] ?? 'Utilisateur';
        String nom = data['nom'] ?? '';
        
        // --- OPTION A : Masquage partiel des lettres (Ex: Glo**** S.) ---
        String maskedPrenom = prenom.length > 3 
            ? "${prenom.substring(0, 3)}${'*'.padLeft(prenom.length - 3, '*')}" 
            : prenom;
        String maskedName = "$maskedPrenom ${nom.isNotEmpty ? '${nom[0]}.' : ''}";

        String statut = "Inscrit";
        Timestamp? ts = data['createdAt'] as Timestamp?;
        String dateStr = ts != null ? "${ts.toDate().day.toString().padLeft(2, '0')}/${ts.toDate().month.toString().padLeft(2, '0')}/${ts.toDate().year}" : "--/--/----";

        return _buildFilleulTile(maskedName, statut, dateStr);
      },
    );
  }

  Widget _buildFilleulTile(String name, String statut, String dateStr) {
    Color statusColor;
    switch (statut.toLowerCase()) {
      case 'converti':
        statusColor = Colors.green;
        break;
      case 'en attente':
        statusColor = Colors.orange;
        break;
      case 'installation':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text("Date : $dateStr", style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          statut,
          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
        ),
      ),
    );
  }
}