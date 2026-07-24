// lib/widgets/boost_property_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/models/service_model.dart';
import 'package:easylocation_mvp/models/payment_target.dart';
import 'package:easylocation_mvp/services/config_service.dart';
import 'package:easylocation_mvp/services/maxicash_service.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart'; 
import 'package:easylocation_mvp/widgets/manuel_payment_sheet.dart'; 
import 'package:easylocation_mvp/widgets/cash_payment_instruction_sheet.dart';
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
  bool _isProcessing = false;

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
              onPressed: (boostOptions.isEmpty || _isProcessing || _selectedBoostId == null) ? null : () {
                final optionChoisie = boostOptions.firstWhere((o) => o.typeService == _selectedBoostId!);
                _procederAuPaiement(context, optionChoisie);
              },
              child: _isProcessing 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("PAYER LE BOOST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _procederAuPaiement(BuildContext context, ServiceModel option) {
    final String uniqueId = "BOOST-${widget.property.referenceUnique}-${DateTime.now().millisecondsSinceEpoch}";
    
    // Récupération des informations du profil utilisateur connecté
    final userProfile = context.read<UserProfileProvider>().userData;
    final String nomClient = userProfile?.nomComplet ?? "Bailleur / Utilisateur";
    final String telephone = userProfile?.telephone ?? "N/A";
    final String email = userProfile?.email ?? "";

    final commande = ServiceModel(
      id: uniqueId,
      locataireId: widget.userId,
      typeService: 'BOOST_ANNONCE',
      statut: 'PROPOSE',
      prix: option.prix,
      provenance: 'APP_MOBILE',
      nomAffichage: "Boost ${option.nomAffichage}",
      description: "Boost pour l'annonce : ${widget.property.title} (Réf: ${widget.property.referenceUnique})",
      timestamp: DateTime.now(),
      // Injection des informations utilisateur pour le back-office
      nomClient: nomClient,
      locataireTel: telephone,
      email: email,
      // ✅ AJOUT OBLIGATOIRE DE LA RÉFÉRENCE DU BIEN
      propertyReference: widget.property.referenceUnique,
    );

    _ouvrirSelecteurPaiement(context, commande);
  }

  void _ouvrirSelecteurPaiement(BuildContext context, ServiceModel commande) {
    final userProfile = context.read<UserProfileProvider>().userData;
    final String userPhone = userProfile?.telephone ?? "";
    final String userName = userProfile?.nomComplet ?? "Utilisateur";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(sheetContext).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ),
            Text("Règlement : ${commande.nomAffichage}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text("Réf. Bien : ${widget.property.referenceUnique}", style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text("Montant : ${commande.prix} \$", style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            
            _buildPaymentTile(
              icon: Icons.credit_card,
              color: Colors.blue,
              title: "MaxiCash (Paiement en ligne)",
              subtitle: "Visa, Mastercard, Mobile Money - Automatique",
              onTap: () async {
                Navigator.pop(sheetContext);
                setState(() => _isProcessing = true);

                try {
                  await FirebaseFirestore.instance.collection(FirestoreCollections.services).doc(commande.id).set(commande.toMap());
                  if (!mounted) return;

                  MaxicashService.encaisserAcompte(
                    context: context,
                    telephone: userPhone, 
                    referenceCommande: commande.id,
                    montant: commande.prix,
                    ville: widget.property.ville, 
                    onSuccess: () {
                      if (mounted) {
                        setState(() => _isProcessing = false);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Paiement réussi ! Boost activé."), backgroundColor: Colors.green)
                        );
                      }
                    },
                    onCancel: () {
                      if (mounted) setState(() => _isProcessing = false);
                    },
                  );
                } catch (e) {
                  debugPrint("❌ ERREUR MAXICASH : $e");
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            ),
            const SizedBox(height: 12),

            _buildPaymentTile(
              icon: Icons.phone_android,
              color: Colors.green,
              title: "Mobile Money Direct",
              subtitle: "M-Pesa, Orange, Airtel - Manuel",
              onTap: () async {
                Navigator.pop(sheetContext);
                setState(() => _isProcessing = true);
                
                try {
                  await FirebaseFirestore.instance.collection(FirestoreCollections.services).doc(commande.id).set(commande.toMap());
                  if (!mounted) return;
                  setState(() => _isProcessing = false);

                  showModalBottomSheet(
                    context: context, 
                    isScrollControlled: true,
                    builder: (_) => ManuelPaymentSheet(
                      propertyId: widget.property.id,
                      // ✅ Transmission correcte de l'ID du bien et de sa référence
                      facture: commande.toFacture(
                        propertyId: widget.property.id,
                        nomClient: userName,
                      ), 
                      montantFinal: commande.prix,
                      devise: "USD",
                      docId: commande.id,
                      target: PaymentTarget.service,
                    )
                  );
                } catch (e) {
                   debugPrint("❌ ERREUR MM MANUEL : $e");
                   if (mounted) setState(() => _isProcessing = false);
                }
              },
            ),
            const SizedBox(height: 12),

            _buildPaymentTile(
              icon: Icons.payments_outlined,
              color: Colors.orange,
              title: "Paiement Cash",
              subtitle: "Payer à l'agence EasyLocation",
              onTap: () async {
                Navigator.pop(sheetContext);
                setState(() => _isProcessing = true);
                
                try {
                  await FirebaseFirestore.instance.collection(FirestoreCollections.services).doc(commande.id).set(commande.toMap());
                  if (!mounted) return;
                  setState(() => _isProcessing = false);

                  showModalBottomSheet(
                    context: context, 
                    isScrollControlled: true,
                    builder: (_) => CashPaymentInstructionSheet(
                      target: PaymentTarget.service,
                      // ✅ Transmission correcte de l'ID du bien et de sa référence
                      facture: commande.toFacture(
                        propertyId: widget.property.id,
                        nomClient: userName,
                      ),
                    )
                  );
                } catch (e) {
                  debugPrint("❌ ERREUR CASH : $e");
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTile({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
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