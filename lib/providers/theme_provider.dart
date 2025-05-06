import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final LocalStorageService _storageService = LocalStorageService();
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    _isDarkMode = await _storageService.getDarkMode();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storageService.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  ThemeData get theme {
    if (_isDarkMode) {
      return ThemeData.dark().copyWith(
        primaryColor: Colors.purple,
        colorScheme: const ColorScheme.dark(
          primary: Colors.purple,
          secondary: Colors.purpleAccent,
        ),
      );
    }
    return ThemeData.light().copyWith(
      primaryColor: Colors.blue,
      colorScheme: const ColorScheme.light(
        primary: Colors.blue,
        secondary: Colors.blueAccent,
      ),
    );
  }
}