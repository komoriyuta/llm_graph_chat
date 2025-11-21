import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/secure_storage_service.dart';
import '../providers/theme_notifier.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _secureStorageService = SecureStorageService();
  bool _isLoading = false;
  String? _currentApiKeyStatus;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    final apiKey = await _secureStorageService.getApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      _apiKeyController.text = '********'; // Mask the key
      _currentApiKeyStatus = 'API Key is set.';
    } else {
      _currentApiKeyStatus = 'API Key is not set.';
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API Key.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_apiKeyController.text != '********') {
        await _secureStorageService.saveApiKey(_apiKeyController.text);
        _apiKeyController.text = '********';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key saved successfully!')),
      );
      setState(() {
        _currentApiKeyStatus = 'API Key is set.';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving API Key: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSettings() async {
    setState(() => _isLoading = true);
    try {
      await _secureStorageService.deleteApiKey();
      _apiKeyController.clear();
      setState(() {
        _currentApiKeyStatus = 'API Key is not set.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting API Key: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final isDarkMode = theme.brightness == Brightness.dark;
    // We need to access the notifier to toggle theme
    final themeNotifier = ref.read(themeProvider.notifier);
    
    // For node settings, we need to decide how to handle them.
    // In the original code, ThemeProvider held nodeWidth/Height.
    // In my migration, I created NodeSettingsNotifier but didn't use it yet.
    // Let's use NodeSettingsNotifier here if I created it, or just assume it's part of the theme for now?
    // Wait, I did create NodeSettingsNotifier in theme_notifier.dart.
    // Let's use it.
    final nodeSettings = ref.watch(nodeSettingsProvider);
    final nodeSettingsNotifier = ref.read(nodeSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                // ダークモード設定
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ダークモード',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: isDarkMode,
                      onChanged: (value) {
                        themeNotifier.toggleTheme();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // ノードサイズ設定
                const Text(
                  'ノードサイズ設定',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ノードの幅: ${nodeSettings.width.round()}px'),
                    Slider(
                      value: nodeSettings.width,
                      min: 200,
                      max: 1000,
                      divisions: 30,
                      label: nodeSettings.width.round().toString(),
                      onChanged: (value) {
                        nodeSettingsNotifier.updateNodeSize(value, nodeSettings.height);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('ノードの高さ: ${nodeSettings.height.round()}px'),
                    Slider(
                      value: nodeSettings.height,
                      min: 100,
                      max:  1000,
                      divisions: 30,
                      label: nodeSettings.height.round().toString(),
                      onChanged: (value) {
                        nodeSettingsNotifier.updateNodeSize(nodeSettings.width, value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                const Text(
                  'LLM API Key (Gemini)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_currentApiKeyStatus ?? 'Loading...'),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Enter API Key',
                    border: OutlineInputBorder(),
                    hintText: 'Paste your Gemini API Key here',
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _saveSettings,
                      child: const Text('Save API Key'),
                    ),
                    TextButton(
                      onPressed: _deleteSettings,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete API Key'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}