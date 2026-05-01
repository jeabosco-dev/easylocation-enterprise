// lib/services/pdf_generators/contract_pdf_builder.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../models/facture_model.dart';

class ContractPdfBuilder {
  /// Construit le document PDF du contrat de bail
  static Future<pw.Document> build({
    required FactureModel facture,
    required Map<String, String> bailleur,
    required Map<String, String> locataire,
    required Map<String, String> platform,
  }) async {
    final pdf = pw.Document();
    final String dateSignature = DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Nettoyage et formatage du nom complet du locataire
    final String identiteLocataire = [
      locataire['prenom'] ?? '',
      locataire['nom'] ?? '',
      locataire['postnom'] ?? ''
    ].where((s) => s.trim().isNotEmpty).join(' ').trim().toUpperCase();

    final String telephonePreneur = locataire['tel'] ?? '__________';
    final String adresseBien = platform['adresse'] ?? 'Bukavu, RDC';
    final double loyerCalcul = facture.loyer ?? 0.0;
    final int nbMoisGarantieCalcul = facture.nbMoisGarantie;
    final String garantieTotale = (loyerCalcul * nbMoisGarantieCalcul).toStringAsFixed(2);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          // En-tête Institutionnel
          pw.Header(
            level: 0,
            child: pw.Column(
              children: [
                pw.Center(
                  child: pw.Text("REPUBLIQUE DEMOCRATIQUE DU CONGO",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text("CONTRAT DE BAIL À LOYER",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                        decoration: pw.TextDecoration.underline,
                      )),
                ),
                pw.SizedBox(height: 20),
              ],
            ),
          ),

          // Identification des parties
          pw.Paragraph(
              text: "ENTRE LES SOUSSIGNÉS :",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          
          pw.Paragraph(
              text: "1. M./Mme ${bailleur['nom_complet'] ?? facture.nomBailleur}, ci-après dénommé(e) LE BAILLEUR."),
          
          pw.Paragraph(
              text: "2. M./Mme $identiteLocataire, Contact : $telephonePreneur, ci-après dénommé(e) LE PRENEUR."),

          pw.SizedBox(height: 10),
          pw.Text("IL A ÉTÉ CONVENU ET ARRÊTÉ CE QUI SUIT :",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          // Clauses contractuelles
          _clauseTitre("ARTICLE 1 : OBJET"),
          pw.Paragraph(
              text: "Le Bailleur donne en location au Preneur le bien immobilier situé à $adresseBien, référence : ${facture.refMaison}."),

          _clauseTitre("ARTICLE 2 : DURÉE"),
          pw.Paragraph(
              text: "Le présent contrat est conclu pour une durée déterminée, prenant cours à la date de signature des présentes."),

          _clauseTitre("ARTICLE 3 : LOYER ET GARANTIE"),
          pw.Paragraph(
              text: "Le loyer mensuel est fixé à ${loyerCalcul.toStringAsFixed(2)} USD. Le Preneur verse ce jour une garantie locative de $nbMoisGarantieCalcul mois, soit $garantieTotale USD."),

          _clauseTitre("ARTICLE 4 : OBLIGATIONS"),
          pw.Bullet(text: "Le Preneur s'engage à maintenir les lieux en bon état de père de famille."),
          pw.Bullet(text: "Le loyer doit être payé au plus tard le 05 de chaque mois."),

          _clauseTitre("ARTICLE 5 : LITIGES"),
          pw.Paragraph(
              text: "En cas de litige, les parties privilégient le règlement à l'amiable. À défaut, les tribunaux compétents de la ville du bien seront seuls saisis."),

          // Espace Signature
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Fait à Bukavu, le $dateSignature"),
                  pw.SizedBox(height: 40),
                  pw.Text("Signature du Bailleur", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.SizedBox(height: 55),
                  pw.Text("Signature du Preneur", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),

          pw.Spacer(),
          pw.Divider(),
          
          // Note de bas de page (Décharge EasyLocation)
          pw.Center(
            child: pw.Text(
              "Document généré via ${platform['name'] ?? 'EasyLocation Enterprise'}. "
              "La plateforme décline toute responsabilité quant à l'exactitude des informations saisies par les parties.",
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Widget utilitaire pour les titres de clauses
  static pw.Widget _clauseTitre(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900),
      ),
    );
  }
}