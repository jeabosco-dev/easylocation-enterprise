// lib/widgets/cash_payment_instruction_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../services/config_service.dart';

class CashPaymentInstructionSheet extends StatefulWidget {
  final String refBien;
  final DateTime dateExpiration;
  final double montantAPayer; // ✅ Le reste à payer en cash
  final double montantWallet; // ✅ Ce qui a été déduit du portefeuille

  const CashPaymentInstructionSheet({
    super.key,
    required this.refBien,
    required this.dateExpiration,
    required this.montantAPayer,
    this.montantWallet = 0.0, // Par défaut à 0 si non fourni
  });

  @override
  State<CashPaymentInstructionSheet> createState() => _CashPaymentInstructionSheetState();
}

class _CashPaymentInstructionSheetState extends State<CashPaymentInstructionSheet> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _calculateTimeLeft();
    });
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    setState(() {
      _timeLeft = widget.dateExpiration.difference(now);
      if (_timeLeft.isNegative) {
        _timeLeft = Duration.zero;
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    if (d.isNegative) return "00h 00m 00s";
    return "${twoDigits(d.inHours)}h ${twoDigits(d.inMinutes.remainder(60))}m ${twoDigits(d.inSeconds.remainder(60))}s";
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigService>();
    final info = config.companyInfo;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barre de drag (esthétique)
          Container(
            width: 40, 
            height: 4, 
            decoration: BoxDecoration(
              color: Colors.grey[300], 
              borderRadius: BorderRadius.circular(10)
            )
          ),
          const SizedBox(height: 20),

          const Icon(Icons.storefront_rounded, size: 50, color: Color(0xFF0D47A1)),
          const SizedBox(height: 10),
          const Text(
            "Paiement au Bureau",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Référence Bien : ${widget.refBien}",
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 20),

          // --- SECTION MONTANT MIXTE ---
          Container(
            padding: const EdgeInsets.all(15),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text("MONTANT À APPORTER AU BUREAU", 
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                const SizedBox(height: 5),
                Text(
                  "${widget.montantAPayer.toStringAsFixed(2)} \$",
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                if (widget.montantWallet > 0) ...[
                  const SizedBox(height: 5),
                  Text(
                    "Votre Wallet a déjà couvert ${widget.montantWallet.toStringAsFixed(2)} \$",
                    style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 15),

          // --- SECTION TIMER ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _timeLeft.isNegative || _timeLeft == Duration.zero ? Colors.red[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _timeLeft.isNegative || _timeLeft == Duration.zero ? Colors.red : Colors.orange),
            ),
            child: Column(
              children: [
                const Text("TEMPS RESTANT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                Text(
                  _formatDuration(_timeLeft),
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.bold, 
                    color: _timeLeft.inMinutes < 30 ? Colors.red : Colors.orange[900]
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- INFOS DE CONTACT ---
          _buildInfoTile(
            Icons.location_on_rounded, 
            "Adresse du Bureau", 
            info['adresse'] ?? "Bukavu, RDC",
            onTap: info['adresse'] != null ? () => _ouvrirGoogleMaps(info['adresse']!) : null,
          ),
          const Divider(),
          _buildInfoTile(
            Icons.phone_in_talk_rounded, 
            "Service Client", 
            info['tel'] ?? "N/A",
            onTap: info['tel'] != null ? () => launchUrl(Uri.parse("tel:${info['tel']}")) : null,
          ),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("J'AI COMPRIS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
        child: Icon(icon, color: const Color(0xFF0D47A1), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
      trailing: onTap != null ? const Icon(Icons.arrow_forward_ios, size: 12) : null,
      contentPadding: EdgeInsets.zero,
    );
  }

  /// ✅ Méthode corrigée pour une compatibilité maximale (Android / iOS)
  void _ouvrirGoogleMaps(String adresse) async {
    final String encodedAddress = Uri.encodeComponent(adresse);
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedAddress");

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir la carte.")),
        );
      }
    }
  }
}