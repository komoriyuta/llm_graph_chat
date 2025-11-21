import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/local_storage_service.dart';

part 'theme_notifier.g.dart';

@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  late final LocalStorageService _storageService;

  @override
  ThemeData build() {
    _storageService = LocalStorageService();
    _loadSettings();
    // Return default theme initially
    return _buildTheme(false);
  }

  Future<void> _loadSettings() async {
    final isDarkMode = await _storageService.getDarkMode();
    // We might want to store node size in a separate provider or state, 
    // but for now let's keep it simple and focus on the theme data.
    // If node size is needed globally, we should probably have a SettingsNotifier.
    // For this migration, I will assume ThemeProvider was mainly used for Theme.
    // However, the original ThemeProvider also held nodeWidth/Height.
    // Let's handle that by splitting or keeping it here if we change the state type.
    // Since the return type is ThemeData, we can't easily store node sizes here.
    // I will create a separate SettingsNotifier for node sizes if needed, 
    // or just use a separate provider for node settings.
    // For now, let's stick to ThemeData and create a separate provider for settings if needed.
    state = _buildTheme(isDarkMode);
  }

  ThemeData _buildTheme(bool isDarkMode) {
    if (isDarkMode) {
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

  Future<void> toggleTheme() async {
    final isDark = state.brightness == Brightness.dark;
    final newIsDark = !isDark;
    await _storageService.setDarkMode(newIsDark);
    state = _buildTheme(newIsDark);
  }
}

// Separate provider for node settings if we want to keep it clean
@riverpod
class NodeSettingsNotifier extends _$NodeSettingsNotifier {
  late final LocalStorageService _storageService;

  @override
  NodeSettingsState build() {
    _storageService = LocalStorageService();
    _loadSettings();
    return const NodeSettingsState();
  }

  Future<void> _loadSettings() async {
    final width = await _storageService.getNodeWidth();
    final height = await _storageService.getNodeHeight();
    state = NodeSettingsState(width: width, height: height);
  }

  Future<void> updateNodeSize(double width, double height) async {
    await _storageService.setNodeWidth(width);
    await _storageService.setNodeHeight(height);
    state = NodeSettingsState(width: width, height: height);
  }
}

class NodeSettingsState {
  final double width;
  final double height;

  const NodeSettingsState({
    this.width = LocalStorageService.defaultNodeWidth,
    this.height = LocalStorageService.defaultNodeHeight,
  });
}
