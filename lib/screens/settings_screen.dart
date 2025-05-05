import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _modelNameController = TextEditingController(); // Controller for model name
  final _secureStorageService = SecureStorageService();
  bool _isLoading = false;
  String? _currentApiKeyStatus;
  String? _currentModelNameStatus; // Status for model name

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final apiKey = await _secureStorageService.getApiKey();
    final modelName = await _secureStorageService.getSelectedModel(); // Load saved model name

    if (apiKey != null && apiKey.isNotEmpty) {
      _apiKeyController.text = '********'; // Mask the key
      _currentApiKeyStatus = 'API Key is set.';
    } else {
      _currentApiKeyStatus = 'API Key is not set.';
    }

    if (modelName != null && modelName.isNotEmpty) {
      _modelNameController.text = modelName;
      _currentModelNameStatus = 'Model: $modelName';
    } else {
      _currentModelNameStatus = 'Model name is not set.';
      // Optionally set a default model name hint
      // _modelNameController.text = 'gemini-1.5-flash-latest';
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    final apiKey = _apiKeyController.text;
    final modelName = _modelNameController.text;
    bool apiKeyChanged = false;
    bool modelNameChanged = false;

    // Validate and save API Key if changed
    if (apiKey.isNotEmpty && apiKey != '********') {
      await _secureStorageService.saveApiKey(apiKey);
      _apiKeyController.text = '********'; // Mask after saving
      _currentApiKeyStatus = 'API Key saved successfully.';
      apiKeyChanged = true;
    } else if (apiKey.isEmpty && _currentApiKeyStatus != 'API Key is not set.') {
      // Handle case where user clears the masked key without intending to delete
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a new API Key or leave masked.')),
      );
       return; // Don't proceed if only masked key was cleared
    }


    // Validate and save Model Name if changed
    if (modelName.isNotEmpty) {
       final currentModel = await _secureStorageService.getSelectedModel();
       if(modelName != currentModel) {
         await _secureStorageService.saveSelectedModel(modelName);
         _currentModelNameStatus = 'Model saved: $modelName';
         modelNameChanged = true;
       }
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a model name (e.g., gemini-1.5-flash-latest).')),
      );
       return; // Don't proceed if model name is empty
    }


    setState(() {
      // Update status messages only if something changed
      if (!apiKeyChanged && !modelNameChanged) {
         _currentApiKeyStatus = 'Settings unchanged.';
         _currentModelNameStatus = '';
      } else {
         if(!apiKeyChanged) _currentApiKeyStatus = 'API Key is set.'; // Keep existing status if not changed
         if(!modelNameChanged) _currentModelNameStatus = 'Model: ${modelName}'; // Keep existing status
      }
    });

     if (apiKeyChanged || modelNameChanged) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Settings saved successfully!')),
       );
     }
  }

  Future<void> _deleteApiKey() async {
    setState(() => _isLoading = true);
    await _secureStorageService.deleteApiKey(); // This also deletes the model name now
    _apiKeyController.clear();
    _modelNameController.clear(); // Clear model field as well
    _currentApiKeyStatus = 'API Key deleted.';
    _currentModelNameStatus = 'Model name deleted.';
    setState(() => _isLoading = false);
     ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API Key and Model Name deleted.')),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // Added for smaller screens
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LLM API Key (Gemini)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                Text(_currentApiKeyStatus ?? 'Loading...'),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true, // Hide the API key
                  decoration: const InputDecoration(
                    labelText: 'Enter API Key',
                    border: OutlineInputBorder(),
                    hintText: 'Paste your Gemini API Key here',
                  ),
                ),
                const SizedBox(height: 24), // Increased spacing

                // --- Model Name Input ---
                const Text(
                  'LLM Model Name',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_currentModelNameStatus ?? ''),
                const SizedBox(height: 16),
                 TextField(
                  controller: _modelNameController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Model Name',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., gemini-1.5-flash-latest',
                  ),
                ),
                const SizedBox(height: 24), // Increased spacing

                // --- Action Buttons ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _saveSettings, // Use combined save function
                      child: const Text('Save Settings'),
                    ),
                    TextButton(
                      onPressed: _deleteApiKey, // Deletes both key and model
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete Key & Model'),
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}