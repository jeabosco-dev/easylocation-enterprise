// lib/services/export_service.dart

import 'package:excel/excel.dart' as ex;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ✅ Import conditionnel pour la gestion Web / Mobile
import 'save_helper.dart' 
    if (dart.library.html) 'save_web.dart' 
    if (dart.library.io) 'save_mobile.dart';

class ExportService {
  
  /// ✅ EXPORT RÉPERTOIRE DES CONTRATS (Audit Interne / Back-office)
  /// Cette méthode exporte le détail complet : Qui loue quoi et où.
  static Future<void> exportContratsDetaillesToExcel({
    required List<Map<String, dynamic>> contratsData,
  }) async {
    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel[excel.getDefaultSheet() ?? "Répertoire Contrats"];

    // 1. Entêtes stratégiques (Correction du symbole $)
    final headers = [
      'DATE SIGNATURE',
      'VILLE',
      'COMMUNE',
      'QUARTIER',
      'AVENUE',
      'NUMÉRO',
      'BAILLEUR (NOM)',
      'BAILLEUR (TEL)',
      'LOCATAIRE (NOM)',
      'LOCATAIRE (TEL)',
      'LOYER (\$)', // ✅ CORRIGÉ : Ajout du \ devant le $
      'STATUT'
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = ex.TextCellValue(headers[i]);
    }

    // 2. Écriture des Données
    for (var i = 0; i < contratsData.length; i++) {
      final item = contratsData[i];
      
      // Extraction sécurisée de la map adresse_bien
      final adresse = item['adresse_bien'] as Map<String, dynamic>? ?? {};

      final row = [
        item['date_signature'], 
        adresse['ville'] ?? 'N/A',
        adresse['commune'] ?? 'N/A',
        adresse['quartier'] ?? 'N/A',
        adresse['avenue'] ?? 'N/A',
        adresse['numero'] ?? 'N/A',
        item['bailleur_nom'] ?? 'Inconnu',
        item['bailleur_tel'] ?? 'N/A',
        item['locataire_nom'] ?? 'N/A',
        item['locataire_tel'] ?? 'N/A',
        item['loyer_mensuel'] ?? 0.0,
        item['statut_contrat'] ?? 'ACTIF',
      ];

      for (var j = 0; j < row.length; j++) {
        _setCellValue(sheet, j, i + 1, row[j]);
      }
    }

    final bytes = excel.encode();
    if (bytes != null) {
      String dateStr = DateFormat('dd_MM_yyyy').format(DateTime.now());
      await saveAndLaunchFile(bytes, "Rapport_Interne_Contrats_$dateStr.xlsx");
    }
  }

  /// ✅ EXPORT PARTENAIRES B2B (Performance et Commissions)
  static Future<void> exportPartnersToExcel({
    required List<QueryDocumentSnapshot> docs,
  }) async {
    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel[excel.getDefaultSheet() ?? "Partenaires"];

    final headers = [
      'ID PARTENAIRE',
      'NOM OFFICIEL',
      'TYPE',
      'TAUX COM (%)',
      'STATUT',
      'TOTAL APPORTÉS',
      'SOLDE DÛ (À PAYER)',
      'REVENU GÉNÉRÉ (POUR SGA)',
      'DATE CRÉATION',
      'UID LIÉ'
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = ex.TextCellValue(headers[i]);
    }

    for (var i = 0; i < docs.length; i++) {
      final data = docs[i].data() as Map<String, dynamic>;
      
      final double rate = (data['commission_rate'] ?? 0.0);
      final double soldePartenaire = (data['solde_commission'] ?? 0.0);
      final int conversions = (data['total_conversions'] ?? 0);

      double revenuEstimeSGA = 0.0;
      if (rate > 0) {
        double volumeTotal = soldePartenaire / rate;
        revenuEstimeSGA = volumeTotal - soldePartenaire;
      }

      final row = [
        docs[i].id,
        data['nom'] ?? 'N/A',
        data['type'] ?? 'N/A',
        "${(rate * 100).toStringAsFixed(1)}%",
        (data['is_active'] ?? false) ? "ACTIF" : "SUSPENDU",
        conversions,
        soldePartenaire,
        revenuEstimeSGA,
        data['created_at'],
        data['linked_uid'] ?? 'Non lié'
      ];

      for (var j = 0; j < row.length; j++) {
        _setCellValue(sheet, j, i + 1, row[j]);
      }
    }

    final bytes = excel.encode();
    if (bytes != null) {
      String dateStr = DateFormat('dd_MM_yyyy').format(DateTime.now());
      await saveAndLaunchFile(bytes, "Rapport_Partenaires_$dateStr.xlsx");
    }
  }

