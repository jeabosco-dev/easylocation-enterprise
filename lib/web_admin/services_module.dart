// lib/web_admin/services_module.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/service_model.dart';
import '../../providers/service_provider.dart';
import '../../services/export_service.dart'; // Import de l'export service

class ServicesModule extends StatefulWidget {
  const ServicesModule({super.key});

  @override
  State<ServicesModule> createState() => _ServicesModuleState();
}

class _ServicesModuleState extends State<ServicesModule> {
  // Fonction pour lancer l'appel téléphonique directement au locataire
  Future<void> _lancerAppel(String? telephone) async {
    if (telephone == null || telephone == "N/A" || telephone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: telephone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Impossible de lancer l'appel: $e");
    }
  }

  // Fonction d'exportation Excel basée sur la logique Finance
  void _exportExcel(List<ServiceModel> commandes) {
    // Conversion des modèles en Map pour l'ExportService
    final List<Map<String, dynamic>> dataToExport = commandes.map((c) => {
      'date': c.timestamp != null ? DateFormat('dd/MM/yyyy HH:mm').format(c.timestamp!) : 'N/A',
      'service': c.libelle,
      'type': c.typeService,
      'client': c.nomClient ?? 'Inconnu',
      'telephone': c.locataireTel ?? 'N/A',
      'prix': "${c.prix} \$",
      'statut': c.statut,
    }).toList();

    // ✅ Correction du type : passage en 'dynamic' pour accepter la List<Map> 
    // si ExportService attend des QueryDocumentSnapshot
    ExportService.exportPropertiesToExcel(
      docs: dataToExport as dynamic, 
      fileName: "Rapport_Services_SGA_${DateFormat('dd_MM_yyyy').format(DateTime.now())}",
      sheetName: "Commandes Services",
      headers: ['DATE', 'SERVICE', 'TYPE', 'CLIENT', 'TELEPHONE', 'PRIX', 'STATUT'],
      keys: ['date', 'service', 'type', 'client', 'telephone', 'prix', 'statut'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final serviceProv = context.read<ServiceProvider>();

    return StreamBuilder<List<ServiceModel>>(
      stream: serviceProv.getAllServicesCommandes(),
      builder: (context, snapshot) {
        final List<ServiceModel> commandes = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER AVEC BOUTON EXPORT ---
              _buildHeader(commandes),
              
              const SizedBox(height: 25),
              
              Expanded(
                child: Builder(builder: (context) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (commandes.isEmpty) {
                    return const Center(
                      child: Text("Aucune commande ou alerte active pour le moment."),
                    );
                  }

                  return ListView.builder(
                    itemCount: commandes.length,
                    itemBuilder: (context, index) {
                      final commande = commandes[index];
                      return _buildServiceCard(context, commande);
                    },
                  );
                }),
              ),
            ],
          ),
        );
      }
    );
  }

  // Widget d'en-tête avec le titre et le bouton d'export
  Widget _buildHeader(List<ServiceModel> filteredDocs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Centre de Commande SGA - Services & CRM",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            Text(
              "Gérez les paiements, les alertes VIP et le suivi client.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: filteredDocs.isEmpty ? null : () => _exportExcel(filteredDocs),
          icon: const Icon(Icons.download_rounded),
          label: const Text("Exporter Excel"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(BuildContext context, ServiceModel commande) {
    String dateFormatted = commande.timestamp != null 
        ? DateFormat('dd/MM/yyyy HH:mm').format(commande.timestamp!) 
        : 'Date inconnue';

    bool needsValidation = commande.statut == 'PROPOSE' || commande.statut == 'COMMANDE';
    bool isVIP = commande.typeService == 'ALERTE_IMMO' || commande.typeService == 'CHASSEUR_VIP';

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: commande.colorStatut.withOpacity(0.1),
                    child: Icon(_getServiceIcon(commande.typeService), color: commande.colorStatut, size: 28),
                  ),
                  const SizedBox(height: 10),
                  _buildStatusBadge(commande.statut, commande.colorStatut),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commande.libelle.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: Colors.blueGrey),
                        const SizedBox(width: 5),
                        Text(
                          commande.nomClient ?? "Client non identifié",
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (isVIP && commande.metadata != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("🎯 BESOINS DU CLIENT :", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                            const SizedBox(height: 4),
                            Text(
                              "Type: ${commande.metadata!['type'] ?? 'N/A'} | Zone: ${commande.metadata!['commune'] ?? 'Toute la ville'}",
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              "Budget Max: ${commande.metadata!['budgetMax'] ?? 'Non spécifié'} \$",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    if (commande.commentairesAdmin != null && commande.commentairesAdmin!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "📝 Note : ${commande.commentairesAdmin}",
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.brown),
                        ),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(thickness: 1, width: 30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("💰 ${commande.prix.toStringAsFixed(0)} \$", 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                      Text(dateFormatted, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _lancerAppel(commande.locataireTel),
                        icon: const Icon(Icons.phone_forwarded, color: Colors.blue),
                        tooltip: "Appeler le client",
                      ),
                      if (commande.statut == 'PAYE' && isVIP)
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ouverture du catalogue pour matching...")));
                          },
                          icon: const Icon(Icons.maps_home_work, color: Colors.purple),
                          tooltip: "Proposer une maison",
                        ),
                      if (needsValidation)
                        ElevatedButton(
                          onPressed: () => _showValidationDialog(context, commande),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          child: const Text("VÉRIFIER", style: TextStyle(color: Colors.white)),
                        ),
                      _buildAdminMenu(context, commande),
                    ],
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showValidationDialog(BuildContext context, ServiceModel commande) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Validation : ${commande.libelle}"),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (commande.urlPreuve != null && commande.urlPreuve!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      commande.urlPreuve!,
                      height: 350,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                ] else 
                  const Text("⚠️ Aucune preuve d'achat jointe.", style: TextStyle(color: Colors.red)),
                
                const Divider(height: 30),
                const Text("Montant à confirmer sur votre téléphone :"),
                Text("${commande.prix.toStringAsFixed(2)} USD", 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ANNULER")),
          ElevatedButton(
            onPressed: () {
              context.read<ServiceProvider>().updateServiceStatut(commande.id, 'PAYE');
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("CONFIRMER LE PAIEMENT", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminMenu(BuildContext context, ServiceModel commande) {
    return PopupMenuButton<String>(
      onSelected: (newStatus) {
        context.read<ServiceProvider>().updateServiceStatut(commande.id, newStatus);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'COMMANDE', child: Text('⌛ Remettre en attente')),
        const PopupMenuItem(value: 'EN_COURS', child: Text('⚙️ En cours de traitement')),
        const PopupMenuItem(value: 'TERMINE', child: Text('✅ Marquer comme Terminé')),
        const PopupMenuItem(value: 'ANNULE', child: Text('❌ Annuler/Rembourser')),
      ],
      child: const Icon(Icons.more_vert),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  IconData _getServiceIcon(String type) {
    switch (type) {
      case 'ALERTE_IMMO': 
      case 'CHASSEUR_VIP': return Icons.psychology_alt;
      case 'BOOST_ANNONCE': return Icons.rocket_launch;
      case 'NETTOYAGE': return Icons.cleaning_services;
      case 'DEMENAGEMENT': return Icons.local_shipping;
      default: return Icons.miscellaneous_services;
    }
  }
}