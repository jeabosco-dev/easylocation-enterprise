import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:easylocation_mvp/models/facture_model.dart';
import 'package:easylocation_mvp/utils/ui_utils.dart';

class InvoicePdfBuilder {
  /// Moteur principal de construction du document PDF
  static Future<pw.Document> build({
    required FactureModel facture, 
    required Map<String, String> companyInfo, 
    required bool estPaye
  }) async {
    final pdf = pw.Document();

    // Chargement du logo
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Le logo reste nul s'il n'est pas trouvé
    }

    final double garantieTotaleUSD = facture.montantGarantieTotal ?? (facture.loyer * facture.nbMoisGarantie);
    final int moisGarantie = facture.nbMoisGarantie;
    
    final double resteAPayerBailleurUSD =
        garantieTotaleUSD - (facture.commissionBailleurUSD);

    final String dateStr =
        DateFormat('dd/MM/yyyy HH:mm').format(facture.dateCreation ?? DateTime.now());
    
    // ✅ URL mise à jour pour le QR Code
    final String dataVerification =
        "verify?ref=${facture.refMaison}&client=${facture.id}";

    final String entrepriseNom = companyInfo['name']?.toUpperCase() ?? "EASY LOCATION ENTERPRISE";
    final String nif = companyInfo['n_impot'] ?? "---";
    final String rccm = companyInfo['rccm'] ?? "---";
    final String idNat = companyInfo['id_nat'] ?? "---";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Center(
                child: pw.Opacity(
                  opacity: 0.07,
                  child: pw.Transform.rotate(
                    angle: -0.5,
                    child: pw.Text(
                      estPaye ? "PAYÉ / VALIDÉ" : "PROFORMA",
                      style: pw.TextStyle(
                          color: estPaye ? PdfColors.green : PdfColors.red,
                          fontSize: 80,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ),
              ),
              
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (logoImage != null) pw.Container(height: 50, child: pw.Image(logoImage)),
                          pw.SizedBox(height: 8),
                          pw.Text(entrepriseNom,
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11,
                                  color: PdfColors.blue900)),
                          pw.Text("NIF: $nif | RCCM: $rccm", style: pw.TextStyle(fontSize: 7)),
                          pw.Text("ID Nat: $idNat", style: pw.TextStyle(fontSize: 7)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(estPaye ? "REÇU DE PAIEMENT" : "FACTURE PROFORMA",
                              style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue900)),
                          pw.Text("N° : ${facture.id?.toUpperCase() ?? 'TEMP'}",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text("Date : $dateStr", style: pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 15),
                  pw.Divider(thickness: 1.5, color: PdfColors.blue900),
                  pw.SizedBox(height: 15),

                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoBlock("DESTINATAIRE (LOCATAIRE)", facture.nomClient,
                          "Tél: ${facture.telClient}"),
                      _buildInfoBlock("RÉFÉRENCES DU BIEN", "Code Bien: ${facture.refMaison}",
                          "Propriétaire: ${facture.nomBailleur ?? 'N/A'}"),
                    ],
                  ),

                  pw.SizedBox(height: 30),

                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1.2)},
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                        children: [
                          _headerCell("DESCRIPTION DES SERVICES"),
                          _headerCell("MONTANT (USD)", align: pw.TextAlign.right),
                        ],
                      ),
                       _buildPdfRow('Frais de Commission Locataire', facture.commissionLocataireUSD),
                      _buildPdfRow('Acompte sur Garantie (Frais Bailleur)', facture.commissionBailleurUSD),
                      
                      if (facture.montantWallet > 0)
                        _buildPdfRow('Wallet Easylocation (EasyCredit)', facture.montantWallet, isDeduction: true),

                      if (facture.montantRemise > 0)
                        _buildPdfRow('Promotion (${facture.promoCode ?? "Code"})', facture.montantRemise, isDeduction: true),
                      
                      _buildPdfRow(
                        'État du Versement', 
                        facture.totalNetUSD, 
                        customValue: "SOLDE : ${facture.totalNetUSD.toStringAsFixed(2)} \$",
                        isTotal: true
                      ),

                      if (facture.cadeauId != null && facture.cadeauId != "Aucun")
                        _buildPdfRow('Cadeau de Bienvenue (${facture.cadeauId})', 0.0, customValue: "INCLUS"),
                    ],
                  ),

                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(
                        width: 200,
                        margin: const pw.EdgeInsets.only(top: 10),
                        padding: const pw.EdgeInsets.all(10),
                        decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                        child: pw.Column(
                          children: [
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text("NET À PAYER :",
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        fontSize: 10,
                                        color: PdfColors.blue900)),
                                pw.Text("${facture.totalNetUSD.toStringAsFixed(2)} \$",
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            pw.Align(
                                alignment: pw.Alignment.centerRight,
                                child: pw.Text("Taux : ${facture.tauxApplique} FC / 1\$",
                                    style: pw.TextStyle(fontSize: 6.5, fontStyle: pw.FontStyle.italic))),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 30),

                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                        color: PdfColors.blueGrey50,
                        border: pw.Border(left: pw.BorderSide(color: PdfColors.blue900, width: 3))),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("RÉSUMÉ DES ACCORDS :",
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text("• Garantie totale : ${garantieTotaleUSD.toStringAsFixed(2)} \$ ($moisGarantie mois).",
                            style: pw.TextStyle(fontSize: 8)),
                        pw.Text("• Acompte perçu ce jour : ${facture.commissionBailleurUSD.toStringAsFixed(2)} \$.",
                            style: pw.TextStyle(fontSize: 8)),
                        pw.Text("• RELIQUAT À VERSER AU BAILLEUR : ${resteAPayerBailleurUSD.toStringAsFixed(2)} \$.",
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900)),
                      ],
                    ),
                  ),

                  pw.Spacer(),

                  pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("EasyLocation Enterprise - La location en un clic",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                          pw.Text("Adresse : ${companyInfo['adresse'] ?? 'Bukavu, RDC'}", style: pw.TextStyle(fontSize: 7)),
                          pw.Text("Contact : ${companyInfo['tel'] ?? ''} | ${companyInfo['email'] ?? ''}", style: pw.TextStyle(fontSize: 7)),
                        ],
                      ),
                      pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(), data: dataVerification, width: 45, height: 45),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  static pw.Widget _buildInfoBlock(String title, String val1, String val2) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(val1, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Text(val2, style: pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  static pw.Widget _headerCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)),
    );
  }

  static pw.TableRow _buildPdfRow(
    String label, 
    double montant, {
    String? customValue, 
    bool isTotal = false,
    bool isDeduction = false,
  }) {
    String displayValue;
    if (customValue != null) {
      displayValue = customValue;
    } else {
      final String prefix = isDeduction ? "- " : "";
      displayValue = "$prefix${UIUtils.formatPrice(montant.abs(), decimalDigits: 2)} \$";
    }

    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label, 
            style: pw.TextStyle(
              fontSize: 9, 
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal
            )
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            displayValue,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, 
              fontSize: isTotal ? 10 : 9, 
              color: isDeduction ? PdfColors.red : PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }
}