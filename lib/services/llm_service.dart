import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';

class LlmService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  
  // 利用可能なモデルのリスト
  static const List<String> availableModels = [
    'gemini-2.5-flash-preview-04-17','gemini-2.5-pro-preview-03-25','gemini-2.0-flash','gemini-2.0-flash-lite','gemini-1.5-flash','gemini-1.5-flash-8b','gemini-1.5-pro'
  ];

  // デフォルトモデル
  static const String defaultModel = 'gemini-2.0-flash';

  final SecureStorageService _secureStorageService;
  String? _apiKey;
  String? _selectedModelName;

  LlmService(this._secureStorageService);

  List<String> getAvailableModels() {
    return List.from(availableModels);
  }

  Future<void> initialize() async {
    _apiKey = await _secureStorageService.getApiKey();
    _selectedModelName = await _secureStorageService.getSelectedModel();

    if (_selectedModelName == null || _selectedModelName!.isEmpty) {
      _selectedModelName = defaultModel;
      await _secureStorageService.saveSelectedModel(defaultModel);
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      print('API Key not found. Please set the API Key.');
    } else {
      print('LLM Service Initialized with model: $_selectedModelName');
    }
  }

  Future<String> generateResponse(GraphSession session, ChatNode currentNode) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return 'Error: API Key not set.';
    }

    if (_selectedModelName == null || _selectedModelName!.isEmpty) {
      return 'Error: Model not selected.';
    }

    try {
      final url = Uri.parse('$_baseUrl/models/$_selectedModelName:generateContent?key=$_apiKey');
      final chatHistory = _buildChatHistory(session, currentNode);

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': chatHistory,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _extractResponseText(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error']['message'] ?? 'Unknown error occurred');
      }
    } catch (e) {
      print('Error generating LLM response: $e');
      if (e.toString().contains('API key not valid')) {
        return 'Error: Invalid API Key. Please check your API Key in settings.';
      }
      return 'Error: Could not connect to LLM. ${e.toString()}';
    }
  }

  String _extractResponseText(Map<String, dynamic> data) {
    try {
      return data['candidates'][0]['content']['parts'][0]['text'] ?? 'Error: No response text from LLM.';
    } catch (e) {
      print('Error extracting response text: $e');
      return 'Error: Invalid response format from LLM.';
    }
  }

  List<Map<String, dynamic>> _buildChatHistory(GraphSession session, ChatNode currentNode) {
    final history = <Map<String, dynamic>>[];
    ChatNode? node = currentNode;
    final nodeMap = {for (var n in session.nodes) n.id: n};

    // チャット履歴を構築（新しい形式に合わせる）
    while (node != null) {
      if (node.llmOutput.isNotEmpty) {
        history.insert(0, {
          'parts': [{'text': node.llmOutput}],
          'role': 'model'
        });
      }

      history.insert(0, {
        'parts': [{'text': node.userInput}],
        'role': 'user'
      });

      node = node.parentId != null ? nodeMap[node.parentId] : null;
    }

    return history;
  }
}