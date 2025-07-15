import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final LocalStorageService _storageService = LocalStorageService();
  bool _isDarkMode = false;
  double _nodeWidth = LocalStorageService.defaultNodeWidth;
  double _nodeHeight = LocalStorageService.defaultNodeHeight;

  bool get isDarkMode => _isDarkMode;
  double get nodeWidth => _nodeWidth;
  double get nodeHeight => _nodeHeight;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _isDarkMode = await _storageService.getDarkMode();
    _nodeWidth = await _storageService.getNodeWidth();
    _nodeHeight = await _storageService.getNodeHeight();
    notifyListeners();
  }

  Future<void> updateNodeSize(double width, double height) async {
    _nodeWidth = width;
    _nodeHeight = height;
    await _storageService.setNodeWidth(width);
    await _storageService.setNodeHeight(height);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storageService.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  ThemeData get theme {
    if (_isDarkMode) {
      return ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.purple,
        colorScheme: const ColorScheme.dark(
          primary: Colors.purple,
          secondary: Colors.purpleAccent,
        ),
        fontFamily: 'NotoSansJP',
      );
    }
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: Colors.blue,
      colorScheme: const ColorScheme.light(
        primary: Colors.blue,
        secondary: Colors.blueAccent,
      ),
      fontFamily: 'NotoSansJP',
    );
  }
}