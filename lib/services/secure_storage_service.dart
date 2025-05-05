import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();
  static const _apiKeyKey = 'llm_api_key';
  static const _selectedModelKey = 'selected_llm_model'; // Key for selected model

  Future<void> saveApiKey(String apiKey) async {
    await _storage.write(key: _apiKeyKey, value: apiKey);
  }

  Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKeyKey);
  }

  Future<void> deleteApiKey() async {
    await _storage.delete(key: _apiKeyKey);
    // Also delete selected model when API key is deleted
    await deleteSelectedModel();
  }

  // --- Model Selection ---

  Future<void> saveSelectedModel(String modelName) async {
    await _storage.write(key: _selectedModelKey, value: modelName);
  }

  Future<String?> getSelectedModel() async {
    return await _storage.read(key: _selectedModelKey);
  }

  Future<void> deleteSelectedModel() async {
    await _storage.delete(key: _selectedModelKey);
  }
}