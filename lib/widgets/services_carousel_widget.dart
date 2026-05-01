import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/service_model.dart';
import '../services/config_service.dart'; 
import '../providers/service_provider.dart';
import 'service_payment_sheet.dart'; 

class ServicesCarouselWidget extends StatelessWidget {
  final String provenance; // 'POST_RESERVATION' ou 'DASHBOARD'

  const ServicesCarouselWidget({
    super.key, 
    this.provenance = 'DASHBOARD'
  });

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigService>();
    final user = FirebaseAuth.instance.currentUser;

    // 1. Liste des types de services autorisés
    const allowedServices = [
      'NETTOYAGE',
      'PEINTURE',
      'DEMENAGEMENT_STD', 
      'DEMENAGEMENT_PREMIUM',
      'DEMENAGEMENT_GOLD',
      'PACK_SERENITE'
    ];

    // 2. Transformation des données et filtrage
    final List<ServiceModel> offers = config.upsellServices
        .map((map) => ServiceModel.fromConfig(map))
        .where((service) {
          final type = service.typeService.trim().toUpperCase();
          return allowedServices.contains(type);
        })
        .toList();

    if (offers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            "Optimisez votre installation 🏠",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 200, // Augmenté légèrement pour le confort visuel
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final service = offers[index];
              return _buildServiceCard(context, service, user?.uid, config);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(BuildContext context, ServiceModel service, String? uid, ConfigService config) {
    // --- LOGIQUE DE CALCUL DYNAMIQUE ---
    double prixFinal = service.prix;
    double tauxReduction = service.prix; 
    String texteBadge = service.isPercentage 
        ? "-${tauxReduction.toStringAsFixed(0)}%" 
        : "${service.prix.toStringAsFixed(0)} \$";
    
    if (service.typeService == 'PACK_SERENITE') {
      // Récupération dynamique des prix des composants depuis la config
      double pNettoyage = _getRawPrice(config.upsellServices, 'NETTOYAGE');
      double pPeinture = _getRawPrice(config.upsellServices, 'PEINTURE');
      double pDemenagement = _getRawPrice(config.upsellServices, 'DEMENAGEMENT_GOLD');

      double totalBrut = pNettoyage + pPeinture + pDemenagement;

      // Calcul du prix après réduction (ex: 80$ - 10%)
      prixFinal = totalBrut - (totalBrut * tauxReduction / 100);
      texteBadge = "-${tauxReduction.toStringAsFixed(0)}%"; 
    }

    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1E5D8F).withOpacity(0.1),
                  child: Icon(
                    service.typeService == 'PACK_SERENITE' ? Icons.verified_user : Icons.bolt, 
                    color: const Color(0xFF1E5D8F)
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    texteBadge,
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              service.libelle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Affichage du prix réel calculé en Dollars
            Text(
              "${prixFinal.toStringAsFixed(0)} \$",
              style: const TextStyle(
                fontWeight: FontWeight.w900, 
                fontSize: 18, 
                color: Color(0xFF1E5D8F)
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                service.description ?? "",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                onPressed: () => _confirmOrder(context, service, uid, config),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E5D8F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Commander", style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fonction utilitaire pour extraire les prix de la config sans doublon de code
  double _getRawPrice(List<dynamic> services, String type) {
    try {
      final s = services.firstWhere(
        (element) => element['id'] == type,
        orElse: () => {'prix': 0.0},
      );
      return (s['prix'] as num).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  void _confirmOrder(BuildContext context, ServiceModel service, String? uid, ConfigService config) {
    if (uid == null) return;

    // Calcul du prix final pour le message de confirmation
    double prixFinalMsg = service.prix;
    if (service.typeService == 'PACK_SERENITE') {
        double pNettoyage = _getRawPrice(config.upsellServices, 'NETTOYAGE');
        double pPeinture = _getRawPrice(config.upsellServices, 'PEINTURE');
        double pDemenagement = _getRawPrice(config.upsellServices, 'DEMENAGEMENT_GOLD');
        double total = pNettoyage + pPeinture + pDemenagement;
        prixFinalMsg = total - (total * service.prix / 100);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Commander : ${service.libelle}"),
        content: Text("Souhaitez-vous confirmer cette commande pour ${prixFinalMsg.toStringAsFixed(0)}\$ ?\n\nVous allez être redirigé vers le tunnel de paiement."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              final commande = ServiceModel(
                id: '', 
                locataireId: uid,
                typeService: service.typeService,
                statut: 'PROPOSE', 
                prix: service.prix, // Le Provider recalculera le prix net en backend
                provenance: provenance,
                timestamp: DateTime.now(),
                nomAffichage: service.libelle,
              );

              final String? generatedId = await context.read<ServiceProvider>().creerCommandeInitial(
                commande, 
                config.upsellServices
              );

              if (generatedId != null && context.mounted) {
                final commandeAvecId = commande.copyWith(id: generatedId, prix: prixFinalMsg);
                
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => ServicePaymentSheet(
                    commande: commandeAvecId,
                    serviceName: service.libelle,
                  ),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Erreur lors de l'initialisation."), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );
  }
}