// lib/services/export_service.dart

import 'package:excel/excel.dart' as ex;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ✅ C'EST ICI LA MAGIE : On importe le helper qui choisit le bon fichier tout seul
import 'save_helper.dart' 
    if (dart.library.html) 'save_web.dart' 
    if (dart.library.io) 'save_mobile.dart';

class ExportService {
  static Future<void> exportPropertiesToExcel({
    required List<QueryDocumentSnapshot> docs,
    required String fileName,
    required String sheetName,
    required List<String> headers,
    required List<String> keys,
  }) async {
    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel[excel.getDefaultSheet() ?? sheetName];

    // 1. Entêtes
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = ex.TextCellValue(headers[i]);
    }

    // 2. Ajouter les données
    for (var i = 0; i < docs.length; i++) {
      final data = docs[i].data() as Map<String, dynamic>;
      for (var j = 0; j < keys.length; j++) {
        var value = data[keys[j]];
        var cell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));

        if (value == null) {
          cell.value = ex.TextCellValue('');
        } else if (value is num) {
          cell.value = ex.DoubleCellValue(value.toDouble());
        } else if (value is Timestamp) {
          String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(value.toDate());
          cell.value = ex.TextCellValue(formattedDate);
        } else if (value is String) {
          DateTime? tryDate = DateTime.tryParse(value);
          if (tryDate != null && value.contains('-') && value.length >= 10) {
            cell.value = ex.TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(tryDate));
          } else {
            cell.value = ex.TextCellValue(value);
          }
        } else {
          cell.value = ex.TextCellValue(value.toString());
        }
      }
    }

    // 3. Sortie optimisée
    final bytes = excel.encode();
    if (bytes == null) return;

    // ✅ On appelle la fonction unique, Flutter choisira save_web ou save_mobile tout seul !
    await saveAndLaunchFile(bytes, fileName);
  }
}
