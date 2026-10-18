// lib/widgets/services_carousel_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/service_model.dart';
import '../models/facture_model.dart';
import '../services/config_service.dart'; 
import '../providers/user_profile_provider.dart';
import '../screens/page_facture.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

class ServicesCarouselWidget extends StatelessWidget {
  final String provenance; 

  const ServicesCarouselWidget({
    super.key, 
    this.provenance = 'DASHBOARD'
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigService>(
      builder: (context, config, child) {
        final user = FirebaseAuth.instance.currentUser;

        // Utilisation du getter défini dans ConfigService
        final List<ServiceModel> offers = config.installationServices;

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
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  final service = offers[index];
                  return _buildServiceCard(context, service, user?.uid, config, offers);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServiceCard(BuildContext context, ServiceModel service, String? uid, ConfigService config, List<ServiceModel> allOffers) {
    double prixFinal = service.prix;
    double tauxReduction = service.prix; 
    String texteBadge = service.isPercentage 
        ? "-${tauxReduction.toStringAsFixed(0)}%" 
        : "${service.prix.toStringAsFixed(0)} \$";
    
    if (service.typeService == 'PACK_SERENITE') {
      double pNettoyage = _getRawPrice(allOffers, 'NETTOYAGE');
      double pPeinture = _getRawPrice(allOffers, 'PEINTURE');
      double pDemenagement = _getRawPrice(allOffers, 'DEMENAGEMENT_GOLD');
      double totalBrut = pNettoyage + pPeinture + pDemenagement;
      prixFinal = totalBrut - (totalBrut * tauxReduction / 100);
      texteBadge = "-${tauxReduction.toStringAsFixed(0)}%"; 
    }

    return Container(
      width: 250,
      margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
          Text(
            "${prixFinal.toStringAsFixed(0)} \$",
            style: const TextStyle(
              fontWeight: FontWeight.w900, 
              fontSize: 18, 
              color: Color(0xFF1E5D8F)
            ),
          ),
          const SizedBox(height: 4),
          Text(
            service.description ?? "",
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _confirmOrder(context, service, uid, config, allOffers),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5D8F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Commander"),
            ),
          ),
        ],
      ),
    );
  }

  double _getRawPrice(List<ServiceModel> services, String type) {
    try {
      return services.firstWhere((s) => s.typeService == type, orElse: () => ServiceModel(id: '', locataireId: '', typeService: '', statut: '', prix: 0.0, provenance: '', nomAffichage: '')).prix;
    } catch (e) {
      return 0.0;
    }
  }

  void _confirmOrder(BuildContext context, ServiceModel service, String? uid, ConfigService config, List<ServiceModel> allOffers) {
    if (uid == null) return;

    double prixFinalMsg = service.prix;
    if (service.typeService == 'PACK_SERENITE') {
        double pNettoyage = _getRawPrice(allOffers, 'NETTOYAGE');
        double pPeinture = _getRawPrice(allOffers, 'PEINTURE');
        double pDemenagement = _getRawPrice(allOffers, 'DEMENAGEMENT_GOLD');
        double total = pNettoyage + pPeinture + pDemenagement;
        prixFinalMsg = total - (total * service.prix / 100);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Commander : ${service.libelle}"),
        content: Text("Souhaitez-vous confirmer cette commande pour ${prixFinalMsg.toStringAsFixed(0)}\$ ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              // 1. Récupération du profil utilisateur pour la géolocalisation
              final userProfile = context.read<UserProfileProvider>().userData;

              // 2. Construction de la map de la facture pour le service
              final Map<String, dynamic> serviceFactureMap = {
                FactureFields.typeService: service.typeService,
                FactureFields.clientId: uid,
                FactureFields.nomClient: userProfile?.nomComplet ?? 'Client',
                FactureFields.telClient: userProfile?.telephone ?? '',
                FactureFields.refMaison: 'SERV-${service.typeService}',
                FactureFields.loyer: prixFinalMsg, // Montant du service
                FactureFields.nomOffre: service.libelle,
                FactureFields.province: userProfile?.province,
                FactureFields.ville: userProfile?.ville,
                FactureFields.commune: userProfile?.commune,
                'categorieBien': service.typeService,
                'serviceEligible': service.typeService,
                'categorieEligible': service.typeService,
              };

              // 3. Instanciation du FactureModel via fromServiceMap unifié
              final uniqueId = "FACT-SERV-${DateTime.now().millisecondsSinceEpoch}";
              final FactureModel factureService = FactureModel.fromServiceMap(serviceFactureMap, uniqueId);

              // 4. Navigation directe vers la FacturePage unifiée
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FacturePage(facture: factureService),
                  ),
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