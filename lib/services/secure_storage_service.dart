import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/llm_provider.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const _legacyApiKeyKey = 'llm_api_key';
  static const _legacyModelKey = 'selected_llm_model';
  static const _activeProviderKey = 'llm_active_provider';

  String _apiKeyKeyFor(LlmProviderType provider) =>
      'llm_api_key_${provider.storageKey}';
  String _endpointKeyFor(LlmProviderType provider) =>
      'llm_endpoint_${provider.storageKey}';
  String _modelKeyFor(LlmProviderType provider) =>
      'llm_model_${provider.storageKey}';

  Future<void> saveActiveProvider(LlmProviderType provider) async {
    await _storage.write(key: _activeProviderKey, value: provider.storageKey);
  }

  Future<LlmProviderType> getActiveProvider() async {
    final stored = await _storage.read(key: _activeProviderKey);
    final parsed = LlmProviderOption.typeFromStorage(stored);
    if (parsed != null) {
      return parsed;
    }

    final legacyKey = await _storage.read(key: _legacyApiKeyKey);
    if (legacyKey != null && legacyKey.isNotEmpty) {
      return LlmProviderType.gemini;
    }

    return LlmProviderType.gemini;
  }

  Future<void> saveApiKeyForProvider(
    LlmProviderType provider,
    String apiKey,
  ) async {
    await _storage.write(key: _apiKeyKeyFor(provider), value: apiKey);
    if (provider == LlmProviderType.gemini) {
      await _storage.write(key: _legacyApiKeyKey, value: apiKey);
    }
  }

  Future<String?> getApiKeyForProvider(LlmProviderType provider) async {
    final key = await _storage.read(key: _apiKeyKeyFor(provider));
    if (key != null && key.isNotEmpty) {
      return key;
    }
    if (provider == LlmProviderType.gemini) {
      return await _storage.read(key: _legacyApiKeyKey);
    }
    return null;
  }

  Future<void> deleteApiKeyForProvider(LlmProviderType provider) async {
    await _storage.delete(key: _apiKeyKeyFor(provider));
    await deleteSelectedModelForProvider(provider);
    if (provider == LlmProviderType.gemini) {
      await _storage.delete(key: _legacyApiKeyKey);
      await _storage.delete(key: _legacyModelKey);
    }
  }

  Future<void> saveEndpointForProvider(
    LlmProviderType provider,
    String? endpoint,
  ) async {
    if (endpoint == null || endpoint.isEmpty) {
      await _storage.delete(key: _endpointKeyFor(provider));
    } else {
      await _storage.write(key: _endpointKeyFor(provider), value: endpoint);
    }
  }

  Future<String?> getEndpointForProvider(LlmProviderType provider) async {
    final endpoint = await _storage.read(key: _endpointKeyFor(provider));
    if (endpoint == null || endpoint.isEmpty) {
      return null;
    }
    return endpoint;
  }

  Future<void> saveSelectedModelForProvider(
    LlmProviderType provider,
    String modelName,
  ) async {
    await _storage.write(key: _modelKeyFor(provider), value: modelName);
    if (provider == LlmProviderType.gemini) {
      await _storage.write(key: _legacyModelKey, value: modelName);
    }
  }

  Future<String?> getSelectedModelForProvider(LlmProviderType provider) async {
    final stored = await _storage.read(key: _modelKeyFor(provider));
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    if (provider == LlmProviderType.gemini) {
      final legacy = await _storage.read(key: _legacyModelKey);
      if (legacy != null && legacy.isNotEmpty) {
        return legacy;
      }
    }
    return null;
  }

  Future<void> deleteSelectedModelForProvider(LlmProviderType provider) async {
    await _storage.delete(key: _modelKeyFor(provider));
    if (provider == LlmProviderType.gemini) {
      await _storage.delete(key: _legacyModelKey);
    }
  }

  // Legacy helpers kept for backward compatibility --------------------------------

  @Deprecated('Use saveApiKeyForProvider instead.')
  Future<void> saveApiKey(String apiKey) =>
      saveApiKeyForProvider(LlmProviderType.gemini, apiKey);

  @Deprecated('Use getApiKeyForProvider instead.')
  Future<String?> getApiKey() =>
      getApiKeyForProvider(LlmProviderType.gemini);

  @Deprecated('Use deleteApiKeyForProvider instead.')
  Future<void> deleteApiKey() =>
      deleteApiKeyForProvider(LlmProviderType.gemini);

  @Deprecated('Use saveSelectedModelForProvider instead.')
  Future<void> saveSelectedModel(String modelName) =>
      saveSelectedModelForProvider(LlmProviderType.gemini, modelName);

  @Deprecated('Use getSelectedModelForProvider instead.')
  Future<String?> getSelectedModel() =>
      getSelectedModelForProvider(LlmProviderType.gemini);

  @Deprecated('Use deleteSelectedModelForProvider instead.')
  Future<void> deleteSelectedModel() =>
      deleteSelectedModelForProvider(LlmProviderType.gemini);
}
