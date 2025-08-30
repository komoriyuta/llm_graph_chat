import 'dart:html' as html;
import 'dart:convert';
import 'dart:async';

Future<void> exportFile(String content, String filename) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<String?> importTextFile({List<String>? extensions}) async {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement();
  if (extensions != null && extensions.isNotEmpty) {
    input.accept = extensions.map((e) => e.startsWith('.') ? e : '.$e').join(',');
  }
  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      if (!completer.isCompleted) {
        completer.complete(reader.result?.toString());
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.readAsText(file);
  });
  // Trigger dialog
  input.click();
  return completer.future;
}
