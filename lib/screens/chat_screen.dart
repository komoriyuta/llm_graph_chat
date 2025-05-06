import 'package:flutter/material.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';
import '../services/llm_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/chat_graph.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late GraphSession _currentSession;
  ChatNode? _selectedNode;
  late LlmService _llmService;
  bool _isGenerating = false;
  String? _selectedModel;
  List<String> _availableModels = [];

  @override
  void initState() {
    super.initState();
    _llmService = LlmService(SecureStorageService());
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() => _isGenerating = true);
    await _llmService.initialize();

    // 利用可能なモデルリストを取得
    _availableModels = _llmService.getAvailableModels();
    
    // 現在選択されているモデルを取得
    final selectedModel = await SecureStorageService().getSelectedModel();
    _selectedModel = selectedModel ?? LlmService.defaultModel;

    // セッションの初期化
    if (!mounted) return;
    _currentSession = GraphSession(title: 'New Chat');
    _selectedNode = null;

    setState(() => _isGenerating = false);
  }

  void _handleNodeSelected(ChatNode node) {
    setState(() {
      _selectedNode = node;
    });
  }

  void _startChat(String userInput) async {
    if (userInput.isEmpty || _isGenerating) {
      return;
    }
    setState(() => _isGenerating = true);

    final firstNode = ChatNode(
      parentId: null,
      userInput: userInput,
      id: _currentSession.rootNodeId,
    );

    setState(() {
      _currentSession.addNode(firstNode);
      _selectedNode = firstNode;
    });

    final llmResponse = await _llmService.generateResponse(_currentSession, firstNode);

    setState(() {
      final nodeIndex = _currentSession.nodes.indexWhere((n) => n.id == firstNode.id);
      if (nodeIndex != -1) {
        _currentSession.nodes[nodeIndex].llmOutput = llmResponse;
      }
      _isGenerating = false;
    });
  }

  void _toggleNodeCollapse(ChatNode node) {
    setState(() {
      final nodeIndex = _currentSession.nodes.indexWhere((n) => n.id == node.id);
      if (nodeIndex != -1) {
        _currentSession.nodes[nodeIndex].isCollapsed = !_currentSession.nodes[nodeIndex].isCollapsed;
      }
    });
  }

  void _handleGenerateChild(ChatNode parentNode, String userInput) async {
    if (userInput.isEmpty || _isGenerating) {
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    final newNode = ChatNode(
      parentId: parentNode.id,
      userInput: userInput,
    );

    setState(() {
      _currentSession.addNode(newNode);
      final parentIndex = _currentSession.nodes.indexWhere((n) => n.id == parentNode.id);
      if (parentIndex != -1) {
        _currentSession.nodes[parentIndex].childrenIds.add(newNode.id);
      }
      _selectedNode = newNode;
    });

    final llmResponse = await _llmService.generateResponse(_currentSession, newNode);

    setState(() {
      final nodeIndex = _currentSession.nodes.indexWhere((n) => n.id == newNode.id);
      if (nodeIndex != -1) {
        _currentSession.nodes[nodeIndex].llmOutput = llmResponse;
      }
      _isGenerating = false;
    });
  }

  Future<void> _handleModelChange(String? newModel) async {
    if (newModel != null && newModel != _selectedModel) {
      setState(() => _isGenerating = true);
      
      try {
        await SecureStorageService().saveSelectedModel(newModel);
        setState(() {
          _selectedModel = newModel;
        });
        await _llmService.initialize();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully switched to model: $newModel')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error changing model')),
        );
      } finally {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isSessionInitialized = false;
    try {
      if (_currentSession != null) isSessionInitialized = true;
    } catch (e) {
      isSessionInitialized = false;
    }

    if (_isGenerating && !isSessionInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(isSessionInitialized ? _currentSession.title : "Chat"),
            ),
            if (_availableModels.isNotEmpty) ...[
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedModel,
                items: _availableModels.map((String model) {
                  return DropdownMenuItem<String>(
                    value: model,
                    child: Text(
                      model,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: _handleModelChange,
                underline: Container(), // AppBarに合わせて下線を削除
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 14,
                ),
                iconEnabledColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ],
          ],
        ),
        actions: [
          if (_isGenerating && isSessionInitialized)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) {
                _llmService.initialize();
              });
            },
          ),
        ],
      ),
      body: isSessionInitialized
          ? (_currentSession.nodes.isEmpty
              ? _buildInitialInputView()
              : ChatGraphWidget(
                  session: _currentSession,
                  selectedNode: _selectedNode,
                  onGenerateChild: _handleGenerateChild,
                  onNodeSelected: _handleNodeSelected,
                  onToggleCollapse: _toggleNodeCollapse,
                ))
          : const Center(child: Text("Initializing...")),
    );
  }

  Widget _buildInitialInputView() {
    final TextEditingController initialInputController = TextEditingController();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Start a new chat", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: initialInputController,
              decoration: const InputDecoration(
                hintText: 'Enter your first message...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => _startChat(value),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _startChat(initialInputController.text),
              child: const Text('Start Chat'),
            ),
          ],
        ),
      ),
    );
  }
}