  /// ✅ EXPORT DE MAPS (Contrats, Rapports personnalisés)
  static Future<void> exportCustomDataToExcel({
    required List<Map<String, dynamic>> data,
    required String fileName,
    required List<String> headers,
    String sheetName = "Export",
  }) async {
    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel[excel.getDefaultSheet() ?? sheetName];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = ex.TextCellValue(headers[i]);
    }

    for (var i = 0; i < data.length; i++) {
      final rowData = data[i];
      for (var j = 0; j < headers.length; j++) {
        var key = headers[j];
        var value = rowData[key];
        _setCellValue(sheet, j, i + 1, value);
      }
    }

    final bytes = excel.encode();
    if (bytes != null) {
      await saveAndLaunchFile(bytes, "$fileName.xlsx");
    }
  }

  /// ✅ EXPORT FIREBASE (Propriétés, Utilisateurs)
  static Future<void> exportPropertiesToExcel({
    required List<QueryDocumentSnapshot> docs,
    required String fileName,
    required String sheetName,
    required List<String> headers,
    required List<String> keys,
  }) async {
    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel[excel.getDefaultSheet() ?? sheetName];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = ex.TextCellValue(headers[i]);
    }

    for (var i = 0; i < docs.length; i++) {
      final data = docs[i].data() as Map<String, dynamic>;
      for (var j = 0; j < keys.length; j++) {
        var value = data[keys[j]];
        
        if (value is Map<String, dynamic>) {
          if (value.containsKey('ville') || value.containsKey('avenue')) {
            final n = value['numero'] ?? '';
            final ave = value['avenue'] ?? '';
            final q = value['quartier'] ?? '';
            final c = value['commune'] ?? '';
            final v = value['ville'] ?? '';
            final p = value['province'] ?? '';
            final pays = value['pays'] ?? '';

            value = "${n != '' ? 'N° $n ' : ''}$ave, $q, $c, $v, $p, $pays"
                .replaceAll(RegExp(r', ,'), ',') 
                .trim();
            
            if (value.startsWith(',')) value = value.substring(1).trim();
          }
        }

        _setCellValue(sheet, j, i + 1, value);
      }
    }

    final bytes = excel.encode();
    if (bytes != null) {
      await saveAndLaunchFile(bytes, "$fileName.xlsx");
    }
  }

  /// 🛠️ Helper privé pour uniformiser le remplissage des cellules
  static void _setCellValue(ex.Sheet sheet, int col, int row, dynamic value) {
    var cell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));

    if (value == null) {
      cell.value = ex.TextCellValue('N/A');
    } else if (value is num) {
      cell.value = ex.DoubleCellValue(value.toDouble());
    } else if (value is Timestamp) {
      cell.value = ex.TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(value.toDate()));
    } else if (value is DateTime) {
      cell.value = ex.TextCellValue(DateFormat('dd/MM/yyyy').format(value));
    } else if (value is bool) {
      cell.value = ex.TextCellValue(value ? "OUI" : "NON");
    } else {
      cell.value = ex.TextCellValue(value.toString());
    }
  }
}