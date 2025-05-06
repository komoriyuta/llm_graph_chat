import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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