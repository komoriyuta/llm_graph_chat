import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_node.dart';
import '../models/graph_session.dart';
import '../models/llm_provider.dart';
import 'secure_storage_service.dart';

class LlmService {
  LlmService(this._secureStorageService);

  static const List<LlmProviderOption> providerOptions = LlmProviderOption.all;

  final SecureStorageService _secureStorageService;

  LlmProviderType _provider = LlmProviderType.gemini;
  String? _apiKey;
  String? _endpoint;
  String? _selectedModelName;

  LlmProviderType get currentProvider => _provider;
  String? get apiKey => _apiKey;
  String? get endpoint => _endpoint;
  String? get selectedModel => _selectedModelName;

  List<String> getAvailableModels() {
    final option = LlmProviderOption.byType(_provider);
    final models = [...option.defaultModels];
    if (_selectedModelName != null &&
        _selectedModelName!.isNotEmpty &&
        !models.contains(_selectedModelName)) {
      models.add(_selectedModelName!);
    }
    return models;
  }

  Future<void> initialize() async {
    _provider = await _secureStorageService.getActiveProvider();
    await _secureStorageService.saveActiveProvider(_provider);
    await _loadProviderState(_provider);

    if (_selectedModelName == null || _selectedModelName!.isEmpty) {
      final option = LlmProviderOption.byType(_provider);
      if (option.defaultModels.isNotEmpty) {
        _selectedModelName = option.defaultModels.first;
        await _secureStorageService.saveSelectedModelForProvider(
          _provider,
          _selectedModelName!,
        );
      }
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      print('LLM Service: API key not configured for provider $_provider');
    } else {
      print(
        'LLM Service initialized with provider $_provider model $_selectedModelName',
      );
    }
  }

  Future<void> setCurrentProvider(LlmProviderType provider) async {
    _provider = provider;
    await _secureStorageService.saveActiveProvider(provider);
    await _loadProviderState(provider);
  }

  Future<void> setSelectedModel(String model) async {
    _selectedModelName = model;
    await _secureStorageService.saveSelectedModelForProvider(_provider, model);
  }

  Future<void> refreshCachedCredentials() async {
    await _loadProviderState(_provider);
  }

  Future<String> generateResponse(
    GraphSession session,
    ChatNode currentNode,
  ) async {
    if (_selectedModelName == null || _selectedModelName!.isEmpty) {
      return 'Error: Model not selected.';
    }
    if (_apiKey == null || _apiKey!.isEmpty) {
      return 'Error: API key not set for ${_provider.displayName}. Set it in Settings.';
    }

    final history = _buildChatHistory(session, currentNode);

    try {
      switch (_provider) {
        case LlmProviderType.gemini:
          return await _callGemini(history);
        case LlmProviderType.openai:
        case LlmProviderType.custom:
          return await _callOpenAiCompatible(history);
        case LlmProviderType.claude:
          return await _callClaude(history);
      }
    } catch (e) {
      print('Error generating LLM response: $e');
      return 'Error: Could not connect to LLM. ${e.toString()}';
    }
  }

  Future<void> updateEndpoint(String? endpoint) async {
    _endpoint = endpoint;
    await _secureStorageService.saveEndpointForProvider(_provider, endpoint);
  }

  Future<void> updateApiKey(String apiKey) async {
    _apiKey = apiKey;
    await _secureStorageService.saveApiKeyForProvider(_provider, apiKey);
  }

  Future<void> deleteApiKey() async {
    await _secureStorageService.deleteApiKeyForProvider(_provider);
    _apiKey = null;
    _selectedModelName = null;
  }

  Future<void> _loadProviderState(LlmProviderType provider) async {
    final option = LlmProviderOption.byType(provider);
    _apiKey = await _secureStorageService.getApiKeyForProvider(provider);
    _endpoint =
        await _secureStorageService.getEndpointForProvider(provider) ??
        option.defaultEndpoint;
    _selectedModelName =
        await _secureStorageService.getSelectedModelForProvider(provider) ??
        (option.defaultModels.isNotEmpty ? option.defaultModels.first : null);
  }

  List<_ChatMessage> _buildChatHistory(
    GraphSession session,
    ChatNode currentNode,
  ) {
    final history = <_ChatMessage>[];
    ChatNode? node = currentNode;
    final nodeMap = {for (final n in session.nodes) n.id: n};

    while (node != null) {
      final isCurrentNode = node.id == currentNode.id;
      final trimmedOutput = node.llmOutput.trim();

      if (!isCurrentNode && trimmedOutput.isNotEmpty) {
        history.insert(
          0,
          _ChatMessage(role: 'assistant', content: trimmedOutput),
        );
      }

      history.insert(0, _ChatMessage(role: 'user', content: node.userInput));
      node = node.parentId != null ? nodeMap[node.parentId] : null;
    }

    return history;
  }

