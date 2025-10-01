import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/llm_provider.dart';
import '../providers/theme_provider.dart';
import '../services/secure_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _endpointController = TextEditingController();
  final _customModelController = TextEditingController();
  final SecureStorageService _secureStorageService = SecureStorageService();

  bool _isLoading = false;
  bool _hasStoredApiKey = false;
  bool _isSaving = false;

  LlmProviderType _selectedProvider = LlmProviderType.gemini;
  String? _selectedModel;
  String? _storedApiKey;
  String? _statusMessage;
  bool _useCustomModel = false;

  List<String> _modelOptions = [];

  static const _mask = '********';
  static const _customModelToken = '__custom__';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _endpointController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final provider = await _secureStorageService.getActiveProvider();
    await _loadProviderConfig(provider);
    setState(() => _isLoading = false);
  }

  Future<void> _loadProviderConfig(LlmProviderType provider) async {
    final option = LlmProviderOption.byType(provider);
    final apiKey = await _secureStorageService.getApiKeyForProvider(provider);
    final endpoint =
        await _secureStorageService.getEndpointForProvider(provider) ??
        option.defaultEndpoint;
    final model =
        await _secureStorageService.getSelectedModelForProvider(provider) ??
        (option.defaultModels.isNotEmpty ? option.defaultModels.first : null);

    setState(() {
      _selectedProvider = provider;
      _modelOptions = [...option.defaultModels];
      _storedApiKey = apiKey;
      _hasStoredApiKey = apiKey != null && apiKey.isNotEmpty;
      _statusMessage =
          _hasStoredApiKey
              ? '${option.displayName} API key is set.'
              : '${option.displayName} API key is not set.';

      if (_hasStoredApiKey) {
        _apiKeyController.text = _mask;
      } else {
        _apiKeyController.clear();
      }

      if (option.allowEndpointEditing) {
        _endpointController.text = endpoint;
      } else {
        _endpointController.text = option.defaultEndpoint;
      }

      _selectedModel = model;
      if (_selectedModel != null && !_modelOptions.contains(_selectedModel)) {
        _modelOptions.add(_selectedModel!);
        _useCustomModel = true;
        _customModelController.text = _selectedModel!;
      } else if (_selectedModel != null) {
        _useCustomModel = false;
        _customModelController.clear();
      } else {
        _useCustomModel = true;
        _customModelController.text = '';
        if (_modelOptions.isNotEmpty) {
          _selectedModel = _modelOptions.first;
          _useCustomModel = false;
        }
      }
    });
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    final option = LlmProviderOption.byType(_selectedProvider);
    String resolvedApiKey = _apiKeyController.text.trim();
    final bool apiKeyUnchanged =
        resolvedApiKey == _mask && _storedApiKey != null;

    if (apiKeyUnchanged) {
      resolvedApiKey = _storedApiKey!;
    }

    if (resolvedApiKey.isEmpty) {
      _showSnackBar('Please enter an API key for ${option.displayName}.');
      return;
    }

    late final String resolvedModel;
    if (_useCustomModel) {
      final customModel = _customModelController.text.trim();
      if (customModel.isEmpty) {
        _showSnackBar('Please provide a model name.');
        return;
      }
      resolvedModel = customModel;
    } else {
      final selected = _selectedModel;
      if (selected == null || selected.isEmpty) {
        _showSnackBar('Please select a model.');
        return;
      }
      resolvedModel = selected;
    }

    String? resolvedEndpoint;
    if (option.requiresEndpoint && option.allowEndpointEditing) {
      resolvedEndpoint = _endpointController.text.trim();
      if (resolvedEndpoint.isEmpty) {
        _showSnackBar('Please enter an endpoint URL.');
        return;
      }
    } else if (option.requiresEndpoint) {
      resolvedEndpoint = option.defaultEndpoint;
    } else {
      resolvedEndpoint = option.defaultEndpoint;
    }

    setState(() => _isSaving = true);

    try {
      await _secureStorageService.saveApiKeyForProvider(
        _selectedProvider,
        resolvedApiKey,
      );
      await _secureStorageService.saveSelectedModelForProvider(
        _selectedProvider,
        resolvedModel,
      );
      await _secureStorageService.saveEndpointForProvider(
        _selectedProvider,
        resolvedEndpoint,
      );
      await _secureStorageService.saveActiveProvider(_selectedProvider);

      if (!_modelOptions.contains(resolvedModel)) {
        setState(() => _modelOptions.add(resolvedModel));
      }

      setState(() {
        _storedApiKey = resolvedApiKey;
        _hasStoredApiKey = true;
        _statusMessage = '${option.displayName} API key is set.';
        _apiKeyController.text = _mask;
        _selectedModel = resolvedModel;
        if (_useCustomModel) {
          _customModelController.text = resolvedModel;
        }
      });

      _showSnackBar('Settings saved for ${option.displayName}.');
    } catch (e) {
      _showSnackBar('Error saving settings: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteSettings() async {
    final option = LlmProviderOption.byType(_selectedProvider);
    setState(() => _isSaving = true);
    try {
      await _secureStorageService.deleteApiKeyForProvider(_selectedProvider);
      await _secureStorageService.deleteSelectedModelForProvider(
        _selectedProvider,
      );
      if (option.allowEndpointEditing) {
        await _secureStorageService.saveEndpointForProvider(
          _selectedProvider,
          option.defaultEndpoint,
        );
      }

      setState(() {
        _storedApiKey = null;
        _hasStoredApiKey = false;
        _apiKeyController.clear();
        _statusMessage = '${option.displayName} API key is not set.';
        _selectedModel =
            option.defaultModels.isNotEmpty ? option.defaultModels.first : null;
        _useCustomModel = false;
        _customModelController.clear();
        _endpointController.text = option.defaultEndpoint;
      });

      _showSnackBar('${option.displayName} credentials cleared.');
    } catch (e) {
      _showSnackBar('Error deleting API key: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final option = LlmProviderOption.byType(_selectedProvider);
    final String dropdownModelValue = _useCustomModel
        ? _customModelToken
        : _selectedModel ??
            (_modelOptions.isNotEmpty ? _modelOptions.first : _customModelToken);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ダークモード',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        return Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (value) {
                            themeProvider.toggleTheme();
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                const Text(
                  'ノードサイズ設定',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ノードの幅: ${themeProvider.nodeWidth.round()}px'),
                        Slider(
                          value: themeProvider.nodeWidth,
                          min: 200,
                          max: 1000,
                          divisions: 30,
                          label: themeProvider.nodeWidth.round().toString(),
                          onChanged: (value) {
                            themeProvider.updateNodeSize(
                              value,
                              themeProvider.nodeHeight,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text('ノードの高さ: ${themeProvider.nodeHeight.round()}px'),
                        Slider(
                          value: themeProvider.nodeHeight,
                          min: 100,
                          max: 1000,
                          divisions: 30,
                          label: themeProvider.nodeHeight.round().toString(),
                          onChanged: (value) {
                            themeProvider.updateNodeSize(
                              themeProvider.nodeWidth,
                              value,
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                const Text(
                  'LLM 設定',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<LlmProviderType>(
                  value: _selectedProvider,
                  decoration: const InputDecoration(
                    labelText: 'Service',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      LlmProviderOption.all
                          .map(
                            (opt) => DropdownMenuItem<LlmProviderType>(
                              value: opt.type,
                              child: Text(opt.displayName),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value == null || value == _selectedProvider) return;
                    _loadProviderConfig(value);
                  },
                ),
                const SizedBox(height: 16),
                if (option.allowEndpointEditing) ...[
                  TextFormField(
                    controller: _endpointController,
                    decoration: InputDecoration(
                      labelText: 'Endpoint',
                      hintText: option.defaultEndpoint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Text('Endpoint: ${option.defaultEndpoint}'),
                  const SizedBox(height: 16),
                ],
                DropdownButtonFormField<String>(
                  value: dropdownModelValue,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    ..._modelOptions.map(
                      (model) => DropdownMenuItem<String>(
                        value: model,
                        child: Text(model),
                      ),
                    ),
                    const DropdownMenuItem<String>(
                      value: _customModelToken,
                      child: Text('Custom model...'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      if (value == _customModelToken) {
                        _useCustomModel = true;
                      } else {
                        _useCustomModel = false;
                        _selectedModel = value;
                      }
                    });
                  },
                ),
                if (_useCustomModel) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customModelController,
                    decoration: const InputDecoration(
                      labelText: 'Custom model name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '${option.displayName} API Key',
                    border: const OutlineInputBorder(),
                    hintText: 'Paste your ${option.displayName} API key here',
                  ),
                ),
                const SizedBox(height: 8),
                if (_statusMessage != null) Text(_statusMessage!),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      child:
                          _isSaving
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Save LLM Settings'),
                    ),
                    TextButton(
                      onPressed:
                          _isSaving || !_hasStoredApiKey
                              ? null
                              : _deleteSettings,
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
