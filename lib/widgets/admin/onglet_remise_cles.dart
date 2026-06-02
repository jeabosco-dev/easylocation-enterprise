// lib/widgets/admin/onglet_remise_cles.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; // Import ajouté
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart';
import 'package:easylocation_mvp/models/facture_model.dart';
import 'package:easylocation_mvp/utils/phone_utils.dart';
import 'package:easylocation_mvp/utils/date_helper.dart';
import 'package:url_launcher/url_launcher.dart';
// 🔌 Importation du widget d'assignation nettoyé
import 'package:easylocation_mvp/widgets/admin/bouton_assignation_agent_widget.dart';

class OngletRemiseCles extends StatefulWidget {
  const OngletRemiseCles({super.key});

  @override
  State<OngletRemiseCles> createState() => _OngletRemiseClesState();
}

class _OngletRemiseClesState extends State<OngletRemiseCles> {
  bool _isProcessing = false;

  /// ✅ Helper pour générer une référence de contrat lisible (ex: CTR-2026-A1B2)
  String _generateContractRef(String factureId) {
    final String year = DateTime.now().year.toString();
    final String shortId = factureId.length > 4 
        ? factureId.substring(factureId.length - 4).toUpperCase() 
        : factureId.toUpperCase();
    return "CTR-$year-$shortId";
  }

