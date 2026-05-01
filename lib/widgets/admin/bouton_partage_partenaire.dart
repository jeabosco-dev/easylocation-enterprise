// lib/widgets/admin/bouton_partage_partenaire.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart'; // Pour kIsWeb

class BoutonPartagePartenaire extends StatefulWidget {
  final String partnerId;
  final Map<String, dynamic> partnerData;

  const BoutonPartagePartenaire({
    super.key,
    required this.partnerId,
    required this.partnerData,
  });

  @override
  State<BoutonPartagePartenaire> createState() => _BoutonPartagePartenaireState();
}

class _BoutonPartagePartenaireState extends State<BoutonPartagePartenaire> {
  bool _isSharing = false; // Empêche le double-clic et l'erreur de partage concurrent

  Future<void> _partager(BuildContext context) async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    final String nom = widget.partnerData['nom'] ?? 'Partenaire';
    final double commission = ((widget.partnerData['commission_rate'] ?? 0.0) * 100);
    
    String message = "🤝 *Bienvenue chez EasyLocation Enterprise !*\n\n"
        "Cher partenaire *$nom*,\n"
        "Votre compte partenaire B2B est désormais actif.\n\n"
        "🔑 *Vos accès :*\n"
        "• ID Partenaire : `${widget.partnerId}`\n"
        "• Commission : *${commission.toStringAsFixed(0)}%*\n\n"
        "Lien vers votre QR Code :\n"
        "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${widget.partnerId}";

    try {
      // 1. Mise à jour Firestore (optionnel mais utile)
      await FirebaseFirestore.instance
          .collection('partenaires')
          .doc(widget.partnerId)
          .update({'last_shared_at': FieldValue.serverTimestamp()});

      // 2. Partage
      if (kIsWeb) {
        // Sur Web, on ajoute un petit délai pour s'assurer que le navigateur est prêt
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await Share.share(message, subject: 'Accès Partenaire EasyLocation');

    } catch (e) {
      debugPrint("Erreur lors du partage partenaire: $e");
      // Si l'erreur navigator.share survient, on peut proposer une alternative (copier-coller)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Le partage a échoué. Veuillez réessayer.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _isSharing 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.share, color: Colors.green, size: 22),
      onPressed: _isSharing ? null : () => _partager(context),
      tooltip: "Partager les accès",
    );
  }
}