  Future<String> _callGemini(List<_ChatMessage> history) async {
    final base =
        _endpoint ??
        LlmProviderOption.byType(LlmProviderType.gemini).defaultEndpoint;
    final uri = _composeUri(
      base,
      '/models/$_selectedModelName:generateContent',
      queryParameters: {'key': _apiKey!},
    );

    final payload = {
      'contents':
          history
              .map(
                (m) => {
                  'parts': [
                    {'text': m.content},
                  ],
                  'role': m.role == 'assistant' ? 'model' : 'user',
                },
              )
              .toList(),
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _extractGeminiResponseText(data);
    }

    final error = _safeErrorMessage(response.body);
    throw Exception('Gemini request failed (${response.statusCode}): $error');
  }

  Future<String> _callOpenAiCompatible(List<_ChatMessage> history) async {
    final base =
        _endpoint ?? LlmProviderOption.byType(_provider).defaultEndpoint;
    if (base.isEmpty) {
      throw Exception('No endpoint configured for ${_provider.displayName}.');
    }

    final uri = _composeUri(base, '/chat/completions');
    final payload = {
      'model': _selectedModelName,
      'messages':
          history
              .map(
                (m) => {
                  'role': m.role == 'assistant' ? 'assistant' : 'user',
                  'content': m.content,
                },
              )
              .toList(),
    };

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, dynamic>) {
          final message = first['message'];
          if (message is Map<String, dynamic>) {
            final content = message['content'];
            if (content is String && content.trim().isNotEmpty) {
              return content;
            }
            if (content is List) {
              final buffer = StringBuffer();
              for (final part in content) {
                if (part is Map<String, dynamic>) {
                  final text = part['text'];
                  if (text is String) {
                    buffer.write(text);
                  }
                }
              }
              final aggregated = buffer.toString();
              if (aggregated.trim().isNotEmpty) {
                return aggregated;
              }
            }
          }
          final text = first['text'];
          if (text is String && text.trim().isNotEmpty) {
            return text;
          }
        }
      }
      throw Exception('OpenAI-compatible response did not contain text.');
    }

    final error = _safeErrorMessage(response.body);
    throw Exception(
      'OpenAI-compatible request failed (${response.statusCode}): $error',
    );
  }

  Future<String> _callClaude(List<_ChatMessage> history) async {
    final base =
        _endpoint ??
        LlmProviderOption.byType(LlmProviderType.claude).defaultEndpoint;
    if (base.isEmpty) {
      throw Exception('No endpoint configured for Claude.');
    }

    final uri = _composeUri(base, '/messages');
    final payload = {
      'model': _selectedModelName,
      'max_tokens': 1024,
      'messages':
          history
              .map(
                (m) => {
                  'role': m.role,
                  'content': [
                    {'type': 'text', 'text': m.content},
                  ],
                },
              )
              .toList(),
    };

    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': _apiKey!,
      'anthropic-version': '2023-06-01',
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'];
      if (content is List && content.isNotEmpty) {
        final buffer = StringBuffer();
        for (final part in content) {
          if (part is Map<String, dynamic>) {
            final text = part['text'];
            if (text is String) {
              buffer.write(text);
            }
          }
        }
        final aggregated = buffer.toString();
        if (aggregated.trim().isNotEmpty) {
          return aggregated;
        }
      }
      final outputText = data['output_text'];
      if (outputText is String && outputText.trim().isNotEmpty) {
        return outputText;
      }
      throw Exception('Claude response did not contain text.');
    }

    final error = _safeErrorMessage(response.body);
    throw Exception('Claude request failed (${response.statusCode}): $error');
  }

  String _extractGeminiResponseText(Map<String, dynamic> data) {
    final candidates = data['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      for (final candidate in candidates) {
        if (candidate is Map<String, dynamic>) {
          final content = candidate['content'];
          if (content is Map<String, dynamic>) {
            final parts = content['parts'];
            if (parts is List && parts.isNotEmpty) {
              for (final part in parts) {
                if (part is Map<String, dynamic>) {
                  final text = part['text'];
                  if (text is String && text.trim().isNotEmpty) {
                    return text;
                  }
                }
              }
            }
          }
          final outputText = candidate['output_text'];
          if (outputText is String && outputText.trim().isNotEmpty) {
            return outputText;
          }
          final text = candidate['text'];
          if (text is String && text.trim().isNotEmpty) {
            return text;
          }
        }
      }
    }
    final outputText = data['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return outputText;
    }
    final text = data['text'];
    if (text is String && text.trim().isNotEmpty) {
      return text;
    }
    throw Exception('Gemini response did not contain text.');
  }

  Uri _composeUri(
    String base,
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final normalizedBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: queryParameters);
  }

  String _safeErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String) {
            return message;
          }
        }
        final message = decoded['message'];
        if (message is String) {
          return message;
        }
      }
    } catch (_) {}
    return body;
  }
}

class _ChatMessage {
  final String role;
  final String content;

  const _ChatMessage({required this.role, required this.content});
}
