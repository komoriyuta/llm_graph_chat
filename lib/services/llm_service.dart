import 'package:google_generative_ai/google_generative_ai.dart'; // Add this import
import 'package:google_generative_ai/google_generative_ai.dart';
import 'secure_storage_service.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';

class LlmService {
  final SecureStorageService _secureStorageService;
  GenerativeModel? _model;
  String? _apiKey; // Store API key locally
  String? _selectedModelName; // Store the selected model name

  LlmService(this._secureStorageService);

  // Initialize: Load API key and selected model, then create the model instance
  Future<void> initialize() async {
    _apiKey = await _secureStorageService.getApiKey();
    _selectedModelName = await _secureStorageService.getSelectedModel();

    if (_apiKey != null && _apiKey!.isNotEmpty && _selectedModelName != null && _selectedModelName!.isNotEmpty) {
      try {
        _model = GenerativeModel(model: _selectedModelName!, apiKey: _apiKey!);
        print('LLM Service Initialized with model: $_selectedModelName');
      } catch (e) {
         print('Error initializing GenerativeModel: $e');
         _model = null; // Ensure model is null if initialization fails
      }
    } else {
      _model = null; // Ensure model is null if no key or model selected
      if (_apiKey == null || _apiKey!.isEmpty) {
        print('API Key not found. Please set the API Key.');
      }
      if (_selectedModelName == null || _selectedModelName!.isEmpty) {
         print('LLM Model not selected. Please select a model in settings.');
      }
    }
  }

  // // Get available models that support 'generateContent'
  // // NOTE: Temporarily commented out due to potential API incompatibility with listModels
  // Future<List<String>> getAvailableModels() async {
  //   if (_apiKey == null || _apiKey!.isEmpty) {
  //     print('Cannot list models: API Key not set.');
  //     return []; // Return empty list if no API key
  //   }
  //   try {
  //     // Use the top-level function to list models
  //     // final modelsResponse = await GoogleGenerativeAI.listModels(apiKey: _apiKey!);
  //     // // Filter models that support 'generateContent'
  //     // final supportedModels = modelsResponse.models
  //     //     .where((model) => model.supportedGenerationMethods != null && model.supportedGenerationMethods!.contains('generateContent'))
  //     //     .map((model) => model.name) // Extract model names (e.g., "models/gemini-1.5-flash-latest")
  //     //     .toList();
  //     // // print("Available models supporting generateContent: $supportedModels"); // Debugging
  //     // return supportedModels;
  //     print("Warning: Model listing is temporarily disabled.");
  //     return ['gemini-1.5-flash-latest', 'models/gemini-pro']; // Return common defaults as fallback
  //   } catch (e) {
  //     print('Error listing models: $e');
  //     return []; // Return empty list on error
  //   }
  // }


  Future<String> generateResponse(GraphSession session, ChatNode currentNode) async {
    // Ensure initialized before generating
    if (_model == null) {
      await initialize();
      if (_model == null) {
        // Provide more specific error based on initialization status
        if (_apiKey == null || _apiKey!.isEmpty) return 'Error: API Key not set.';
        if (_selectedModelName == null || _selectedModelName!.isEmpty) return 'Error: Model not selected.';
        return 'Error: LLM Service not initialized correctly.';
      }
    }

    final chatHistory = _buildChatHistory(session, currentNode);

    try {
      final response = await _model!.generateContent(chatHistory);
      return response.text ?? 'Error: No response text from LLM.';
    } catch (e) {
      print('Error generating LLM response: $e');
      // Check for specific API key errors if possible
      if (e.toString().contains('API key not valid')) {
         return 'Error: Invalid API Key. Please check your API Key in settings.';
      }
      return 'Error: Could not connect to LLM.';
    }
  }

  List<Content> _buildChatHistory(GraphSession session, ChatNode currentNode) {
    final history = <Content>[];
    ChatNode? node = currentNode;
    final nodeMap = { for (var n in session.nodes) n.id : n };

    // Traverse up the tree from the current node to the root
    while (node != null) {
      // Add LLM output first (if available) as 'model' role
      if (node.llmOutput.isNotEmpty) {
        history.insert(0, Content('model', [TextPart(node.llmOutput)]));
      }
      // Add user input as 'user' role
      history.insert(0, Content('user', [TextPart(node.userInput)]));

      // Move to the parent node
      node = node.parentId != null ? nodeMap[node.parentId] : null;
    }

    // The API expects alternating user/model roles, starting with user.
    // If the first message is from the model (e.g., root node only has LLM output),
    // we might need adjustment, but our structure ensures user input is always present first.

    return history;
  }
}