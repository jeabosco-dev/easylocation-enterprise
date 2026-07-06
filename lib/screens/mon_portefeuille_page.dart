// lib/screens/mon_portefeuille_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/phone_utils.dart';
import '../providers/wallet_provider.dart';
import '../widgets/wallet/wallet_balance_card.dart';
import '../widgets/wallet/wallet_actions_bar.dart';
import '../widgets/wallet/transaction_list_tile.dart';

class MonPortefeuillePage extends StatefulWidget {
  const MonPortefeuillePage({super.key});

  @override
  State<MonPortefeuillePage> createState() => _MonPortefeuillePageState();
}

class _MonPortefeuillePageState extends State<MonPortefeuillePage> {
  final GlobalKey<State<WalletActionsBar>> _actionsBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<WalletProvider>();
      final userPhone = provider.wallet?.phoneNumber;
      
      if (userPhone != null) {
        final normalizedPhone = normalizePhoneNumber(userPhone);
        provider.listenToIncomingRequests(normalizedPhone);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final wallet = walletProvider.wallet;
    final transactions = walletProvider.transactions;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Mon Portefeuille",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: wallet == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => walletProvider.refreshAll(wallet.userId),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // --- STREAM POUR SUIVI DES DEMANDES DE RETRAIT ---
                  if (currentUser != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('withdraw_requests')
                          .where('userId', isEqualTo: currentUser.uid)
                          .where('status', whereIn: ['pending', 'approved', 'rejected'])
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                          final doc = snapshot.data!.docs.first;
                          final status = doc['status'];
                          final amount = doc['amount'];

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: status == 'pending' ? Colors.blue.shade50 : (status == 'approved' ? Colors.green.shade50 : Colors.red.shade50),
                            child: ListTile(
                              leading: Icon(
                                status == 'pending' ? Icons.access_time : (status == 'approved' ? Icons.check_circle : Icons.error),
                                color: status == 'pending' ? Colors.blue : (status == 'approved' ? Colors.green : Colors.red),
                              ),
                              title: Text("Retrait de ${amount} \$"),
                              subtitle: Text("Statut : ${status.toUpperCase()}"),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  
                  // --- STREAM POUR NOTIFICATIONS PAIEMENT (EXISTANT) ---
                  if (currentUser != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('payment_requests')
                          .where('fromId', isEqualTo: currentUser.uid)
                          .where('status', whereIn: ['rejected', 'accepted'])
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                          final doc = snapshot.data!.docs.first;
                          final status = doc['status'];
                          final amount = doc['amount'];

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(status == 'accepted' 
                                    ? "Succès : Votre demande de $amount \$ a été acceptée !" 
                                    : "Votre demande de $amount \$ a été refusée."),
                                backgroundColor: status == 'accepted' ? Colors.green : Colors.red,
                              ),
                            );
                            FirebaseFirestore.instance.collection('payment_requests').doc(doc.id).delete();
                          });
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  
                  WalletBalanceCard(wallet: wallet),
                  _buildIncomingRequests(walletProvider),
                  const SizedBox(height: 10),
                  WalletActionsBar(key: _actionsBarKey, wallet: wallet),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
                    child: Text(
                      "Historique des transactions",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (transactions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Text("Aucune transaction pour le moment", style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: transactions.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final String currentUid = currentUser?.uid ?? '';
                        return TransactionListTile(
                          transaction: transactions[index],
                          currentUserId: currentUid,
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildIncomingRequests(WalletProvider provider) {
    if (provider.incomingRequests.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Demandes reçues", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 10),
          ...provider.incomingRequests.map((req) => Card(
                elevation: 0,
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.orange.shade100),
                ),
                child: ListTile(
                  title: Text("${req['senderName'] ?? 'Utilisateur'} vous demande ${req['amount']} \$"),
                  subtitle: Text(
                    req['senderPhone'] != null ? "Tél : ${req['senderPhone']}" : "N° inconnu",
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () {
                          final state = _actionsBarKey.currentState;
                          if (state != null) {
                            (state as dynamic).showAcceptDialog(context, req);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => provider.rejectPaymentRequest(req['id']),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}