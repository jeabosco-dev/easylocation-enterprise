import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndLaunchFile(List<int> bytes, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName.xlsx');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], text: "Export EasyLocation");
}
