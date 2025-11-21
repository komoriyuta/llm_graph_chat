import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/platform_util.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';
import '../models/session_list.dart';
import '../services/llm_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/chat_graph.dart';
import '../widgets/session_drawer.dart';
import 'settings_screen.dart';
import '../providers/session_notifier.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
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

    if (!mounted) return;
    setState(() {
      _selectedNode = null;
      _isGenerating = false;
    });
  }

  void _createNewSession() {
    ref.read(sessionProvider.notifier).createNewSession();
    setState(() => _selectedNode = null);
  }

  Future<void> _deleteSession(GraphSession session) async {
    ref.read(sessionProvider.notifier).deleteSession(session.id);
  }

  Future<void> _exportSession() async {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
                     '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final filename = 'chat_export_$timestamp.json';
    final current = ref.read(sessionProvider).currentSession;
    if (current == null) return;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(current.toJson());
    
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

  Future<void> _importSession() async {
    final content = await importTextFile(extensions: ['json']);
    if (content == null) return;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic> && decoded.containsKey('sessions')) {
        // SessionList 形式にも対応
        final list = SessionList.fromJson(decoded);
        for (final s in list.sessions) {
          ref.read(sessionProvider.notifier).addImportedSession(s);
        }
      } else if (decoded is Map<String, dynamic>) {
        final session = GraphSession.fromJson(decoded);
        ref.read(sessionProvider.notifier).addImportedSession(session);
      } else {
        throw Exception('Unsupported JSON');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('チャット履歴をインポートしました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('インポートに失敗しました')),
      );
    }
  }

  Future<void> _updateSessionTitle(GraphSession session, String newTitle) async {
    ref.read(sessionProvider.notifier).updateSessionTitle(session.id, newTitle);
  }

  void _switchSession(GraphSession session) {
    ref.read(sessionProvider.notifier).switchSession(session.id);
    setState(() => _selectedNode = null);
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

    final notifier = ref.read(sessionProvider.notifier);
    final firstNode = await notifier.addRootNode(userInput);
    setState(() {
      _selectedNode = firstNode;
      _isGenerating = false;
    });
  }

  void _toggleNodeCollapse(ChatNode node) {
    ref.read(sessionProvider.notifier).toggleNodeCollapse(node.id);
  }

  void _handleGenerateChild(ChatNode parentNode, String userInput) async {
    if (userInput.isEmpty || _isGenerating) {
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    final notifier = ref.read(sessionProvider.notifier);
    final newNode = await notifier.addChildNode(parentNode, userInput);
    setState(() {
      _selectedNode = newNode;
      _isGenerating = false;
    });
  }

  void _handleRegenerate(ChatNode node) async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    final notifier = ref.read(sessionProvider.notifier);
    await notifier.regenerateNode(node);
    setState(() => _isGenerating = false);
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
    final sessionState = ref.watch(sessionProvider);
    final currentSession = sessionState.currentSession;
    final isSessionInitialized = currentSession != null && !sessionState.isLoading;

    if (_isGenerating && !isSessionInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      drawer: SessionDrawer(
        sessions: sessionState.sessions,
        currentSession: currentSession,
        onSessionSelect: _switchSession,
        onNewSession: _createNewSession,
        onDeleteSession: _deleteSession,
        onSessionTitleEdit: _updateSessionTitle,
      ),
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(isSessionInitialized ? currentSession!.title : "Chat"),
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
              icon: const Icon(Icons.upload_file),
              tooltip: 'インポート',
              onPressed: _importSession,
            ),
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
          ? (currentSession.nodes.isEmpty
              ? _buildInitialInputView()
              : ChatGraphWidget(
                  session: currentSession,
                  graphVersion: sessionState.graphVersion,
                  selectedNode: _selectedNode,
                  onGenerateChild: _handleGenerateChild,
                  onNodeSelected: _handleNodeSelected,
                  onToggleCollapse: _toggleNodeCollapse,
                  onRegenerate: _handleRegenerate,
                  onSessionSave: () => ref.read(sessionProvider.notifier).scheduleSave(), 
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
