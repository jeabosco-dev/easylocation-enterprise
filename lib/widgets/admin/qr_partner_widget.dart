// lib/widgets/admin/qr_partner_widget.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';
import 'package:easylocation_mvp/services/referral_service.dart'; // Import du service universel

class QrPartnerWidget extends StatelessWidget {
  final String partnerId;
  final String partnerName;

  const QrPartnerWidget({
    super.key,
    required this.partnerId,
    required this.partnerName,
  });

  /// Génère un document PDF contenant le QR code et les informations du partenaire
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    
    // Génération de l'image raster du QR code pour l'intégrer proprement dans le PDF
    final qrValidationResult = QrValidator.validate(
      data: ReferralService.genererLienPartenaire(partnerId),
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
    );
    
    final qrCode = qrValidationResult.qrCode;
    final painter = QrPainter.withQr(
      qr: qrCode!,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
      gapless: true,
    );
    
    final imageBytes = await painter.toImageData(200);
    final pdfImage = pw.MemoryImage(imageBytes!.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  "QR Code Partenaire - EasyLocation",
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  partnerName,
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                ),
                pw.Text(
                  "ID: $partnerId",
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 30),
                pw.Container(
                  padding: const pw.EdgeInsets.all(15), // Correction ici avec pw.EdgeInsets
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Image(pdfImage, width: 180, height: 180),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  ReferralService.genererLienPartenaire(partnerId),
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue600),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    // Utilisation propre du ReferralService pour générer l'URL du QR code
    final String referralUrl = ReferralService.genererLienPartenaire(partnerId);

    return AlertDialog(
      title: const Text("QR Code Partenaire", textAlign: TextAlign.center),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              partnerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(partnerId, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: QrImageView(
                data: referralUrl,
                version: QrVersions.auto,
                size: 200.0,
                padding: const EdgeInsets.all(0),
                // --- AJOUT DU LOGO AU CENTRE ---
                embeddedImage: const AssetImage('assets/images/logo.png'),
                embeddedImageStyle: QrEmbeddedImageStyle(
                  size: const Size(40, 40), // Taille du logo au centre
                ),
              ),
            ),
            const SizedBox(height: 15),
            SelectableText(
              referralUrl,
              style: const TextStyle(fontSize: 10, color: Colors.blueAccent),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        // Groupe d'actions complet (Copier, Partager, Télécharger, Imprimer)
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: [
            // 1. Bouton Copier
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: referralUrl));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lien copié dans le presse-papier !")),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text("Copier"),
            ),

            // 2. Bouton Partager
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await Share.share(
                    ReferralService.genererMessagePartenaire(partnerId, partnerName: partnerName),
                    subject: "QR Code et Lien Partenaire - $partnerName",
                  );
                } catch (e) {
                  debugPrint("Erreur lors du partage : $e");
                }
              },
              icon: const Icon(Icons.share, size: 16),
              label: const Text("Partager"),
            ),

            // 3. Bouton Télécharger (Génération et sauvegarde réelle via file_saver)
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final pdfData = await _generatePdf(PdfPageFormat.a4);
                  final safeName = partnerName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
                  
                  await FileSaver.instance.saveFile(
                    name: 'QR_Partner_$safeName',
                    bytes: pdfData,
                    ext: 'pdf',
                    mimeType: MimeType.pdf,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("QR Code téléchargé avec succès !")),
                    );
                  }
                } catch (e) {
                  debugPrint("Erreur lors du téléchargement : $e");
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Erreur lors du téléchargement : $e")),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text("Télécharger"),
            ),

            // 4. Bouton Imprimer (Ouverture du module d'impression via le package printing)
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await Printing.layoutPdf(
                    onLayout: (PdfPageFormat format) async => _generatePdf(format),
                    name: 'QR_Code_$partnerId',
                  );
                } catch (e) {
                  debugPrint("Erreur lors de l'impression : $e");
                }
              },
              icon: const Icon(Icons.print, size: 16),
              label: const Text("Imprimer"),
            ),
          ],
        ),

        // Bouton de fermeture principal
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("FERMER", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}