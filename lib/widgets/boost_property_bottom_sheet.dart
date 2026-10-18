// lib/widgets/boost_property_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/models/service_model.dart';
import 'package:easylocation_mvp/models/facture_model.dart';
import 'package:easylocation_mvp/services/config_service.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart'; 
import 'package:easylocation_mvp/screens/page_facture.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

class BoostPropertyBottomSheet extends StatefulWidget {
  final Property property;
  final String userId;

  const BoostPropertyBottomSheet({
    super.key, 
    required this.property, 
    required this.userId
  });

  @override
  State<BoostPropertyBottomSheet> createState() => _BoostPropertyBottomSheetState();
}

class _BoostPropertyBottomSheetState extends State<BoostPropertyBottomSheet> {
  String? _selectedBoostId;

  Map<String, dynamic> _getStyleForBoost(String id) {
    switch (id) {
      case 'BOOST_FLASH':
        return {'icon': Icons.bolt, 'color': Colors.orange};
      case 'BOOST_PREMIUM':
        return {'icon': Icons.rocket_launch, 'color': Colors.deepPurple};
      case 'BOOST_URGENT':
        return {'icon': Icons.priority_high, 'color': Colors.red};
      default:
        return {'icon': Icons.star, 'color': Colors.blue};
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigService>();
    final boostOptions = config.boostServices; 

    if (_selectedBoostId == null && boostOptions.isNotEmpty) {
      _selectedBoostId = boostOptions.first.typeService;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 50, height: 5,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Propulser votre annonce", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text("Multipliez vos chances de trouver un locataire rapidement.", style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 20),
          
          if (boostOptions.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("Aucun service disponible.")))
          else
            ...boostOptions.map((option) => _buildOptionTile(option)),
          
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (boostOptions.isEmpty || _selectedBoostId == null) ? null : () {
                final optionChoisie = boostOptions.firstWhere((o) => o.typeService == _selectedBoostId!);
                _ouvrirPageFacture(context, optionChoisie);
              },
              child: const Text("PAYER LE BOOST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _ouvrirPageFacture(BuildContext context, ServiceModel option) {
    // 1. Récupération des données utilisateur et propriété
    final userProfile = context.read<UserProfileProvider>().userData;
    final String uniqueId = "FACT-BOOST-${widget.property.referenceUnique}-${DateTime.now().millisecondsSinceEpoch}";

    // 2. Construction de la Map unifiée de la facture pour le service Boost
    final Map<String, dynamic> serviceFactureMap = {
      FactureFields.typeService: option.typeService,
      FactureFields.clientId: widget.userId,
      FactureFields.nomClient: userProfile?.nomComplet ?? 'Bailleur / Utilisateur',
      FactureFields.telClient: userProfile?.telephone ?? '',
      FactureFields.refMaison: widget.property.referenceUnique,
      FactureFields.loyer: option.prix,
      FactureFields.nomOffre: "Boost ${option.nomAffichage}",
      FactureFields.province: userProfile?.province ?? 'Sud-Kivu',
      FactureFields.ville: userProfile?.ville ?? widget.property.ville,
      FactureFields.commune: userProfile?.commune ?? widget.property.commune,
      'categorieBien': 'BOOST_ANNONCE',
      'serviceEligible': option.typeService,
      'categorieEligible': 'BOOST_ANNONCE',
      'propertyId': 'SERVICE',
    };

    // 3. Création du modèle FactureModel
    final FactureModel factureBoost = FactureModel.fromServiceMap(serviceFactureMap, uniqueId);

    // 4. Fermeture du BottomSheet et redirection vers FacturePage
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacturePage(facture: factureBoost),
      ),
    );
  }

  Widget _buildOptionTile(ServiceModel option) {
    bool isSelected = (_selectedBoostId != null && _selectedBoostId == option.typeService);
    final style = _getStyleForBoost(option.typeService);
    
    final IconData icon = style['icon'] as IconData;
    final Color color = style['color'] as Color;

    return GestureDetector(
      onTap: () => setState(() => _selectedBoostId = option.typeService),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: 2),
          color: isSelected ? color.withOpacity(0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.nomAffichage, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(option.description ?? "", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text("${option.prix} \$", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          ],
        ),
      ),
    );
  }
}