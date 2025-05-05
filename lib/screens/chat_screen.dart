import 'package:flutter/material.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';
import '../services/llm_service.dart'; // Import LlmService
import '../services/secure_storage_service.dart'; // Import SecureStorageService
import '../widgets/chat_graph.dart';
import 'settings_screen.dart'; // Import SettingsScreen

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // TODO: Implement session loading/creation and persistence
  late GraphSession _currentSession;
  ChatNode? _selectedNode; // Still useful for highlighting/focusing in graph
  // final TextEditingController _textController = TextEditingController(); // REMOVED
  late LlmService _llmService; // Add LlmService instance
  bool _isGenerating = false; // Renamed isLoading for clarity

  @override
  void initState() {
    super.initState();
    _llmService = LlmService(SecureStorageService()); // Initialize LlmService
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() => _isGenerating = true); // Start loading
    await _llmService.initialize(); // Initialize LLM service (loads API key)

    // TODO: Implement session loading/creation and persistence
    // Initialize with an empty session
    if (!mounted) return; // Check if widget is still mounted after async gap
    _currentSession = GraphSession(title: 'New Chat');
    _selectedNode = null; // No node selected initially

    // TODO: Implement loading existing sessions here. If a session is loaded,
    // _currentSession.nodes will not be empty.

    setState(() => _isGenerating = false); // Stop loading
  }

  // Handles node selection from the graph widget
  void _handleNodeSelected(ChatNode node) {
    setState(() {
      _selectedNode = node;
    });
    // No need to clear text field here as it's inside the node widget
  }

  // Handles starting the chat with the first message
  void _startChat(String userInput) async {
     if (userInput.isEmpty || _isGenerating) {
      return;
    }
    setState(() => _isGenerating = true);

    // Create the very first node (root node)
    final firstNode = ChatNode(
      parentId: null, // No parent for the root
      userInput: userInput,
      id: _currentSession.rootNodeId, // Use the session's rootNodeId
    );

     // Add the node and select it
    setState(() {
      _currentSession.addNode(firstNode);
      _selectedNode = firstNode;
    });

     // Call LLM API for the first node
    final llmResponse = await _llmService.generateResponse(_currentSession, firstNode);

     // Update the node with the response
     setState(() {
       final nodeIndex = _currentSession.nodes.indexWhere((n) => n.id == firstNode.id);
       if (nodeIndex != -1) {
         _currentSession.nodes[nodeIndex].llmOutput = llmResponse;
       }
       _isGenerating = false;
     });
     // TODO: Persist session changes
  }


  // Toggles the collapsed state of a node and its descendants
  void _toggleNodeCollapse(ChatNode node) {
    setState(() {
      final nodeIndex = _currentSession.nodes.indexWhere((n) => n.id == node.id);
      if (nodeIndex != -1) {
        _currentSession.nodes[nodeIndex].isCollapsed = !_currentSession.nodes[nodeIndex].isCollapsed;
        // Note: We are only toggling the flag here. The actual hiding/showing
        // logic will be handled in ChatGraphWidget's _buildGraph method.
      }
      // Force rebuild of GraphView using UniqueKey
    });
     // TODO: Persist session changes (including collapse state)
  }


  // Handles generating subsequent child nodes
  void _handleGenerateChild(ChatNode parentNode, String userInput) async {
    if (userInput.isEmpty || _isGenerating) {
      return; // Do nothing if input is empty or already generating
    }

    setState(() {
      _isGenerating = true; // Start loading indicator
      // _selectedNode = parentNode; // Keep parent selected initially? Or select new node? Let's select new.
    });

    // Create the new node optimistically
    final newNode = ChatNode(
      parentId: parentNode.id,
      userInput: userInput,
    );

    // Add the new node to the session state
    setState(() {
      _currentSession.addNode(newNode);
      final parentIndex = _currentSession.nodes.indexWhere((n) => n.id == parentNode.id);
      if (parentIndex != -1) {
        _currentSession.nodes[parentIndex].childrenIds.add(newNode.id);
      }
      _selectedNode = newNode; // Select the newly created node
    });

    // Call LLM API
    final llmResponse = await _llmService.generateResponse(_currentSession, newNode);

    // Update the new node with the LLM response
    setState(() {
      final nodeIndex = _currentSession.nodes.indexWhere((n) => n.id == newNode.id);
      if (nodeIndex != -1) {
        _currentSession.nodes[nodeIndex].llmOutput = llmResponse;
      }
      _isGenerating = false; // Stop loading indicator
    });

    // TODO: Persist session changes
  }


  @override
  Widget build(BuildContext context) {
    // Show loading indicator until initialization is complete
    // Use a local variable to avoid accessing potentially uninitialized _currentSession
    bool isSessionInitialized = false;
    try {
       // Check if _currentSession is accessible without throwing LateInitializationError
       // This is a bit of a workaround; ideally use a FutureBuilder or similar pattern
       if (_currentSession != null) isSessionInitialized = true;
    } catch (e) {
       isSessionInitialized = false;
    }


    if (_isGenerating && !isSessionInitialized) { // Show loading only during initial load
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // --- Build UI based on whether the chat has started ---
    return Scaffold(
      appBar: AppBar(
        title: Text(isSessionInitialized ? _currentSession.title : "Chat"),
        actions: [
          if (_isGenerating && isSessionInitialized) // Show loading in AppBar
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) {
                _llmService.initialize(); // Re-initialize on return
              });
            },
          ),
        ],
      ),
      body: isSessionInitialized
          ? (_currentSession.nodes.isEmpty
              // --- Show Initial Input View ---
              ? _buildInitialInputView()
              // --- Show Graph View ---
              : ChatGraphWidget(
                  session: _currentSession,
                  selectedNode: _selectedNode,
                  onGenerateChild: _handleGenerateChild,
                  onNodeSelected: _handleNodeSelected,
                  onToggleCollapse: _toggleNodeCollapse, // Pass the toggle callback
                ))
          : const Center(child: Text("Initializing...")),
    );
  }

  // --- Helper to build the initial input view ---
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