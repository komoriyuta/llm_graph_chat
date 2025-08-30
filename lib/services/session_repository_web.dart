import 'dart:async';
import '../models/graph_session.dart';
import '../models/session_list.dart';
import 'session_repository_base.dart';
import 'local_storage_service.dart';

class WebPrefsSessionRepository implements SessionRepository {
  final _prefs = LocalStorageService();

  @override
  Future<void> delete(String sessionId) async {
    await _prefs.deleteSession(sessionId);
  }

  @override
  Future<List<GraphSession>> loadAll() async {
    return _prefs.loadSessions();
  }

  @override
  Future<void> upsert(GraphSession session) async {
    // 既存の全件を読み出し、対象のみ差し替えて書き戻す。
    final list = await _prefs.loadSessions();
    final idx = list.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      list[idx] = session;
    } else {
      list.add(session);
    }
    await _prefs.writeSessions(list);
  }
}

SessionRepository createRepository() => WebPrefsSessionRepository();
