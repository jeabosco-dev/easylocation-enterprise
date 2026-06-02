// lib/widgets/cash_payment_instruction_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'dart:async';
import 'dart:io';
import '../services/config_service.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

class CashPaymentInstructionSheet extends StatefulWidget {
  final String refBien;
  final String? factureId; // 👈 Passé de 'String' à 'String?' (Optionnel) pour réparer les autres pages
  final double montantAPayer; 
  final double montantWallet; 
  final DateTime? dateExpiration; 

  const CashPaymentInstructionSheet({
    super.key,
    required this.refBien,
    this.factureId, // 👈 Retrait du 'required' pour ne plus bloquer l'application
    required this.montantAPayer,
    this.montantWallet = 0.0, 
    this.dateExpiration, 
  });

  @override
  State<CashPaymentInstructionSheet> createState() => _CashPaymentInstructionSheetState();
}

class _CashPaymentInstructionSheetState extends State<CashPaymentInstructionSheet> {
  Timer? _timer; 
  StreamSubscription? _factureSubscription; 
  Duration _timeLeft = Duration.zero;
  DateTime? _dynamicDateExpiration; 

  @override
  void initState() {
    super.initState();
    // On initialise d'abord avec la date statique reçue (si elle existe)
    _dynamicDateExpiration = widget.dateExpiration;
    
    // Ensuite, on lance la synchronisation Firestore uniquement si un ID est fourni
    if (widget.factureId != null && widget.factureId!.isNotEmpty) {
      _initFactureStream();
    } else {
      // Sinon, on démarre le timer directement avec la date fixe de base
      _startTimer();
    }
  }

  // 🔄 Écoute Firestore en continu (uniquement si factureId est présent)
  void _initFactureStream() {
    _factureSubscription = FirebaseFirestore.instance
        .collection(FirestoreCollections.factures) // 👈 Remplacement par la constante harmonisée
        .doc(widget.factureId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      // Gestion propre de la suppression du dossier ou annulation
      if (!snapshot.exists) {
        _timer?.cancel();
        setState(() {
          _timeLeft = Duration.zero;
        });
        return;
      }

      final data = snapshot.data();
      if (data != null && data['dateExpiration'] != null) {
        final Timestamp timestamp = data['dateExpiration'];
        
        setState(() {
          _dynamicDateExpiration = timestamp.toDate();
        });

        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _calculateTimeLeft();
    if (_dynamicDateExpiration != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _calculateTimeLeft();
      });
    }
  }

  void _calculateTimeLeft() {
    if (!mounted || _dynamicDateExpiration == null) return;
    
    final now = DateTime.now();
    final difference = _dynamicDateExpiration!.difference(now); 

    if (difference.isNegative || difference == Duration.zero) {
      if (_timer?.isActive ?? false) _timer?.cancel();
      setState(() {
        _timeLeft = Duration.zero;
      });
    } else {
      setState(() {
        _timeLeft = difference;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); 
    _factureSubscription?.cancel(); 
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    if (d.isNegative || d == Duration.zero) return "00h 00m 00s";
    return "${twoDigits(d.inHours)}h ${twoDigits(d.inMinutes.remainder(60))}m ${twoDigits(d.inSeconds.remainder(60))}s";
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigService>();
    final info = config.companyInfo;
    final bool isExpired = _timeLeft == Duration.zero;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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

          // --- SECTION MONTANT ---
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

          // --- SECTION TIMER (Affichée uniquement si une date d'expiration est disponible) ---
          if (_dynamicDateExpiration != null) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isExpired ? Colors.red[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isExpired ? Colors.red : Colors.orange),
              ),
              child: Column(
                children: [
                  Text(
                    isExpired ? "DÉLAI EXPIRÉ" : "TEMPS RESTANT", 
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: isExpired ? Colors.red : Colors.orange[900]
                    )
                  ),
                  Text(
                    _formatDuration(_timeLeft),
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold, 
                      color: isExpired ? Colors.red : (_timeLeft.inMinutes < 30 ? Colors.redAccent : Colors.orange[900])
                    ),
                  ),
                ],
              ),
            ),
          ],

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

  // ✅ CORRECTION NATIVE : Redirection cartographique sécurisée Android / iOS
  void _ouvrirGoogleMaps(String adresse) async {
    final String encodedAddress = Uri.encodeComponent(adresse);
    Uri mapsUrl;

    if (Platform.isAndroid) {
      // Intent natif pour ouvrir directement l'application par défaut (Maps, OsmAnd, etc.)
      mapsUrl = Uri.parse("geo:0,0?q=$encodedAddress");
    } else if (Platform.isIOS) {
      // Lien universel Apple Maps / Google Maps pour les appareils iOS
      mapsUrl = Uri.parse("https://maps.apple.com/?q=$encodedAddress");
    } else {
      // Fallback web générique pour le reste des plateformes
      mapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedAddress");
    }

    try {
      if (await canLaunchUrl(mapsUrl)) {
        await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
      } else {
        // Si l'intent direct échoue, on tente d'ouvrir via le navigateur web standard
        final Uri fallbackWebUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedAddress");
        if (await canLaunchUrl(fallbackWebUrl)) {
          await launchUrl(fallbackWebUrl, mode: LaunchMode.externalApplication);
        } else {
          throw "Impossible d'exécuter l'action de cartographie.";
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Impossible d'ouvrir la carte pour l'adresse : $adresse"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}