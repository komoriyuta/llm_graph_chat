import 'platform_web.dart' if (dart.library.io) 'platform_io.dart' as platform;

Future<void> exportFile(String content, String filename) {
  return platform.exportFile(content, filename);
}