// lib/widgets/cash_payment_instruction_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'dart:async';
import 'dart:io';
import '../models/facture_model.dart';
import '../services/config_service.dart';
import '../services/payment_service.dart'; 
import 'package:easylocation_mvp/constants/all_constants.dart';

class CashPaymentInstructionSheet extends StatefulWidget {
  final FactureModel facture; 

  const CashPaymentInstructionSheet({
    super.key,
    required this.facture,
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
    _dynamicDateExpiration = widget.facture.dateExpiration;
    
    // ✅ Correction du null-check : on vérifie si l'ID est non nul
    if (widget.facture.id != null) {
      PaymentService.processPaymentUpdate(
        docId: widget.facture.id!, // ✅ Forcé avec ! car testé juste avant
        collectionTarget: FirestoreCollections.factures,
        paymentMethod: 'cash',
        isNewCreation: false,
        updateData: {
          'methodePaiement': 'cash',
          'paymentStatus': 'pending',
          'etapeDossier': 'en_attente_cash',
          'montantExterne': widget.facture.totalNetUSD,
          'nomBailleur': widget.facture.nomBailleur,
          'telBailleur': widget.facture.telBailleur,
          'categorieEligible': widget.facture.categorieEligible,
          'serviceEligible': widget.facture.serviceEligible,
        },
      ).catchError((e) => debugPrint("Erreur mise à jour état cash: $e"));

      _initFactureStream();
    } else {
      _startTimer();
    }
  }

  void _initFactureStream() {
    if (widget.facture.id == null) return;

    _factureSubscription = FirebaseFirestore.instance
        .collection(FirestoreCollections.factures)
        .doc(widget.facture.id!)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (!snapshot.exists) {
        _timer?.cancel();
        setState(() => _timeLeft = Duration.zero);
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
      _timer?.cancel();
      setState(() => _timeLeft = Duration.zero);
    } else {
      setState(() => _timeLeft = difference);
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
              width: 40, height: 4, 
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))
          ),
          const SizedBox(height: 20),
          const Icon(Icons.storefront_rounded, size: 50, color: Color(0xFF0D47A1)),
          const SizedBox(height: 10),
          const Text("Paiement au Bureau", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Référence : ${widget.facture.refMaison ?? 'N/A'}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          
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
                const Text("MONTANT À APPORTER AU BUREAU", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                const SizedBox(height: 5),
                Text("${widget.facture.totalNetUSD.toStringAsFixed(2)} \$", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black)),
                if (widget.facture.montantWallet > 0) ...[
                  const SizedBox(height: 5),
                  Text(
                    "Votre Wallet a déjà couvert ${widget.facture.montantWallet.toStringAsFixed(2)} \$",
                    style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("J'AI COMPRIS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
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
      ),
    );
  }

  void _ouvrirGoogleMaps(String adresse) async {
    final String encodedAddress = Uri.encodeComponent(adresse);
    Uri mapsUrl;
    if (Platform.isAndroid) {
      mapsUrl = Uri.parse("geo:0,0?q=$encodedAddress");
    } else if (Platform.isIOS) {
      mapsUrl = Uri.parse("https://maps.apple.com/?q=$encodedAddress");
    } else {
      mapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedAddress");
    }
    try {
      if (await canLaunchUrl(mapsUrl)) {
        await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir la carte."), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}