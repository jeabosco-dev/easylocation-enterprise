// lib/widgets/bouton_partage.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:intl/intl.dart';

class BoutonPartage extends StatefulWidget {
  final Property property;

  const BoutonPartage({super.key, required this.property});

  @override
  State<BoutonPartage> createState() => _BoutonPartageState();
}

class _BoutonPartageState extends State<BoutonPartage> {
  late int _localShares;

  @override
  void initState() {
    super.initState();
    _localShares = widget.property.shares;
  }

  @override
  void didUpdateWidget(BoutonPartage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.property.id != widget.property.id) {
      _localShares = widget.property.shares;
    }
  }

  String _construireMessagePartage() {
    final p = widget.property;
    final now = DateTime.now();
    
    // --- LOGIQUE INTELLIGENTE DE DISPONIBILITÉ ---
    bool estDejaPassee = p.dateDisponibilite != null && p.dateDisponibilite!.isBefore(now);
    
    // 0. Accroche Branding
    String entreprise = "🚀 *Superbe opportunité sur EasyLocation !*\n\n";

    // 1. Titre et Localisation
    String entete = "🏠 *${p.typeBien ?? 'Logement'} à louer !*\n";
    String localite = "📍 ${p.commune}${p.quartier != null && p.quartier!.isNotEmpty ? ' (${p.quartier})' : ''}\n";
    
    // ✅ AMÉLIORATION MARKETING : Prix en gras format WhatsApp
    String prix = "💰 Loyer : *${p.price.toStringAsFixed(0)}\$ / mois*\n\n";

    // 2. Détails essentiels (Logique Maison Simple vs Étages)
    String details = "✨ *Détails du bien :*\n";
    
    if (p.maisonEnEtage == false) {
      details += "• Maison simple au sol (non en étage)\n";
    } else {
      if (p.niveauEtage == 99) {
        details += "• Situé au niveau du Grenier\n";
      } else if (p.niveauEtage == 0 || p.niveauEtage == null) {
        details += "• Situé au Rez-de-chaussée\n";
      } else {
        String rang = p.niveauEtage == 1 ? "1er" : "${p.niveauEtage}ème";
        details += "• Situé au $rang étage\n";
      }
    }

    details += "• ${p.nombreChambres} ${p.nombreChambres > 1 ? 'chambres' : 'chambre'}${p.hasSalon ? ' + Salon' : ''}\n";
    
    if (p.selectedTypeSol != null && p.selectedTypeSol!.isNotEmpty && p.selectedTypeSol != 'autre') {
      String typeSol = p.selectedTypeSol!.contains('carrelé') ? "carreaux" : "ciment";
      details += "• Intérieur en $typeSol\n";
    }

    // 3. Commodités internes
    if (p.hasCuisine) details += "• Cuisine\n";
    if (p.hasToiletteParentale) details += "• Toilette interne\n";
    if (p.hasDepot) details += "• Espace de stockage (Dépôt)\n";

    // 4. Services
    if (p.hasEau) {
      String lieuEau = p.compteurEau ? "dans la maison" : "dans la parcelle";
      details += "• Eau disponible $lieuEau 💧\n";
    }

    if (p.electricite == 'Propre Cash-power' || p.electricite == 'propre cash-power') {
      details += "• Propre compteur Cash-power ⚡\n";
    } else if (p.electricite.toLowerCase().contains('commun')) {
      details += "• Électricité disponible ⚡\n"; 
    } 

    // 5. Extérieur et Cohabitation
    if (p.maisonEnclos) details += "• Dans un enclos sécurisé 🛡️\n";
    if (p.hasGarage) details += "• Avec Garage 🚗\n";
    if (!p.bailleurHabiteAvec) details += "• Bailleur n'habite pas sur place 🔑\n";
    
    // 6. Disponibilité
    String dispo = "";
    if (p.disponibiliteImmediate || estDejaPassee) {
      dispo = "\n✅ *Disponible immédiatement*";
    } else if (p.dateDisponibilite != null) {
      String dateStr = DateFormat('d MMMM yyyy', 'fr').format(p.dateDisponibilite!);
      dispo = "\n⏳ *Libre à partir du $dateStr*";
    }

    // 7. Pied de message
    String pied = "\n\n👉 *Voir les photos et plus de détails sur EasyLocation :*\n"
        "https://easylocation-be28b.web.app/propriete?id=${p.id}";

    return "$entreprise$entete$localite$prix$details$dispo$pied";
  }

  void _partager() async {
    try {
      // ✅ AMÉLIORATION SÉCURITÉ : Utilisation de await pour garantir la mise à jour
      await FirebaseFirestore.instance
          .collection('proprietes')
          .doc(widget.property.id)
          .update({'shares': FieldValue.increment(1)});
      
      if (mounted) {
        setState(() {
          _localShares += 1;
          widget.property.shares = _localShares;
        });
      }

      final String message = _construireMessagePartage();
      await Share.share(message);

    } catch (e) {
      debugPrint("Erreur partage: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _partager,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          // ✅ AMÉLIORATION UI : Ne prend que l'espace nécessaire
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.share_outlined, color: Colors.blue, size: 28),
            const SizedBox(height: 4),
            Text(
              "$_localShares",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            // ✅ AMÉLIORATION UX : Texte professionnel
            Text(
              _localShares > 1 ? "partages" : "partage",
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}