import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';
import '../services/session_repository.dart';

class SessionProvider extends ChangeNotifier {
  final SessionRepository _repo = createDefaultSessionRepository();

  final List<GraphSession> _sessions = [];
  GraphSession? _current;
  Timer? _saveTimer;
  int _graphVersion = 0;

  List<GraphSession> get sessions => List.unmodifiable(_sessions);
  GraphSession? get currentSession => _current;
  int get graphVersion => _graphVersion;

  SessionProvider() {
    // 自動的にロード開始（awaitしない）
    Future.microtask(() => load());
  }

  Future<void> load() async {
    final loaded = await _repo.loadAll();
    _sessions
      ..clear()
      ..addAll(loaded);
    _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (_sessions.isEmpty) {
      final s = GraphSession(title: 'New Chat');
      _sessions.add(s);
    }
    _current = _sessions.first;
    notifyListeners();
  }

  void createNewSession() {
    final newSession = GraphSession(title: 'New Chat');
    _sessions.insert(0, newSession);
    _current = newSession;
    _graphVersion++;
    _scheduleSave();
    notifyListeners();
  }

  void addImportedSession(GraphSession session) {
    // 同一IDセッションがある場合は新しいIDに差し替え
    if (_sessions.any((s) => s.id == session.id)) {
      session = GraphSession(
        title: session.title,
        nodes: session.nodes,
        rootNodeId: session.rootNodeId,
        createdAt: session.createdAt,
        updatedAt: DateTime.now(),
      );
    } else {
      session.updatedAt = DateTime.now();
    }
    _sessions.insert(0, session);
    _current = session;
    unawaited(_repo.upsert(session));
    _scheduleSave();
    notifyListeners();
  }

  void switchSession(String sessionId) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      _current = _sessions[idx];
      notifyListeners();
    }
  }

  void deleteSession(String sessionId) {
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_current?.id == sessionId) {
      if (_sessions.isEmpty) {
        final s = GraphSession(title: 'New Chat');
        _sessions.add(s);
      }
      _current = _sessions.first;
    }
    _graphVersion++;
    // 即時で削除を反映
    unawaited(_repo.delete(sessionId));
    _scheduleSave();
    notifyListeners();
  }

  void updateSessionTitle(String sessionId, String newTitle) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;

    final old = _sessions[index];
    final updated = GraphSession(
      id: old.id,
      title: newTitle,
      nodes: old.nodes,
      rootNodeId: old.rootNodeId,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );

    _sessions[index] = updated;
    if (_current?.id == sessionId) _current = updated;
    _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _scheduleSave();
    notifyListeners();
  }

  ChatNode addRootNode(String userInput) {
    final current = _requireCurrent();
    final node = ChatNode(
      parentId: null,
      userInput: userInput,
      id: current.rootNodeId,
    );
    current.addNode(node);
    _graphVersion++;
    _scheduleSave();
    notifyListeners();
    return node;
  }

  ChatNode addChildNode(ChatNode parent, String userInput) {
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
    _graphVersion++;
    _scheduleSave();
    notifyListeners();
    return node;
  }

  void updateNodeOutput(String nodeId, String output) {
    final current = _requireCurrent();
    final idx = current.nodes.indexWhere((n) => n.id == nodeId);
    if (idx != -1) {
      current.nodes[idx].llmOutput = output;
      current.updatedAt = DateTime.now();
      _scheduleSave();
      notifyListeners();
    }
  }

  void toggleNodeCollapse(String nodeId) {
    final current = _requireCurrent();
    final idx = current.nodes.indexWhere((n) => n.id == nodeId);
    if (idx != -1) {
      current.nodes[idx].isCollapsed = !current.nodes[idx].isCollapsed;
      notifyListeners();
      _graphVersion++;
      _scheduleSave();
    }
  }

  void updateNodePosition(String nodeId, Offset position) {
    final current = _requireCurrent();
    final idx = current.nodes.indexWhere((n) => n.id == nodeId);
    if (idx != -1) {
      current.nodes[idx].position = position;
      notifyListeners();
      _graphVersion++;
      _scheduleSave();
    }
  }

  void scheduleSave() => _scheduleSave();

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    final current = _current;
    if (current != null) {
      await _repo.upsert(current);
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () async {
      final current = _current;
      if (current != null) {
        await _repo.upsert(current);
      }
    });
  }

  GraphSession _requireCurrent() {
    final c = _current;
    if (c == null) {
      throw StateError('No current session loaded');
    }
    return c;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
