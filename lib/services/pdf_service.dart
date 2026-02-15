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
      {bool estPaye = false, double? tauxApplique}) async { 
    
    final pdf = pw.Document();

    // --- CHARGEMENT DU LOGO ---
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint("Logo non trouvé, génération sans logo.");
    }

    // --- PRÉPARATION DES DONNÉES ---
    final double avanceBailleurUSD = facture.loyer * 0.15;
    final double resteAPayerBailleurUSD = (facture.loyer * facture.nbMoisGarantie) - avanceBailleurUSD;
    
    // Formatage de la date
    final String dateStr = "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}";

    final String dataVerification = 
        "https://easylocation.cd/verify?ref=${facture.refMaison}&client=${facture.clientId}";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // --- COUCHE 1 : WATERMARK (Filigrane) ---
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

              // --- COUCHE 2 : CONTENU ---
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
                          if (logoImage != null)
                            pw.Container(height: 50, child: pw.Image(logoImage)),
                          pw.SizedBox(height: 5),
                          pw.Text("EASY LOCATION SARLU",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue900)),
                          pw.Text("La location en un clic", style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(estPaye ? "REÇU DE PAIEMENT" : "FACTURE PROFORMA",
                              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.Text("REF : ${facture.refMaison.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text("Émis le : $dateStr", style: pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 20),
                  pw.Divider(thickness: 1, color: PdfColors.blue900),
                  pw.SizedBox(height: 10),

                  // BLOC CLIENT / INFOS BIEN
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("LOCATAIRE", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                          pw.Text(facture.nomClient, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.Text("Tél : ${facture.telClient}", style: pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("DÉTAILS DU BIEN", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Référence : ${facture.refMaison}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.Text("Propriétaire : ${facture.nomBailleur}", style: pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 25),

                  // TABLEAU DES FRAIS
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.blue900),
                        children: [
                          _headerCell("Désignation des frais"),
                          _headerCell("Montant USD", align: pw.TextAlign.right),
                        ],
                      ),
                      _buildPdfRow('Frais de Service (Commission)', facture.commissionUSD),
                      _buildPdfRow('Avance sur Garantie (Acompte Bailleur)', avanceBailleurUSD),
                      if (facture.transportChoisi) _buildPdfRow('Frais de Transport & Logistique', 10.0),
                    ],
                  ),

                  // SECTION RÉCAPITULATIF FINANCIER
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(
                        width: 250,
                        padding: const pw.EdgeInsets.all(10),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: pw.BorderRadius.only(bottomLeft: pw.Radius.circular(5), bottomRight: pw.Radius.circular(5))
                        ),
                        child: pw.Column(
                          children: [
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(estPaye ? "TOTAL PAYÉ :" : "TOTAL À PAYER :", 
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                                pw.Text("${facture.totalUSD.toStringAsFixed(2)} \$", 
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue900)),
                              ],
                            ),
                            if (tauxApplique != null) ...[
                              pw.SizedBox(height: 6),
                              pw.Divider(thickness: 0.5, color: PdfColors.blue200),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text("Payé en Francs Congolais", style: pw.TextStyle(fontSize: 8, color: PdfColors.blue700)),
                                  pw.Text("${(facture.totalUSD * tauxApplique).toStringAsFixed(0)} FC", 
                                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                                ],
                              ),
                              pw.Align(
                                alignment: pw.Alignment.centerRight,
                                child: pw.Text("Taux appliqué : 1\$ = $tauxApplique FC", style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 30),

                  // BLOC INFORMATION BAILLEUR
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.orange50,
                      border: pw.Border.all(color: PdfColors.orange200),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(children: [
                          pw.Text("⚠️ ", style: pw.TextStyle(fontSize: 10)),
                          pw.Text("RELIQUAT À PAYER AU PROPRIÉTAIRE", 
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.orange900, fontSize: 9)),
                        ]),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Le solde de ${resteAPayerBailleurUSD.toStringAsFixed(2)} \$ (soit le reste de votre garantie locative) doit être versé directement à M./Mme ${facture.nomBailleur} lors de la signature du contrat et de la remise des clés.",
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.orange900, lineSpacing: 1.5), // ✅ Corrigé ici
                        ),
                      ],
                    ),
                  ),

                  pw.Spacer(),

                  // FOOTER AVEC QR CODE
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("AUTHENTICITÉ DU DOCUMENT", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                            pw.Text(
                              "Ce document est une preuve officielle de transaction. Scannez le QR code pour vérifier l'authenticité sur notre portail sécurisé.",
                              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                            ),
                            pw.SizedBox(height: 10),
                            pw.Text("Siège Social : 44, Av. des ouvriers, Ibanda, Bukavu, Sud-Kivu, RD Congo", style: pw.TextStyle(fontSize: 7)),
                          ],
                        ),
                      ),
                      pw.Column(
                        children: [
                          pw.Container(
                            width: 65,
                            height: 65,
                            padding: const pw.EdgeInsets.all(2),
                            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: dataVerification,
                              drawText: false,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text("Scanner pour vérifier", style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 10),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  pw.Center(
                    child: pw.Text(
                      "Easy Location SARLU - RCCM : CD/BKV/RCCM/22-B-03012 - ID.NAT : 01-G4701-N39201Z",
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Partage du fichier
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: estPaye 
          ? 'Recu_Paiement_${facture.refMaison}_${facture.nomClient.replaceAll(' ', '_')}.pdf' 
          : 'Facture_Proforma_${facture.refMaison}.pdf',
    );
  }

  static pw.Widget _headerCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: pw.Text(text, 
          textAlign: align,
          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)),
    );
  }

  static pw.TableRow _buildPdfRow(String label, double montant) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 9)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text("${montant.toStringAsFixed(2)} \$", 
              textAlign: pw.TextAlign.right, 
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ),
      ],
    );
  }
}
