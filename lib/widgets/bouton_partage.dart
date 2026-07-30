// lib/widgets/bouton_partage.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class BoutonPartage extends StatefulWidget {
  final Property property;

  const BoutonPartage({super.key, required this.property});

  @override
  State<BoutonPartage> createState() => _BoutonPartageState();
}

class _BoutonPartageState extends State<BoutonPartage> {
  late int _localShares;
  bool _enCoursDePartage = false;

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
    if (_enCoursDePartage) return;

    setState(() {
      _enCoursDePartage = true;
    });

    try {
      // ✅ Mise à jour du compteur de partages dans Firestore
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
      final String? imageUrl = widget.property.mainImageUrl;

      // Logique de partage multi-plateforme (Web vs Mobile avec image)
      if (kIsWeb || imageUrl == null || imageUrl.isEmpty) {
        // Sur le Web ou si aucune image n'est disponible : partage du texte seul
        await Share.share(message);
      } else {
        // Sur Mobile (Android / iOS) : Téléchargement de l'image et partage combiné (photo + texte)
        try {
          final response = await http.get(Uri.parse(imageUrl));
          if (response.statusCode == 200) {
            final tempDir = await getTemporaryDirectory();
            final file = File('${tempDir.path}/share_property_${widget.property.id}.jpg');
            await file.writeAsBytes(response.bodyBytes);

            await Share.shareXFiles(
              [XFile(file.path)],
              text: message,
            );
          } else {
            // Fallback en cas d'échec du téléchargement de l'image
            await Share.share(message);
          }
        } catch (imgError) {
          debugPrint("Erreur lors du téléchargement de l'image pour le partage : $imgError");
          // Fallback texte seul si le réseau ou le stockage pose problème
          await Share.share(message);
        }
      }

    } catch (e) {
      debugPrint("Erreur partage: $e");
    } finally {
      if (mounted) {
        setState(() {
          _enCoursDePartage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _enCoursDePartage ? null : _partager,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          // ✅ AMÉLIORATION UI : Ne prend que l'espace nécessaire
          mainAxisSize: MainAxisSize.min,
          children: [
            _enCoursDePartage
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined, color: Colors.blue, size: 28),
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