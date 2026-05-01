// lib/services/pdf_generators/receipt_pdf_builder.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../models/contract_model.dart';
import '../../models/payment_model.dart';

class ReceiptPdfBuilder {
  
  /// Construit un reçu unique pour un paiement de loyer mensuel
  /// Note : Appel positionnel (pas de {} autour des arguments)
  static Future<pw.Document> buildSingleReceipt(
    ContractModel contrat, 
    PaymentModel paiement, 
    Map<String, String>? companyInfo
  ) async {
    final pdf = pw.Document();
    final String datePaie = DateFormat('dd/MM/yyyy').format(paiement.dateOperation);
    
    // Fallback si companyInfo est nul
    final info = companyInfo ?? {
      "name": "EASYLOCATION ENTERPRISE", 
      "n_impot": "N/A",
      "adresse": "Bukavu, RDC"
    };

    // Logique de solde pour le filigrane
    final double solde = paiement.soldeRestant ?? 0.0;
    bool estComplet = solde <= 0;
    String filigraneTexte = estComplet ? "PAYÉ CASH" : "PAIEMENT PARTIEL";
    PdfColor statusColor = estComplet ? PdfColors.green : PdfColors.orange;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context ctx) {
          return pw.Stack(
            children: [
              // 1. Filigrane de sécurité
              pw.Center(
                child: pw.Opacity(
                  opacity: 0.1,
                  child: pw.Transform.rotate(
                    angle: -0.5,
                    child: pw.Text(
                      filigraneTexte,
                      style: pw.TextStyle(
                        fontSize: 70, 
                        fontWeight: pw.FontWeight.bold, 
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Contenu principal
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(info),
                  pw.SizedBox(height: 25),
                  pw.Center(
                    child: pw.Text(
                      "REÇU DE LOYER",
                      style: pw.TextStyle(
                        fontSize: 22, 
                        fontWeight: pw.FontWeight.bold, 
                        color: PdfColors.blue900,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                       _buildInfoBlock("LOCATAIRE", contrat.locataireNom.toUpperCase(), "Réf Bien: ${contrat.id}"),
                       _buildInfoBlock("RÉFÉRENCE PAIEMENT", "N°: ${paiement.id.substring(0,8).toUpperCase()}", "Méthode: Mobile Money"),
                    ]
                  ),
                 
                  pw.SizedBox(height: 20),
                  
                  // Tableau des montants
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                        children: [
                          _headerCell("DÉSIGNATION"),
                          _headerCell("PÉRIODE"),
                          _headerCell("MONTANT USD", align: pw.TextAlign.right),
                        ],
                      ),
                      _buildLoyerRow(
                        "Loyer Mensuel", 
                        paiement.periodeConcerns ?? "${paiement.nbMoisPayes} mois", 
                        "${paiement.montantTotal} \$"
                      ),
                      if (!estComplet)
                        _buildLoyerRow(
                          "RELIQUAT (SOLDE)", 
                          "À régulariser", 
                          "${paiement.soldeRestant} \$"
                        ),
                    ],
                  ),
                  
                  pw.SizedBox(height: 40),
                  
                  // Section Signature
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text("Fait à Bukavu, le $datePaie", style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 10),
                        pw.Text("Pour EasyLocation Enterprise", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.SizedBox(height: 50),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: statusColor),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))
                          ),
                          child: pw.Text(
                            estComplet ? "CONFORMÉ" : "RELIQUAT À PAYER",
                            style: pw.TextStyle(
                              color: statusColor, 
                              fontWeight: pw.FontWeight.bold, 
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  pw.Spacer(),
                  pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                  pw.Center(
                    child: pw.Text(
                      "Ce reçu est une preuve de paiement électronique générée par EasyLocation MVP.\nL'authenticité peut être vérifiée via le scan du QR Code sur la facture originale.",
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
                    ),
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

  // --- Widgets d'aide ---

  static pw.Widget _buildHeader(Map<String, String> info) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              info['name']?.toUpperCase() ?? "EASYLOCATION ENTERPRISE",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900, fontSize: 12),
            ),
            pw.Text("NIF: ${info['n_impot'] ?? 'En cours'}", style: pw.TextStyle(fontSize: 8)),
            pw.Text("Bukavu, Sud-Kivu, RDC", style: pw.TextStyle(fontSize: 8)),
          ],
        ),
        pw.Text("REÇU ÉLECTRONIQUE", style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
      ],
    );
  }

  static pw.Widget _buildInfoBlock(String title, String name, String sub) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.Text(sub, style: pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  static pw.Widget _headerCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
      ),
    );
  }

  static pw.TableRow _buildLoyerRow(String desc, String periode, String montant) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(desc, style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(periode, style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8), 
          child: pw.Text(
            montant, 
            textAlign: pw.TextAlign.right, 
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          ),
        ),
      ],
    );
  }
}