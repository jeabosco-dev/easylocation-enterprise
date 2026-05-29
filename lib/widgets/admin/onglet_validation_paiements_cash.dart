import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:easylocation_mvp/models/facture_model.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart'; 
import 'package:url_launcher/url_launcher.dart';

import 'package:easylocation_mvp/services/goal_tracking_service.dart';
import 'package:easylocation_mvp/models/community_goal_model.dart';

class OngletValidationPaiementsCash extends StatefulWidget {
  const OngletValidationPaiementsCash({super.key});

  @override
  State<OngletValidationPaiementsCash> createState() => _OngletValidationPaiementsCashState();
}

class _OngletValidationPaiementsCashState extends State<OngletValidationPaiementsCash> {
  bool _voirDossiersPublics = false;
  Timer? _timerRafraichissement;

  @override
  void initState() {
    super.initState();
    // Rafraîchit l'interface toutes les minutes pour recalculer l'état d'expiration du cash
    _timerRafraichissement = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timerRafraichissement?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? myId = context.watch<UserProfileProvider>().userData?.uid;

    if (myId == null) {
      return const Center(child: Text("Erreur d'authentification agent."));
    }

    // ✅ ÉTAPE 1 : Sécurisation de la requête avec agentTerrainId uniquement
    Query query = FirebaseFirestore.instance
        .collection(FirestoreCollections.factures)
        .where(FactureFields.paymentStatus, isEqualTo: FactureFields.statusPending)
        .where(FactureFields.methodePaiement, isEqualTo: 'cash');

    if (_voirDossiersPublics) {
      query = query.where(FactureFields.agentTerrainId, isNull: true);
    } else {
      query = query.where(FactureFields.agentTerrainId, isEqualTo: myId);
    }

    query = query.orderBy(FactureFields.dateCreation, descending: true);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("Mes Dossiers Cash", style: TextStyle(fontWeight: FontWeight.bold))),
                  selected: !_voirDossiersPublics,
                  selectedColor: const Color(0xFF1E293B),
                  labelStyle: TextStyle(color: !_voirDossiersPublics ? Colors.white : Colors.black87),
                  onSelected: (selected) {
                    if (selected) setState(() => _voirDossiersPublics = false);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("Cash Publics", style: TextStyle(fontWeight: FontWeight.bold))),
                  selected: _voirDossiersPublics,
                  selectedColor: Colors.orange.shade800,
                  labelStyle: TextStyle(color: _voirDossiersPublics ? Colors.white : Colors.black87),
                  onSelected: (selected) {
                    if (selected) setState(() => _voirDossiersPublics = true);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Erreur : ${snapshot.error}"));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  // Récupération sécurisée du compteur de rallonges depuis Firestore
                  final int rallongesCount = data['rallongeCount'] ?? 0;
                  
                  final facture = FactureModel.fromMap(data, doc.id);
                  return _buildFactureCard(context, facture, myId, index + 1, rallongesCount);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFactureCard(BuildContext context, FactureModel facture, String myId, int numeroLigne, int rallongesCount) {
    final now = DateTime.now();
    final bool isExpired = facture.dateExpiration != null && facture.dateExpiration!.isBefore(now);
    
    IconData statusIcon = isExpired ? Icons.timer_off : Icons.point_of_sale;
    Color statusColor = isExpired ? Colors.red : Colors.orange;

    // Calcul de la durée restante ou dépassée
    String texteDuree = "";
    if (facture.dateExpiration != null) {
      final difference = facture.dateExpiration!.difference(now);
      if (difference.isNegative) {
        texteDuree = "⛔ Dépassé de : ${difference.inMinutes.abs()} min";
      } else {
        texteDuree = "⏳ Reste : ${difference.inMinutes} min";
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: isExpired ? Colors.red.shade300 : Colors.orange.shade200, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: isExpired ? Colors.red.shade50 : Colors.orange.shade50,
                radius: 18,
                child: Text("$numeroLigne", style: TextStyle(fontWeight: FontWeight.bold, color: isExpired ? Colors.red.shade900 : Colors.orange.shade900, fontSize: 13)),
              ),
              title: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      facture.nomClient, 
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _badge("CASH", Colors.orange),
                  if (isExpired) _badge("EXPIRÉ", Colors.red),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text("🏠 Réf Maison : ${facture.refMaison}", style: const TextStyle(fontSize: 13)),
                  Text("💰 Montant : ${facture.totalUSD} USD", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  if (texteDuree.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      texteDuree, 
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w600, 
                        color: isExpired ? Colors.red.shade700 : Colors.grey.shade700
                      )
                    ),
                  ]
                ],
              ),
              trailing: IconButton.filledTonal(
                icon: const Icon(Icons.phone),
                onPressed: () => launchUrl(Uri.parse("tel:${facture.telClient}")),
                style: IconButton.styleFrom(foregroundColor: Colors.green),
              ),
            ),
            const Divider(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _informerBailleurWhatsApp(context, facture),
                    icon: const Icon(Icons.send, size: 18, color: Colors.green),
                    label: const Text("WHATSAPP"),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  ),
                  const SizedBox(width: 6),
                  
                  // Condition d'affichage / blocage de la rallonge à 3 maximum
                  if (rallongesCount < 3)
                    TextButton.icon(
                      onPressed: () => _prolongerDelai(context, facture),
                      icon: const Icon(Icons.add_alarm, size: 18),
                      label: Text("DÉLAI +1H ($rallongesCount/3)"),
                      style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
                    )
                  else
                    TextButton.icon(
                      onPressed: null, 
                      icon: const Icon(Icons.block, size: 18, color: Colors.grey),
                      label: const Text("MAX RALLONGES"),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                    ),
                  
                  const SizedBox(width: 6),
                  _voirDossiersPublics 
                    ? ElevatedButton.icon(
                        onPressed: () => _captureDossier(context, facture, myId),
                        icon: const Icon(Icons.pan_tool_alt, size: 18),
                        label: const Text("CAPTURER"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          if (isExpired) {
                            _showActionExpireeDialog(context, facture, myId);
                          } else {
                            _showValidationDialog(context, facture, myId);
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text("VALIDER CASH"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                      ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _captureDossier(BuildContext context, FactureModel facture, String myId) async {
    final DocumentReference factureRef = FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(facture.id);
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(factureRef);
        if (!snapshot.exists) throw Exception("Dossier introuvable.");
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        
        // Extraction exclusive avec la nouvelle clé agentTerrainId
        String? currentAgentTerrainId = data[FactureFields.agentTerrainId];

        if (currentAgentTerrainId != null && currentAgentTerrainId.isNotEmpty) {
          throw Exception("Désolé, ce dossier cash a déjà été capturé !");
        }

        transaction.update(factureRef, {
          FactureFields.agentTerrainId: myId,
          FactureFields.assignedAdminId: myId, // Si capturé par un admin, il devient le validateur par défaut.
          'dateCaptureAgent': FieldValue.serverTimestamp(),
        });
      });

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dossier Cash ajouté à votre liste !"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showConflictDialog(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  void _showConflictDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Conflit de capture")]),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  Future<void> _prolongerDelai(BuildContext context, FactureModel facture) async {
    if (facture.dateExpiration == null) return;
    final nouvelleDate = facture.dateExpiration!.add(const Duration(hours: 1));
    
    await FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(facture.id).update({
      'dateExpiration': Timestamp.fromDate(nouvelleDate),
      'rallongeCount': FieldValue.increment(1),
      'dateDerniereRallonge': FieldValue.serverTimestamp(),
    });
    if (mounted) setState(() {});
  }

  Future<void> _process(BuildContext context, FactureModel facture, bool ok, String adminId, {String? motif}) async {
    final DocumentReference factureRef = FirebaseFirestore.instance.collection(FirestoreCollections.factures).doc(facture.id);
    final DocumentReference proprieteRef = FirebaseFirestore.instance.collection(FirestoreCollections.properties).doc(facture.propertyId); 
    final GoalTrackingService goalService = GoalTrackingService();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(factureRef, {
          FactureFields.paymentStatus: ok ? FactureFields.statusPaid : FactureFields.statusRejected,
          FactureFields.etapeDossier: ok ? FactureFields.etapePaye : FactureFields.etapeAnnule, 
          FactureFields.motifRejet: motif,
          FactureFields.dateActionAdmin: FieldValue.serverTimestamp(),
          FactureFields.assignedAdminId: adminId,
        });
        transaction.update(proprieteRef, {
          FirestoreFields.status: ok ? PropertyStatus.reserved : PropertyStatus.disponible,
          FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
        });
      });

      if (ok) {
        final String villeAction = (facture.ville != null && facture.ville!.isNotEmpty) ? facture.ville! : 'bukavu'; 
        unawaited(goalService.trackAction(ville: villeAction, type: MissionType.reservations));
      }

      if (context.mounted) {
        context.read<AdminCountsProvider>().refresh(); 
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? "Encaissement enregistré !" : "Réservation annulée."), backgroundColor: ok ? Colors.green : Colors.red, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur transaction : $e"), backgroundColor: Colors.red));
    }
  }

  void _showValidationDialog(BuildContext context, FactureModel facture, String myId) {
    final TextEditingController motifController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Encaisser Cash : ${facture.nomClient}"),
        content: TextField(controller: motifController, decoration: const InputDecoration(labelText: "Note ou observation de réception", border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          OutlinedButton(onPressed: () => _process(context, facture, false, myId, motif: motifController.text), style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text("REJETER / LIBÉRER")),
          ElevatedButton(onPressed: () => _process(context, facture, true, myId, motif: motifController.text), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text("CONFIRMER RECEPTION")),
        ],
      ),
    );
  }

  void _showActionExpireeDialog(BuildContext context, FactureModel facture, String myId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.timer_off, color: Colors.red),
            SizedBox(width: 8),
            Text("Dossier Expiré"),
          ],
        ),
        content: const Text(
          "Le délai de paiement Cash réglementaire est dépassé.\n\n"
          "Que souhaitez-vous faire ?",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _process(
                context,
                facture,
                false,
                myId,
                motif: "Expiration délai cash automatique",
              );
            },
            child: const Text("ANNULER & LIBÉRER"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showValidationDialog(context, facture, myId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text("FORCER VALIDATION"),
          ),
        ],
      ),
    );
  }

  void _informerBailleurWhatsApp(BuildContext context, FactureModel facture) async {
    String telephone = (facture.telBailleur ?? "").replaceAll(' ', ''); 
    if (telephone.isEmpty) return;
    if (telephone.startsWith('0')) telephone = "243${telephone.substring(1)}";
    final String message = "Bonjour, l'acompte pour votre maison (Réf: ${facture.refMaison}) est en cours d'encaissement direct au guichet.";
    final String url = "https://wa.me/$telephone?text=${Uri.encodeComponent(message)}";
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.monetization_on_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), const Text("Aucun versement Cash attendu", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]));
  }
}