// lib/models/property/property_parsing_utils.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PropertyParsingUtils {
  static bool readBool(Map<String, dynamic> data, String key) {
    var val = data[key];
    if (val == null) return false;
    if (val is bool) return val;
    if (val is num) return val == 1;
    if (val is String) return val.toLowerCase() == 'true';
    return false;
  }

  static Map<String, String> readStringMap(Map<String, dynamic> data, String key) {
    final map = data[key];
    if (map is! Map) return {};
    return map.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  static List<String> readStringList(Map<String, dynamic> data, String key) {
    final list = data[key];
    if (list is! List) return [];
    return list.map((e) => e.toString()).toList();
  }

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}