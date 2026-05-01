// lib/screens/historique_paiements_locataire_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/contract_provider.dart';
import '../models/payment_model.dart';
import '../models/contract_model.dart';
import '../services/pdf_service.dart';
import '../services/config_service.dart'; // ✅ Import pour companyInfo

class HistoriquePaiementsLocatairePage extends StatelessWidget {
  final ContractModel contrat;

  const HistoriquePaiementsLocatairePage({super.key, required this.contrat});

  @override
  Widget build(BuildContext context) {
    // ✅ Récupération de la configuration entreprise
    final config = context.read<ConfigService>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Mes Paiements & Reçus",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  onPressed: () => PdfService.genererRapportCompletLocation(
                    paiements: snapshot.data!,
                    titre: "Historique des paiements - ${contrat.refMaison}", // ✅ Paramètre titre ajouté
                  ),
                  tooltip: "Exporter tout l'historique",
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
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Impossible de charger l'historique : ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
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
                  // ✅ CORRECTION : Utilisation de 'contrat' et ajout de 'companyInfo'
                  onTap: () => PdfService.genererRecuUnique(
                    contrat: contrat,
                    paiement: p,
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
                            color: Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                        ),
                        const SizedBox(width: 16),
                        
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Paiement validé",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Le ${DateFormat('dd/MM/yyyy à HH:mm').format(p.dateOperation)}",
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.download_rounded, size: 14, color: Colors.blueAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Télécharger le reçu",
                                    style: TextStyle(
                                      fontSize: 11, 
                                      color: Colors.blueAccent[700],
                                      fontWeight: FontWeight.w600
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${p.montantTotal} \$",
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              "Couvre ${p.nbMoisPayes} mois",
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            ),
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
          Icon(Icons.receipt_long_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            "Aucun reçu disponible",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Dès que vous effectuez un paiement et que le bailleur le valide, vos reçus apparaîtront ici.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}