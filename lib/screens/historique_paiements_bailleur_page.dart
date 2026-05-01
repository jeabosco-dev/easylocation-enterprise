import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/contract_provider.dart';
import '../models/payment_model.dart';
import '../models/contract_model.dart';
import '../services/pdf_service.dart';
import '../services/config_service.dart'; 

class HistoriquePaiementsBailleurPage extends StatelessWidget {
  final ContractModel contrat;

  const HistoriquePaiementsBailleurPage({super.key, required this.contrat});

  @override
  Widget build(BuildContext context) {
    final config = context.read<ConfigService>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Encaissements : ${contrat.refMaison}",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          FutureBuilder<List<PaymentModel>>(
            future: context.read<ContractProvider>().getPaymentHistory(contrat.id),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.print_rounded, color: Colors.blueAccent),
                  onPressed: () => PdfService.genererRapportCompletLocation(
                    paiements: snapshot.data!,
                    titre: "Rapport de perception - ${contrat.refMaison}",
                  ),
                  tooltip: "Exporter le rapport de perception",
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<PaymentModel>>(
        future: context.read<ContractProvider>().getPaymentHistory(contrat.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text("Erreur : ${snapshot.error}", style: const TextStyle(color: Colors.red)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final paiements = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: paiements.length,
            itemBuilder: (context, index) {
              final p = paiements[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: InkWell(
                  // ✅ CORRECTION ICI : On utilise 'contrat' et 'paiement' (en français)
                  // pour correspondre exactement à votre PdfService
                  onTap: () => PdfService.genererRecuUnique(
                    contrat: contrat,   // <-- C'était 'contract', d'où l'erreur
                    paiement: p,        // <-- C'était 'paiement' (déjà correct)
                    companyInfo: config.companyInfo,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.blue, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Loyer reçu - ${p.nbMoisPayes} mois",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Perçu le ${DateFormat('dd/MM/yyyy').format(p.dateOperation)}",
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "COMPTABILISÉ",
                                  style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "+${p.montantTotal} \$",
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            "Aucun encaissement",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const Text(
            "Les paiements validés s'afficheront ici.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}