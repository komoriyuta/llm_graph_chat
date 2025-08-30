import '../models/graph_session.dart';

abstract class SessionRepository {
  Future<List<GraphSession>> loadAll();
  Future<void> upsert(GraphSession session);
  Future<void> delete(String sessionId);
}

