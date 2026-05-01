import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  @override
  void initState() {
    super.initState();
    // Écoute des demandes dès l'initialisation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userPhone = context.read<WalletProvider>().wallet?.phoneNumber;
      if (userPhone != null) {
        context.read<WalletProvider>().listenToIncomingRequests(userPhone);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final wallet = walletProvider.wallet;
    final transactions = walletProvider.transactions;

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
                  // Widget de la carte de solde (Header)
                  WalletBalanceCard(wallet: wallet),

                  // Section des demandes de paiement reçues
                  _buildIncomingRequests(walletProvider),

                  const SizedBox(height: 10),

                  // Barre d'actions (Envoyer, Demander, Recharger)
                  WalletActionsBar(wallet: wallet),

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
                        child: Text(
                          "Aucune transaction pour le moment",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: transactions.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) => TransactionListTile(
                        transaction: transactions[index],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // --- LOGIQUE DES DEMANDES REÇUES ---

  Widget _buildIncomingRequests(WalletProvider provider) {
    if (provider.incomingRequests.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Demandes reçues",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 10),
          ...provider.incomingRequests.map((req) => Card(
                elevation: 0,
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.orange.shade100),
                ),
                child: ListTile(
                  title: Text("${req['fromName']} vous demande ${req['amount']} \$"),
                  subtitle: const Text("Voulez-vous accepter ?", style: TextStyle(fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _confirmAcceptRequest(context, req),
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

  void _confirmAcceptRequest(BuildContext context, Map<String, dynamic> req) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Accepter la demande"),
        content: Text("Voulez-vous envoyer ${req['amount']} \$ à ${req['fromName']} ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("NON"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _showLoading(context);
              try {
                await context.read<WalletProvider>().acceptPaymentRequest(req);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("OUI, PAYER"),
          )
        ],
      ),
    );
  }

  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }
}