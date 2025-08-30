import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

Future<void> exportFile(String content, String filename) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsString(content);
  await Share.shareXFiles([XFile(file.path)], text: 'チャット履歴のエクスポート');
}

Future<String?> importTextFile({List<String>? extensions}) async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: 'インポートする JSON を選択',
    type: extensions == null || extensions.isEmpty
        ? FileType.any
        : FileType.custom,
    allowedExtensions: extensions,
    allowMultiple: false,
    withData: false,
  );
  if (result == null || result.files.isEmpty) return null;
  final path = result.files.single.path;
  if (path == null) return null;
  try {
    return await File(path).readAsString();
  } catch (_) {
    return null;
  }
}
