// lib/widgets/laisser_commande_whatsapp_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:easylocation_mvp/services/config_service.dart';

class LaisserCommandeWhatsAppWidget extends StatelessWidget {
  const LaisserCommandeWhatsAppWidget({super.key});

  Future<void> _openWhatsAppForOrder(BuildContext context) async {
    final config = Provider.of<ConfigService>(context, listen: false);
    final String rawNumber = config.companyInfo['tel'] ?? '+243980361265';
    final String cleanNumber = rawNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    final String message = Uri.encodeComponent(
      "Bonjour EasyLocation 👋, je recherche un bien spécifique et j'aimerais passer une commande personnalisée."
    );

    final url = Uri.parse('https://wa.me/$cleanNumber?text=$message');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Impossible de lancer WhatsApp");
      }
    } catch (e) {
      debugPrint("Erreur lors de l'ouverture de WhatsApp : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF25D366).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 22),
        tooltip: "Laisser une commande personnalisée",
        onPressed: () => _openWhatsAppForOrder(context),
      ),
    );
  }
}