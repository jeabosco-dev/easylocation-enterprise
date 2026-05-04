// lib/widgets/admin/onglet_remise_cles.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart';
import 'package:easylocation_mvp/models/facture_model.dart';
import 'package:easylocation_mvp/utils/phone_utils.dart';
import 'package:easylocation_mvp/utils/date_helper.dart';

class OngletRemiseCles extends StatefulWidget {
  const OngletRemiseCles({super.key});

  @override
  State<OngletRemiseCles> createState() => _OngletRemiseClesState();
}

class _OngletRemiseClesState extends State<OngletRemiseCles> {
  bool _isProcessing = false;

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

  // --- 1. LOGIQUE DE CLÔTURE (REUSSITE) ---
  Future<void> _confirmerRemiseCles(FactureModel facture, Map<String, dynamic> rawData) async {
    final String statutLocataire = rawData[FactureFields.confirmationLocataire] ?? 'en_attente';
    
    // Initialisation par défaut à "Aujourd'hui"
    DateTime dateChoisie = DateTime.now();

    // Dialogue de confirmation qui permet de modifier la date
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

  // --- 2. LOGIQUE DE REFUS ---
  Future<void> _gererRefus(FactureModel facture) async {
    // 🛡️ VERROU DE SÉCURITÉ : Vérifier si l'admin actuel est bien l'assigné
    final String? currentAdminId = context.read<UserProfileProvider>().userData?.uid;
    if (facture.assignedAdminId != currentAdminId) {
      _showErrorSnackBar("Action non autorisée : Ce dossier ne vous est pas assigné.");
      return;
    }

    final bool confirm = await _showSimpleConfirmDialog(
      "Gérer le litige / Refus", 
      "Le locataire refuse le bien. En confirmant :\n1. Le bien redevient 'LIBRE'.\n2. Le client est crédité de ${facture.totalUSD}\$ sur son Wallet."
    );

    if (!confirm) return;

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
    });

    final logRef = FirebaseFirestore.instance.collection(FirestoreCollections.adminLogs).doc();
    batch.set(logRef, {
      AdminLogFields.typeAction: AdminLogFields.actionRefusWallet,
      AdminLogFields.adminName: context.read<UserProfileProvider>().agentFullName,
      "adminId": currentAdminId, // Ajout de l'ID pour l'audit trail
      AdminLogFields.factureId: facture.id,
      AdminLogFields.propertyRef: facture.refMaison,
      AdminLogFields.amount: facture.totalUSD,
      AdminLogFields.dateAction: FieldValue.serverTimestamp(),
      AdminLogFields.details: "Refus après visite. Bien libéré et client crédité.",
    });

    try {
      await batch.commit();
      if (mounted) {
        context.read<AdminCountsProvider>().refresh();
        _showSuccessSnackBar("Litige réglé : Maison LIBRE et Client crédité.");
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
    String details = "",
  }) async {
    final profileProvider = context.read<UserProfileProvider>();
    final String? currentAdminId = profileProvider.userData?.uid;

    // 🛡️ VERROU DE SÉCURITÉ : Empêcher l'exécution si l'ID ne correspond pas
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
      ContratFields.loyerMensuel: facture.loyer ?? 0.0,
      ContratFields.devise: 'USD',
      ContratFields.agentId: currentAdminId,
      ContratFields.referenceContrat: "CTR-${facture.id}",
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
      "adminId": currentAdminId, // Ajout de l'ID pour l'audit trail
      AdminLogFields.adminRole: profileProvider.userData?.activeRole ?? "Admin",
      AdminLogFields.factureId: facture.id,
      AdminLogFields.dateAction: FieldValue.serverTimestamp(),
      AdminLogFields.details: details,
    });

    try {
      await batch.commit();
      if (mounted) {
        context.read<AdminCountsProvider>().refresh(); 
        _showSuccessSnackBar("Contrat généré avec succès.");
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
              // ✅ Filtrage par statuts de succès (Interne ou MaxiCash)
              .where(FactureFields.paymentStatus, whereIn: [FactureFields.statusPaid, 'success'])
              // ✅ Seul l'agent qui a capturé le dossier le voit
              .where('assignedAdminId', isEqualTo: currentAdminId)
              // ✅ Exclure les dossiers déjà clôturés
              .where(FactureFields.etapeDossier, isNotEqualTo: FactureFields.etapeCloture) 
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            // Filtrage manuel pour le statut final
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
                
                return _buildFactureCard(facture, statutLocataire, data);
              },
            );
          },
        ),
        if (_isProcessing) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
      ],
    );
  }

  Widget _buildFactureCard(FactureModel facture, String statut, Map<String, dynamic> data) {
    Color btnColor = (statut == 'refuse') ? Colors.red.shade700 : const Color(0xFF0D47A1);
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.vpn_key, color: btnColor),
              title: Text("Réf : ${facture.refMaison}", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Client : ${facture.nomClient}\nStatut Locataire : $statut"),
              trailing: Text("${facture.totalUSD} \$", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ),
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: btnColor, foregroundColor: Colors.white),
                onPressed: statut == 'refuse' ? () => _gererRefus(facture) : () => _confirmerRemiseCles(facture, data),
                child: Text(statut == 'refuse' ? "GÉRER LE REFUS" : "VALIDER LA REMISE"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) => Center(child: Text(msg, style: const TextStyle(color: Colors.grey)));

  Future<bool> _showSimpleConfirmDialog(String title, String content) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("OK")),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  void _showErrorSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
}