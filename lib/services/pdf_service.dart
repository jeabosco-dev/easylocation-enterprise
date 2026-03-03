// lib/services/pdf_service.dart

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/facture_model.dart';

class PdfService {
  static Future<void> genererEtPartagerFacture(
      FactureModel facture, 
      {bool estPaye = false}) async { 
    
    final pdf = pw.Document();

    // --- CHARGEMENT DU LOGO ---
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint("Logo non trouvé.");
    }

    // --- PRÉPARATION DES DONNÉES ---
    // Le reliquat est la garantie totale demandée par le bailleur moins ce qui est déjà versé comme commission
    final double garantieTotaleUSD = facture.loyer * facture.nbMoisGarantie;
    final double resteAPayerBailleurUSD = garantieTotaleUSD - facture.commissionBailleurUSD;
    
    final String dateStr = "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}";
    final String dataVerification = "https://easylocation.cd/verify?ref=${facture.refMaison}&client=${facture.clientId}";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // --- WATERMARK ---
              pw.Center(
                child: pw.Opacity(
                  opacity: 0.1,
                  child: pw.Transform.rotate(
                    angle: -0.5,
                    child: pw.Text(
                      estPaye ? "PAYÉ" : "PROFORMA",
                      style: pw.TextStyle(
                        color: estPaye ? PdfColors.green : PdfColors.grey,
                        fontSize: 100,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // HEADER
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (logoImage != null) pw.Container(height: 50, child: pw.Image(logoImage)),
                          pw.SizedBox(height: 5),
                          pw.Text("EASY LOCATION SARLU", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue900)),
                          pw.Text("La location en un clic", style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(estPaye ? "REÇU DE PAIEMENT" : "FACTURE PROFORMA",
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.Text("REF : ${facture.refMaison.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text("Date : $dateStr", style: pw.TextStyle(fontSize: 10)),
                          pw.Text("Offre : ${facture.nomOffre}", style: pw.TextStyle(fontSize: 9, color: PdfColors.blue700)),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 20),
                  pw.Divider(thickness: 1, color: PdfColors.blue900),
                  pw.SizedBox(height: 10),

                  // INFOS PARTIES
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoBlock("LOCATAIRE", facture.nomClient, facture.telClient),
                      _buildInfoBlock("BIEN & BAILLEUR", "Réf: ${facture.refMaison}", "Proprio: ${facture.nomBailleur}"),
                    ],
                  ),

                  pw.SizedBox(height: 25),

                  // TABLEAU DES FRAIS (Basé sur ton FactureModel)
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)},
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.blue900),
                        children: [
                          _headerCell("Désignation des frais"),
                          _headerCell("Montant USD", align: pw.TextAlign.right),
                        ],
                      ),
                      _buildPdfRow('Commission de Service (Locataire)', facture.commissionLocataireUSD),
                      _buildPdfRow('Acompte Garantie (Frais Bailleur)', facture.commissionBailleurUSD),
                      if (facture.transportChoisi) 
                        _buildPdfRow('Service Transport & Logistique', 0.0, customValue: "INCLUS"),
                      if (facture.cadeauId != null && facture.cadeauId != "Aucun")
                        _buildPdfRow('Cadeau de Bienvenue (${facture.nomOffre})', 0.0, customValue: "OFFERT"),
                    ],
                  ),

                  // RÉCAPITULATIF
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(
                        width: 220,
                        padding: const pw.EdgeInsets.all(10),
                        decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                        child: pw.Column(
                          children: [
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text("TOTAL À PAYER :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900)),
                                pw.Text("${facture.totalUSD.toStringAsFixed(2)} \$", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            pw.SizedBox(height: 4),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text("Equivalent FC :", style: pw.TextStyle(fontSize: 8)),
                                pw.Text("${facture.totalCDF.toStringAsFixed(0)} FC", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                              ],
                            ),
                            pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Taux: 1\$ = ${facture.tauxApplique} FC", style: pw.TextStyle(fontSize: 6))),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 30),

                  // NOTE BAILLEUR DYNAMIQUE
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.orange50,
                      border: pw.Border.all(color: PdfColors.orange200),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("NOTE IMPORTANTE AU LOCATAIRE :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.orange900, fontSize: 8)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Pour ce bien, la garantie totale est de ${garantieTotaleUSD.toStringAsFixed(2)} \$. "
                          "Après avoir payé cette facture, il vous restera à verser ${resteAPayerBailleurUSD.toStringAsFixed(2)} \$ "
                          "directement à M./Mme ${facture.nomBailleur} lors de la signature du contrat définitif.",
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.orange900),
                        ),
                      ],
                    ),
                  ),

                  pw.Spacer(),

                  // FOOTER
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("DOCUMENT AUTHENTIQUE", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                          pw.SizedBox(height: 2),
                          pw.SizedBox(width: 300, child: pw.Text("Ce document généré par Easy Location fait foi de preuve de transaction. Toute falsification est passible de poursuites.", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700))),
                          pw.SizedBox(height: 5),
                          pw.Text("Siège : 44, Av. des ouvriers, Ibanda, Bukavu, RD Congo", style: pw.TextStyle(fontSize: 7)),
                        ],
                      ),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: dataVerification,
                        width: 50,
                        height: 50,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Facture_${facture.refMaison}_${facture.nomClient.split(' ')[0]}.pdf',
    );
  }

  static pw.Widget _buildInfoBlock(String title, String val1, String val2) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
        pw.Text(val1, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Text(val2, style: pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  static pw.Widget _headerCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, textAlign: align, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)),
    );
  }

  static pw.TableRow _buildPdfRow(String label, double montant, {String? customValue}) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(label, style: pw.TextStyle(fontSize: 9))),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(customValue ?? "${montant.toStringAsFixed(2)} \$", 
              textAlign: pw.TextAlign.right, 
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ),
      ],
    );
  }
}