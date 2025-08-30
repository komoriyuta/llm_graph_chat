import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/platform_util.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';
import '../models/session_list.dart';
import '../services/llm_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/chat_graph.dart';
import '../widgets/session_drawer.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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


  Future<void> _saveCurrentSession() async {
    await context.read<SessionProvider>().saveNow();
  }

  void _createNewSession() {
    context.read<SessionProvider>().createNewSession();
    setState(() => _selectedNode = null);
  }

  Future<void> _deleteSession(GraphSession session) async {
    context.read<SessionProvider>().deleteSession(session.id);
  }

  Future<void> _exportSession() async {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
                     '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final filename = 'chat_export_$timestamp.json';
    final current = context.read<SessionProvider>().currentSession;
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
          context.read<SessionProvider>().addImportedSession(s);
        }
      } else if (decoded is Map<String, dynamic>) {
        final session = GraphSession.fromJson(decoded);
        context.read<SessionProvider>().addImportedSession(session);
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
    context.read<SessionProvider>().updateSessionTitle(session.id, newTitle);
  }

  void _switchSession(GraphSession session) {
    context.read<SessionProvider>().switchSession(session.id);
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

    final provider = context.read<SessionProvider>();
    final firstNode = provider.addRootNode(userInput);
    setState(() => _selectedNode = firstNode);

    final current = provider.currentSession!;
    final llmResponse = await _llmService.generateResponse(current, firstNode);

    provider.updateNodeOutput(firstNode.id, llmResponse);
    setState(() => _isGenerating = false);
  }

  void _toggleNodeCollapse(ChatNode node) {
    context.read<SessionProvider>().toggleNodeCollapse(node.id);
  }

  void _handleGenerateChild(ChatNode parentNode, String userInput) async {
    if (userInput.isEmpty || _isGenerating) {
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    final provider = context.read<SessionProvider>();
    final newNode = provider.addChildNode(parentNode, userInput);
    setState(() => _selectedNode = newNode);

    final current = provider.currentSession!;
    final llmResponse = await _llmService.generateResponse(current, newNode);

    provider.updateNodeOutput(newNode.id, llmResponse);
    setState(() => _isGenerating = false);
  }

  void _handleRegenerate(ChatNode node) async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    final provider = context.read<SessionProvider>();
    final current = provider.currentSession!;
    final llmResponse = await _llmService.generateResponse(current, node);
    provider.updateNodeOutput(node.id, llmResponse);
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
    final sessionProvider = context.watch<SessionProvider>();
    final currentSession = sessionProvider.currentSession;
    final isSessionInitialized = currentSession != null;

    if (_isGenerating && !isSessionInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      drawer: SessionDrawer(
        sessions: sessionProvider.sessions,
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
                  graphVersion: sessionProvider.graphVersion,
                  selectedNode: _selectedNode,
                  onGenerateChild: _handleGenerateChild,
                  onNodeSelected: _handleNodeSelected,
                  onToggleCollapse: _toggleNodeCollapse,
                  onRegenerate: _handleRegenerate,
                  onSessionSave: () => sessionProvider.scheduleSave(), 
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
