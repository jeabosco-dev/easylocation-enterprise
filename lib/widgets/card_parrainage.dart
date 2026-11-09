// lib/widgets/card_parrainage.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart'; 
import '../providers/user_profile_provider.dart';
import '../services/referral_service.dart';
import '../services/config_service.dart';

class CardParrainage extends StatelessWidget {
  const CardParrainage({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. On récupère la configuration dynamique
    final config = context.watch<ConfigService>();
    
    // 2. On récupère les données de l'utilisateur pour l'UID
    final userProvider = context.watch<UserProfileProvider>();
    final String? monUid = userProvider.userData?.uid;
    final String prenom = userProvider.userData?.prenom ?? "Partenaire";

    // SÉCURITÉ : Si le module est désactivé ou pas d'utilisateur connecté
    if (!config.isReferralActive || monUid == null || monUid.isEmpty) {
      return const SizedBox.shrink();
    }

    final double rate = config.referralReferrerRate;
    final String rateFormatted = rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1);

    return Card(
      elevation: 0,
      color: const Color(0xFFF0F5FA), // Bleu très clair harmonisé
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF1E5D8F).withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF1E5D8F), size: 28),
                ),
              ),
              title: Text(
                "Gagnez jusqu'à $rateFormatted% de bonus",
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16, 
                  color: Color(0xFF1E5D8F),
                ),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  "Invitez un ami ou un partenaire à rejoindre EasyLocation.",
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            ),
            const Divider(height: 24, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Bouton 1 : Partage Digital (WhatsApp, etc.)
                Expanded(
                  child: OutlinedButton.icon(
                   onPressed: () => ReferralService.partagerLien(monUid, partnerName: prenom),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text("PARTAGER"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E5D8F),
                      side: const BorderSide(color: Color(0xFF1E5D8F), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Bouton 2 : QR Code Physique (Pour le terrain)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showQRCodeDialog(context, monUid, prenom),
                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                    label: const Text("MON QR"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E5D8F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Affiche une boîte de dialogue interactive avec le QR Code et les options d'export
  void _showQRCodeDialog(BuildContext context, String code, String prenom) {
    showDialog(
      context: context,
      builder: (context) => _QRCodeDialogContent(code: code, prenom: prenom),
    );
  }
}

/// Widget interne Stateful pour gérer les états de chargement (Enregistrement, Partage)
class _QRCodeDialogContent extends StatefulWidget {
  final String code;
  final String prenom;

  const _QRCodeDialogContent({required this.code, required this.prenom});

  @override
  State<_QRCodeDialogContent> createState() => _QRCodeDialogContentState();
}

class _QRCodeDialogContentState extends State<_QRCodeDialogContent> {
  bool _isLoading = false;
  String? _actionMessage;

  Future<void> _handleAction(Future<void> Function() action, String successMsg) async {
    setState(() {
      _isLoading = true;
      _actionMessage = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() {
          _actionMessage = successMsg;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String link = ReferralService.genererLienPourQRCode(widget.code);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "QR Code de ${widget.prenom}", 
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E5D8F)),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Faites scanner ce code à votre contact ou utilisez les options ci-dessous pour le diffuser.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            
            // Aperçu du QR Code
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                width: 180,
                height: 180,
                child: QrImageView(
                  data: link,
                  version: QrVersions.auto,
                  size: 180.0,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1E5D8F)),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "EasyLocation • Réseau Officiel",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            
            if (_isLoading) ...[
              const SizedBox(height: 15),
              const CircularProgressIndicator(color: Color(0xFF1E5D8F)),
            ] else if (_actionMessage != null) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  _actionMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Boutons d'actions rapides (Enregistrer, Partager l'image)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _handleAction(
                      () => ReferralService.enregistrerQRCode(widget.code, partnerName: widget.prenom),
                      "✅ QR Code enregistré dans la galerie !",
                    ),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text("Enregistrer", style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E5D8F),
                      side: const BorderSide(color: Color(0xFF1E5D8F)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _handleAction(
                      () => ReferralService.partagerQRCode(widget.code, partnerName: widget.prenom),
                      "✅ QR Code partagé avec succès !",
                    ),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text("Partager image", style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E5D8F),
                      side: const BorderSide(color: Color(0xFF1E5D8F)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E5D8F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text("FERMER", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}