  /// ✅ Dialogue de sélection de date (Flexible)
  Future<DateTime?> _selectStartDate(BuildContext context) async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: "DATE DE DÉBUT DU BAIL (Selon accord Bailleur)",
    );
  }

  // --- 1. LOGIQUE DE CLÔTURE (RÉUSSITE) ---
  Future<void> _confirmerRemiseCles(FactureModel facture, Map<String, dynamic> rawData) async {
    final String statutLocataire = rawData[FactureFields.confirmationLocataire] ?? 'en_attente';
    
    DateTime dateChoisie = DateTime.now();

    bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        DateTime tempDate = dateChoisie;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Validation du Bail", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Réf Maison : ${facture.refMaison}"),
                  const SizedBox(height: 15),
                  const Text("Date de début du bail :", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: () async {
                      final picked = await _selectStartDate(context);
                      if (picked != null) {
                        setDialogState(() => tempDate = picked);
                        dateChoisie = picked;
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue.shade900),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.blue.shade50,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateHelper.formatShortDate(tempDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Icon(Icons.calendar_month, color: Color(0xFF0D47A1)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    statutLocataire == 'en_attente' 
                        ? "⚠️ Le locataire n'a pas encore validé via l'app, vous forcez la clôture manuellement."
                        : "✅ Le locataire a déjà confirmé la réception.",
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER")),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
                  child: const Text("CONFIRMER & CRÉER LE CONTRAT"),
                ),
              ],
            );
          },
        );
      },
    );

    if (proceed == true) {
      await _executeSecureAction(
        facture: facture, 
        dateDebutBail: dateChoisie,
        actionType: statutLocataire == 'en_attente' ? AdminLogFields.actionClotureForcee : AdminLogFields.actionClotureStandard,
        details: "Contrat activé par le Backoffice. Début réel : ${DateHelper.formatShortDate(dateChoisie)}",
        rawData: rawData,
        
        factureUpdate: {
          FactureFields.etapeDossier: FactureFields.etapeCloture, 
          FactureFields.dateCloture: FieldValue.serverTimestamp(),
          FactureFields.statutFinal: FactureFields.statutTermine,
          FactureFields.clotureParAdmin: true,
          "dateDebutEffective": Timestamp.fromDate(dateChoisie),
        },
        
        propertyUpdate: {
          FirestoreFields.status: PropertyStatus.rented, 
          FirestoreFields.isVisible: false, 
          FirestoreFields.rentedAt: FieldValue.serverTimestamp(),
          FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
          FirestoreFields.estLouee: true, 
        },
      );
    }
  }

  // --- LOGIQUE D'ENVOI NOTIFICATIONS ---
  Future<void> _envoyerNotificationsCloture(FactureModel facture) async {
    try {
      // 1. Notification au Locataire
      await FirebaseFunctions.instance.httpsCallable('sendNotification').call({
        'userId': facture.clientId,
        'title': "Bail confirmé ! 🔑",
        'body': "Votre bail pour la maison ${facture.refMaison} est officiellement activé. Bienvenue !",
        'propertyId': facture.propertyId,
        'contractId': facture.id,
      });

      // 2. Notification au Bailleur
      if (facture.bailleurId != null) {
        await FirebaseFunctions.instance.httpsCallable('sendNotification').call({
          'userId': facture.bailleurId,
          'title': "Maison Louée ! 🏠",
          'body': "La maison ${facture.refMaison} vient d'être officiellement louée au locataire ${facture.nomClient}.",
          'propertyId': facture.propertyId,
          'contractId': facture.id,
        });
      }
    } catch (e) {
      debugPrint("Erreur envoi notifications : $e");
    }
  }

  // --- 2. LOGIQUE DE REFUS / LITIGE AVEC MOTIF ---
  Future<void> _gererRefus(FactureModel facture) async {
    final String? currentAdminId = context.read<UserProfileProvider>().userData?.uid;
    if (facture.assignedAdminId != currentAdminId) {
      _showErrorSnackBar("Action non autorisée : Ce dossier ne vous est pas assigné.");
      return;
    }

    final TextEditingController motifController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final bool proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Gestion du Litige / Refus", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Le locataire refuse le bien. En confirmant, le logement redevient disponible et le client est remboursé sur son portefeuille électronique.",
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: motifController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Motif obligatoire du refus",
                  labelStyle: TextStyle(color: Colors.red.shade900),
                  hintText: "Ex: Infiltration d'eau non signalée, accès véhicule impossible...",
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red.shade700)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Veuillez saisir un motif pour justifier le refus.";
                  }
                  if (value.trim().length < 10) {
                    return "Soyez plus explicite (10 caractères min).";
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER")),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            child: const Text("CONFIRMER LE REMBOURSEMENT"),
          ),
        ],
      ),
    ) ?? false;

    if (!proceed) return;

    final String motifSaisi = motifController.text.trim();

    setState(() => _isProcessing = true);
    final batch = FirebaseFirestore.instance.batch();

    final propRef = FirebaseFirestore.instance.collection(FirestoreCollections.properties).doc(facture.propertyId);
    batch.update(propRef, {
      FirestoreFields.status: PropertyStatus.disponible,
      FirestoreFields.isVisible: true,
      FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
    });

    final walletRef = FirebaseFirestore.instance.collection(FirestoreCollections.wallets).doc(facture.clientId);
    batch.set(walletRef, {
      'balance': FieldValue.increment(facture.totalUSD),
      'lastUpdate': FieldValue.serverTimestamp(),
      'userUid': facture.clientId,
      'currency': 'USD',
    }, SetOptions(merge: true));

    final factureRef = FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(facture.id);
    batch.update(factureRef, {
      FactureFields.etapeDossier: FactureFields.etapeRemboursementWallet,
      FactureFields.dateLitigeRegle: FieldValue.serverTimestamp(),
      FactureFields.statutFinal: FactureFields.statutLitigeRegle,
      FactureFields.motifRejet: motifSaisi,
      FactureFields.adminRejector: currentAdminId,
    });

    final logRef = FirebaseFirestore.instance.collection(FirestoreCollections.adminLogs).doc();
    batch.set(logRef, {
      AdminLogFields.typeAction: AdminLogFields.actionRefusWallet,
      AdminLogFields.adminName: context.read<UserProfileProvider>().agentFullName,
      "adminId": currentAdminId,
      AdminLogFields.factureId: facture.id,
      AdminLogFields.propertyRef: facture.refMaison,
      AdminLogFields.amount: facture.totalUSD,
      AdminLogFields.dateAction: FieldValue.serverTimestamp(),
      AdminLogFields.details: "Refus après visite terrain. Bien libéré. Motif : $motifSaisi",
    });

    try {
      await batch.commit();
      if (mounted) {
        context.read<AdminCountsProvider>().refresh(adminId: currentAdminId);
        _showSuccessSnackBar("Litige réglé avec succès : Maison libérée et Client crédité.");
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar("Erreur lors de la gestion du litige : $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- 3. LOGIQUE ATOMIQUE ---
  Future<void> _executeSecureAction({
    required FactureModel facture,
    required DateTime dateDebutBail,
    required Map<String, dynamic> factureUpdate,
    required Map<String, dynamic> propertyUpdate,
    required String actionType,
    required Map<String, dynamic> rawData,
    String details = "",
  }) async {
    final profileProvider = context.read<UserProfileProvider>();
    final String? currentAdminId = profileProvider.userData?.uid;

    if (facture.assignedAdminId != currentAdminId) {
      _showErrorSnackBar("Action non autorisée : Ce dossier ne vous est pas assigné.");
      return;
    }

    setState(() => _isProcessing = true);

    final batch = FirebaseFirestore.instance.batch();
    
    final factureRef = FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(facture.id);
    final propRef = FirebaseFirestore.instance.collection(FirestoreCollections.properties).doc(facture.propertyId);
    final logRef = FirebaseFirestore.instance.collection(FirestoreCollections.adminLogs).doc();
    final contractRef = FirebaseFirestore.instance.collection(FirestoreCollections.contrats).doc();

    final int moisGarantie = facture.nbMoisGarantie;
    final DateTime dateFinContrat = DateHelper.ajouterMois(dateDebutBail, moisGarantie);
    final DateTime prochainPaiement = DateHelper.ajouterMois(dateDebutBail, 1);

    final String? agentTerrainId = rawData[FactureFields.agentTerrainId];
    final String finalAgentTerrainId = (agentTerrainId != null && agentTerrainId.isNotEmpty) 
        ? agentTerrainId 
        : (currentAdminId ?? 'unknown_admin');

    batch.update(factureRef, factureUpdate);
    batch.update(propRef, propertyUpdate);

    batch.set(contractRef, {
      ContratFields.propertyId: facture.propertyId,
      ContratFields.factureId: facture.id,
      ContratFields.locataireId: facture.clientId, 
      ContratFields.locataireNom: facture.nomClient, 
      ContratFields.locataireTel: normalizePhoneNumber(facture.telClient), 
      ContratFields.bailleurId: facture.bailleurId, 
      ContratFields.nomBailleur: facture.nomBailleur ?? "EasyLocation Admin",
      ContratFields.bailleurTel: normalizePhoneNumber(facture.telBailleur ?? "000000000"),
      ContratFields.refMaison: facture.refMaison,
      ContratFields.loyerMensuel: facture.loyer,
      ContratFields.devise: 'USD',
      
      ContratFields.agentTerrainId: finalAgentTerrainId,
      
      ContratFields.referenceContrat: _generateContractRef(facture.id!),
      ContratFields.createdAt: FieldValue.serverTimestamp(),
      ContratFields.updatedAt: FieldValue.serverTimestamp(),

      ContratFields.dateDebut: Timestamp.fromDate(dateDebutBail),
      ContratFields.dateFin: Timestamp.fromDate(dateFinContrat), 
      ContratFields.prochainPaiement: Timestamp.fromDate(prochainPaiement),
      ContratFields.nbMoisGarantie: moisGarantie,

      ContratFields.status: ContratFields.statusActive, 
      ContratFields.statut: ContratFields.statutActif,
      ContratFields.statutPaiement: ContratFields.paiementPaye,
    });

    batch.set(logRef, {
      AdminLogFields.typeAction: actionType,
      AdminLogFields.adminName: profileProvider.agentFullName,
      "adminId": currentAdminId,
      AdminLogFields.adminRole: profileProvider.userData?.activeRole ?? "Admin",
      AdminLogFields.factureId: facture.id,
      AdminLogFields.dateAction: FieldValue.serverTimestamp(),
      AdminLogFields.details: details,
    });

    try {
      await batch.commit();
      
      // ✅ Déclenchement des notifications après succès du batch
      await _envoyerNotificationsCloture(facture);

      if (mounted) {
        context.read<AdminCountsProvider>().refresh(adminId: currentAdminId); 
        _showSuccessSnackBar("Contrat généré et notifications envoyées.");
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar("Erreur : $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentAdminId = context.read<UserProfileProvider>().userData?.uid;

    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(FirestoreCollections.factures)
              .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPaid)
              .where(FactureFields.assignedAdminId, isEqualTo: currentAdminId)
              .where(FactureFields.etapeDossier, isNotEqualTo: FactureFields.etapeCloture) 
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            final docs = snapshot.data?.docs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return d[FactureFields.statutFinal] != FactureFields.statutTermine;
            }).toList() ?? [];

            if (docs.isEmpty) return _buildEmptyState("Aucune remise de clés assignée.");

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var doc = docs[index];
                var data = doc.data() as Map<String, dynamic>;
                final facture = FactureModel.fromMap(data, doc.id);
                final String statutLocataire = data[FactureFields.confirmationLocataire] ?? 'en_attente';
                
                return _buildFactureCard(facture, statutLocataire, data, index + 1, doc.id);
              },
            );
          },
        ),
        if (_isProcessing) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
      ],
    );
  }

  Widget _buildFactureCard(FactureModel facture, String statut, Map<String, dynamic> data, int numeroLigne, String uid) {
    bool isRefuse = (statut == 'refuse');
    Color btnColor = isRefuse ? Colors.red.shade700 : const Color(0xFF0D47A1);
    
    String nomCompletBailleur = facture.nomBailleur ?? 'Non renseigné';
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: btnColor.withOpacity(0.1),
                radius: 18,
                child: Text(
                  "$numeroLigne", 
                  style: TextStyle(fontWeight: FontWeight.bold, color: btnColor, fontSize: 13)
                ),
              ),
              title: Row(
                children: [
                  Icon(Icons.vpn_key, color: btnColor, size: 16),
                  const SizedBox(width: 6),
                  Text("Réf : ${facture.refMaison}", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              trailing: Text("${facture.totalUSD} \$", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
            ),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("👤 Locataire :", style: TextStyle(fontWeight: FontWeight.bold, color: btnColor, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(facture.nomClient, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      InkWell(
                        onTap: () async {
                          final Uri telUri = Uri.parse("tel:${facture.telClient}");
                          if (await canLaunchUrl(telUri)) await launchUrl(telUri);
                        },
                        child: Text(
                          "📞 ${facture.telClient}", 
                          style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Container(
                  height: 45,
                  width: 1,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("🏠 Bailleur :", style: TextStyle(fontWeight: FontWeight.bold, color: btnColor, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(nomCompletBailleur, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      InkWell(
                        onTap: () async {
                          if (facture.telBailleur != null) {
                            final Uri telUri = Uri.parse("tel:${facture.telBailleur}");
                            if (await canLaunchUrl(telUri)) await launchUrl(telUri);
                          }
                        },
                        child: Text(
                          "📞 ${facture.telBailleur ?? 'Non renseigné'}",
                          style: TextStyle(
                            color: facture.telBailleur != null ? Colors.blue : Colors.black54,
                            decoration: facture.telBailleur != null ? TextDecoration.underline : TextDecoration.none,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: btnColor.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                child: Text("Statut : ${statut.toUpperCase()}", style: TextStyle(color: btnColor, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ),
            
            const SizedBox(height: 14),

            BoutonAssignationAgentWidget(
              factureId: uid,
              currentAgentTerrainId: data[FactureFields.agentTerrainId],
              villeMaison: data['villeMaison'] ?? 'Bukavu',
            ),

            const Divider(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: btnColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: isRefuse ? () => _gererRefus(facture) : () => _confirmerRemiseCles(facture, data),
                child: Text(
                  isRefuse ? "GÉRER LE REFUS / LITIGE" : "VALIDER LA REMISE DES CLÉS",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) => Center(child: Text(msg, style: const TextStyle(color: Colors.grey)));

  void _showSuccessSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  void _showErrorSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
}