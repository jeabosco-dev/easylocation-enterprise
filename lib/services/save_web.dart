import 'dart:html' as html;

Future<void> saveAndLaunchFile(List<int> bytes, String fileName) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", "$fileName.xlsx")
    ..click();
  html.Url.revokeObjectUrl(url);
}
