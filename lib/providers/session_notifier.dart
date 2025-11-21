import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';
import '../services/session_repository.dart';
import '../services/llm_service.dart';
import '../services/secure_storage_service.dart';
import 'session_state.dart';

part 'session_notifier.g.dart';

@riverpod
class SessionNotifier extends _$SessionNotifier {
  late final SessionRepository _repo;
  late final LlmService _llmService;
  Timer? _saveTimer;

  @override
  SessionState build() {
    _repo = createDefaultSessionRepository();
    _llmService = LlmService(SecureStorageService());
    _initializeLlm();
    
    // Load sessions asynchronously
    Future.microtask(() => load());
    return const SessionState(isLoading: true);
  }

  Future<void> _initializeLlm() async {
    await _llmService.initialize();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final loaded = await _repo.loadAll();
    loaded.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    
    List<GraphSession> sessions = [...loaded];
    GraphSession? current;

    if (sessions.isEmpty) {
      final s = GraphSession(title: 'New Chat');
      sessions.add(s);
    }
    current = sessions.first;

    state = state.copyWith(
      sessions: sessions,
      currentSession: current,
      isLoading: false,
    );
  }

  void createNewSession() {
    final newSession = GraphSession(title: 'New Chat');
    final newSessions = [newSession, ...state.sessions];
    
    state = state.copyWith(
      sessions: newSessions,
      currentSession: newSession,
      graphVersion: state.graphVersion + 1,
    );
    _scheduleSave();
  }

  void addImportedSession(GraphSession session) {
    var newSession = session;
    // Check for duplicate ID
    if (state.sessions.any((s) => s.id == session.id)) {
      newSession = GraphSession(
        title: session.title,
        nodes: session.nodes,
        rootNodeId: session.rootNodeId,
        createdAt: session.createdAt,
        updatedAt: DateTime.now(),
      );
    } else {
      newSession.updatedAt = DateTime.now();
    }

    final newSessions = [newSession, ...state.sessions];
    state = state.copyWith(
      sessions: newSessions,
      currentSession: newSession,
    );
    
    unawaited(_repo.upsert(newSession));
    _scheduleSave();
  }

  void switchSession(String sessionId) {
    final session = state.sessions.firstWhere((s) => s.id == sessionId, orElse: () => state.sessions.first);
    state = state.copyWith(currentSession: session);
  }

  void deleteSession(String sessionId) {
    final newSessions = state.sessions.where((s) => s.id != sessionId).toList();
    GraphSession? newCurrent = state.currentSession;

    if (state.currentSession?.id == sessionId) {
      if (newSessions.isEmpty) {
        final s = GraphSession(title: 'New Chat');
        newSessions.add(s);
      }
      newCurrent = newSessions.first;
    }

    state = state.copyWith(
      sessions: newSessions,
      currentSession: newCurrent,
      graphVersion: state.graphVersion + 1,
    );

    unawaited(_repo.delete(sessionId));
    _scheduleSave();
  }

  void updateSessionTitle(String sessionId, String newTitle) {
    final index = state.sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;

    final old = state.sessions[index];
    final updated = GraphSession(
      id: old.id,
      title: newTitle,
      nodes: old.nodes,
      rootNodeId: old.rootNodeId,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );

    final newSessions = [...state.sessions];
    newSessions[index] = updated;
    newSessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    GraphSession? newCurrent = state.currentSession;
    if (state.currentSession?.id == sessionId) {
      newCurrent = updated;
    }

    state = state.copyWith(
      sessions: newSessions,
      currentSession: newCurrent,
    );
    _scheduleSave();
  }

  Future<ChatNode> addRootNode(String userInput) async {
    final current = _requireCurrent();
    final node = ChatNode(
      parentId: null,
      userInput: userInput,
      id: current.rootNodeId,
    );
    current.addNode(node);
    
    state = state.copyWith(graphVersion: state.graphVersion + 1);
    _scheduleSave();

    // Generate LLM response
    final llmResponse = await _llmService.generateResponse(current, node);
    updateNodeOutput(node.id, llmResponse);
    
    return node;
  }

  Future<ChatNode> addChildNode(ChatNode parent, String userInput) async {
    final current = _requireCurrent();
    final node = ChatNode(
      parentId: parent.id,
      userInput: userInput,
      position: parent.position + const Offset(0, 200),
    );
    current.addNode(node);
    final parentIdx = current.nodes.indexWhere((n) => n.id == parent.id);
    if (parentIdx != -1) {
      current.nodes[parentIdx].childrenIds.add(node.id);
    }

    state = state.copyWith(graphVersion: state.graphVersion + 1);
    _scheduleSave();

    // Generate LLM response
    final llmResponse = await _llmService.generateResponse(current, node);
    updateNodeOutput(node.id, llmResponse);

    return node;
  }

  Future<void> regenerateNode(ChatNode node) async {
    final current = _requireCurrent();
    final llmResponse = await _llmService.generateResponse(current, node);
    updateNodeOutput(node.id, llmResponse);
  }

  void updateNodeOutput(String nodeId, String output) {
    final current = _requireCurrent();
    final idx = current.nodes.indexWhere((n) => n.id == nodeId);
    if (idx != -1) {
      current.nodes[idx].llmOutput = output;
      current.updatedAt = DateTime.now();
      _scheduleSave();
      state = state.copyWith(); 
    }
  }

  void toggleNodeCollapse(String nodeId) {
    final current = _requireCurrent();
    final idx = current.nodes.indexWhere((n) => n.id == nodeId);
    if (idx != -1) {
      current.nodes[idx].isCollapsed = !current.nodes[idx].isCollapsed;
      state = state.copyWith(graphVersion: state.graphVersion + 1);
      _scheduleSave();
    }
  }

  void updateNodePosition(String nodeId, Offset position) {
    final current = _requireCurrent();
    final idx = current.nodes.indexWhere((n) => n.id == nodeId);
    if (idx != -1) {
      current.nodes[idx].position = position;
      state = state.copyWith(graphVersion: state.graphVersion + 1);
      _scheduleSave();
    }
  }

  void scheduleSave() => _scheduleSave();

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    final current = state.currentSession;
    if (current != null) {
      await _repo.upsert(current);
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () async {
      final current = state.currentSession;
      if (current != null) {
        await _repo.upsert(current);
      }
    });
  }

  GraphSession _requireCurrent() {
    final c = state.currentSession;
    if (c == null) {
      throw StateError('No current session loaded');
    }
    return c;
  }
}
