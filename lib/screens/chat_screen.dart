import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/platform_util.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';
import '../services/llm_service.dart';
import '../services/secure_storage_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/chat_graph.dart';
import '../widgets/session_drawer.dart';
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
  late LocalStorageService _storageService;
  bool _isGenerating = false;
  String? _selectedModel;
  List<String> _availableModels = [];
  List<GraphSession> _allSessions = [];

  @override
  void initState() {
    super.initState();
    _llmService = LlmService(SecureStorageService());
    _storageService = LocalStorageService();
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

    // 保存されているセッションを読み込む
    final sessions = await _storageService.loadSessions();
    if (!mounted) return;

    setState(() {
      _allSessions = sessions;
      if (sessions.isNotEmpty) {
        _currentSession = sessions.first;
      } else {
        _currentSession = GraphSession(title: 'New Chat');
        _allSessions.add(_currentSession);
      }
      _selectedNode = null;
      _isGenerating = false;
    });
  }

  Future<void> _saveCurrentSession() async {
    await _storageService.saveSession(_currentSession);
  }

  void _createNewSession() {
    final newSession = GraphSession(title: 'New Chat');
    setState(() {
      _allSessions.add(newSession);
      _currentSession = newSession;
      _selectedNode = null;
    });
    _saveCurrentSession();
  }

  Future<void> _deleteSession(GraphSession session) async {
    await _storageService.deleteSession(session.id);
    setState(() {
      _allSessions.removeWhere((s) => s.id == session.id);
      if (_currentSession.id == session.id) {
        if (_allSessions.isNotEmpty) {
          _currentSession = _allSessions.first;
        } else {
          _createNewSession();
        }
      }
    });
  }

  Future<void> _exportSession() async {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
                     '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final filename = 'chat_export_$timestamp.json';
    
    // GraphSessionをJSON文字列に変換
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_currentSession.toJson());
    
    try {
      await exportFile(jsonStr, filename);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('チャット履歴をエクスポートしました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エクスポートに失敗しました')),
      );
    }
  }

  Future<void> _updateSessionTitle(GraphSession session, String newTitle) async {
    final index = _allSessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      final updatedSession = GraphSession(
        id: session.id,
        title: newTitle,
        nodes: session.nodes,
        rootNodeId: session.rootNodeId,
        createdAt: session.createdAt,
        updatedAt: DateTime.now(),
      );

      setState(() {
        _allSessions[index] = updatedSession;
        if (_currentSession.id == session.id) {
          _currentSession = updatedSession;
        }
      });
      await _storageService.updateSession(updatedSession);
    }
  }

  void _switchSession(GraphSession session) {
    setState(() {
      _currentSession = session;
      _selectedNode = null;
    });
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
    await _saveCurrentSession();

    final llmResponse = await _llmService.generateResponse(_currentSession, firstNode);

    setState(() {
      final nodeIndex = _currentSession.nodes.indexWhere((n) => n.id == firstNode.id);
      if (nodeIndex != -1) {
        _currentSession.nodes[nodeIndex].llmOutput = llmResponse;
      }
      _isGenerating = false;
    });
    await _saveCurrentSession();
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
    await _saveCurrentSession();

    final llmResponse = await _llmService.generateResponse(_currentSession, newNode);

    setState(() {
      final nodeIndex = _currentSession.nodes.indexWhere((n) => n.id == newNode.id);
      if (nodeIndex != -1) {
        _currentSession.nodes[nodeIndex].llmOutput = llmResponse;
      }
      _isGenerating = false;
    });
    await _saveCurrentSession();
  }

  void _handleRegenerate(ChatNode node) async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    final llmResponse = await _llmService.generateResponse(_currentSession, node);

    setState(() {
      final nodeIndex = _currentSession.nodes.indexWhere((n) => n.id == node.id);
      if (nodeIndex != -1) {
        _currentSession.nodes[nodeIndex].llmOutput = llmResponse;
      }
      _isGenerating = false;
    });
    await _saveCurrentSession();
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
      drawer: SessionDrawer(
        sessions: _allSessions,
        currentSession: _currentSession,
        onSessionSelect: _switchSession,
        onNewSession: _createNewSession,
        onDeleteSession: _deleteSession,
        onSessionTitleEdit: _updateSessionTitle,
      ),
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
          if (isSessionInitialized)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'エクスポート',
              onPressed: _exportSession,
            ),
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
                  onRegenerate: _handleRegenerate,
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