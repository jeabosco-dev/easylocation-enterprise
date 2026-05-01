// lib/services/pdf_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../models/facture_model.dart';
import '../models/contract_model.dart';
import '../models/payment_model.dart';
import 'pdf_generators/invoice_pdf_builder.dart';
import 'pdf_generators/contract_pdf_builder.dart';
import 'pdf_generators/receipt_pdf_builder.dart';

class PdfService {
  // ==========================================
  // SECTION 1 : FACTURES & PROFORMA
  // ==========================================

  /// Utilisé dans paiement_succes_page.dart
  static Future<void> sauvegarderFacture(
    FactureModel facture, 
    Map<String, String> companyInfo, 
    {bool estPaye = true}
  ) async {
    final pdf = await InvoicePdfBuilder.build(
      facture: facture, 
      companyInfo: companyInfo, 
      estPaye: estPaye,
    );
    await sauvegarderPdf(pdf, "Facture_${facture.refMaison}");
  }

  /// Utilisé dans mes_factures_page.dart
  static void afficherOptionsFacture(
    BuildContext context, 
    FactureModel facture, 
    Map<String, String> companyInfo
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text("Partager la facture (PDF)"),
            onTap: () {
              Navigator.pop(context);
              genererEtPartagerFacture(context, facture, companyInfo, estPaye: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text("Enregistrer sur le téléphone"),
            onTap: () {
              Navigator.pop(context);
              sauvegarderFacture(facture, companyInfo, estPaye: true);
            },
          ),
        ],
      ),
    );
  }

  static Future<void> genererEtPartagerFacture(
    BuildContext context, 
    FactureModel facture, 
    Map<String, String> companyInfo, 
    {bool estPaye = false}
  ) async {
    final pdf = await InvoicePdfBuilder.build(
      facture: facture, 
      companyInfo: companyInfo, 
      estPaye: estPaye,
    );
    await _partagerPdf(pdf, "Facture_${facture.refMaison}");
  }

  // ==========================================
  // SECTION 2 : RAPPORTS D'HISTORIQUE
  // ==========================================

  /// Utilisé dans les pages d'historique bailleur et locataire
  static Future<void> genererRapportCompletLocation({
    required List<PaymentModel> paiements,
    required String titre,
  }) async {
    // Note : Vous devrez probablement créer un builder spécifique pour les rapports
    // En attendant, voici une logique générique de partage
    debugPrint("Génération du rapport : $titre");
    // Logique à implémenter selon votre ReceiptPdfBuilder ou un nouveau RapportBuilder
  }

  // ==========================================
  // SECTION 3 : CONTRATS & REÇUS
  // ==========================================

  static Future<void> genererEtPartagerContrat(
    BuildContext context, 
    FactureModel facture, 
    Map<String, String> bailleur, 
    Map<String, String> locataire, 
    Map<String, String> platform
  ) async {
    final pdf = await ContractPdfBuilder.build(
      facture: facture, 
      bailleur: bailleur, 
      locataire: locataire, 
      platform: platform,
    );
    await _partagerPdf(pdf, "Contrat_Bail_${facture.refMaison}");
  }

  static Future<void> genererRecuUnique({
    required ContractModel contrat, 
    required PaymentModel paiement, 
    Map<String, String>? companyInfo
  }) async {
    final pdf = await ReceiptPdfBuilder.buildSingleReceipt(
      contrat, 
      paiement, 
      companyInfo,
    );
    await _partagerPdf(pdf, "Recu_Loyer_${paiement.id}");
  }

  // ==========================================
  // SECTION 4 : MOTEUR DE PARTAGE & SAUVEGARDE
  // ==========================================

  static Future<void> _partagerPdf(dynamic pdf, String fileName) async {
    try {
      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final String ts = DateTime.now().millisecondsSinceEpoch.toString();
      final String safeName = fileName.replaceAll(' ', '_');
      final file = File('${tempDir.path}/${safeName}_$ts.pdf');
      
      await file.writeAsBytes(bytes, flush: true);
      
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(file.path)], 
          subject: fileName.replaceAll('_', ' '),
        );
      }
    } catch (e) {
      debugPrint("❌ Erreur de partage PDF : $e");
    }
  }

  static Future<void> sauvegarderPdf(dynamic pdf, String fileName) async {
    try {
      final bytes = await pdf.save();
      String safeName = "${fileName.replaceAll(' ', '_')}.pdf";

      await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le document',
        fileName: safeName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
    } catch (e) {
      debugPrint("❌ Erreur sauvegarde PDF : $e");
    }
  }
}