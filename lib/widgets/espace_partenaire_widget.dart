// lib/widgets/espace_partenaire_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';

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
        String? partnerId = userData?['partner_linked_id'];

        if (partnerId == null || partnerId.isEmpty) return const SizedBox.shrink();

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('partenaires').doc(partnerId).snapshots(),
          builder: (context, partnerSnapshot) {
            if (partnerSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (!partnerSnapshot.hasData || partnerSnapshot.data!.data() == null) {
              return const SizedBox.shrink();
            }

            var partData = partnerSnapshot.data!.data() as Map<String, dynamic>;
            double solde = (partData['solde_commission'] ?? 0.0).toDouble();
            int totalConv = partData['total_conversions'] ?? 0;
            String nomPartenaire = partData['nom'] ?? "Partenaire";

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 25),
              decoration: BoxDecoration(
                color: Colors.white, // FIX: Blanc pur pour bloquer la transparence
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5), // Ombre portée vers le haut
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Barre de saisie visuelle pour le BottomSheet
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
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
                                letterSpacing: 0.5
                              ),
                            ),
                            const Text(
                              "EASYLOCATION ENTERPRISE - BUSINESS", // Branding mis à jour
                              style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${solde.toStringAsFixed(2)} \$",
                            style: const TextStyle(
                              fontSize: 28, 
                              fontWeight: FontWeight.bold, 
                              color: Color(0xFF2E7D32) // Vert plus foncé pour lisibilité
                            ),
                          ),
                          Text(
                            "$totalConv locations via votre code", 
                            style: TextStyle(fontSize: 11, color: Colors.grey[700])
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: solde > 0 ? () => _showWithdrawDialog(context, partnerId, solde) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E5D8F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3, // Relief pour l'affordance cliquable
                        ),
                        child: const Text("RETIRER", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: solde > 0 ? () => _showTransferAsCreditDialog(context, partnerId, solde) : null,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text("ENVOYER DU CRÉDIT À UN TIERS", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E5D8F),
                        side: const BorderSide(color: Color(0xFF1E5D8F), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- LOGIQUE DE TRANSFERT DE CRÉDIT ---
  void _showTransferAsCreditDialog(BuildContext context, String partnerId, double maxAmount) {
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Envoyer du EasyCredit", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Le montant sera déduit de vos commissions pour être envoyé comme crédit service au destinataire.",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "N° Téléphone du bénéficiaire", 
                  prefixIcon: Icon(Icons.phone, size: 20),
                ),
                validator: (val) => (val == null || val.isEmpty) ? "Numéro requis" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Montant à envoyer (\$)", suffixText: "\$"),
                validator: (val) {
                  if (val == null || val.isEmpty) return "Montant requis";
                  double? amt = double.tryParse(val);
                  if (amt == null || amt <= 0) return "Invalide";
                  if (amt > maxAmount) return "Solde insuffisant";
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E5D8F)),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final String phone = phoneController.text.trim();
                final double amount = double.parse(amountController.text);
                Navigator.pop(dialogContext);
                _verifyAndTransfer(context, partnerId, phone, amount);
              }
            },
            child: const Text("VÉRIFIER & ENVOYER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _verifyAndTransfer(BuildContext context, String partnerId, String phone, double amount) async {
    final walletProvider = context.read<WalletProvider>();
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    final String? recipientName = await walletProvider.getUserNameByPhone(phone);
    if (!context.mounted) return;
    Navigator.pop(context);

    if (recipientName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur non trouvé sur EasyLocation.")));
      return;
    }

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Confirmer l'envoi"),
        content: Text("Envoyer $amount \$ à $recipientName ?\n\nNote: Ce montant sera converti en crédit utilisable sur l'application."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("ANNULER")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(c);
              _executePartnerTransfer(context, partnerId, phone, amount);
            },
            child: const Text("OUI, ENVOYER"),
          )
        ],
      ),
    );
  }

  void _executePartnerTransfer(BuildContext context, String partnerId, String phone, double amount) async {
    try {
      await context.read<WalletProvider>().sendCreditsFromPartner(
        partnerId: partnerId, 
        receiverPhone: phone, 
        amount: amount
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Transfert réussi !"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _showWithdrawDialog(BuildContext context, String partnerId, double montant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Demander mon paiement"),
        content: Text(
          "Souhaitez-vous retirer vos $montant \$ ?\n\n"
          "Notre équipe vous contactera pour finaliser le paiement via Mobile Money ou au bureau EasyLocation Enterprise."
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('demandes_retrait').add({
                'partner_id': partnerId,
                'montant': montant,
                'date': FieldValue.serverTimestamp(),
                'statut': 'EN_ATTENTE',
              });
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ Demande envoyée avec succès !"), backgroundColor: Colors.green)
              );
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("CONFIRMER LE RETRAIT"),
          ),
        ],
      ),
    );
  }
}