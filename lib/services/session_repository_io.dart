import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/graph_session.dart';
import 'session_repository_base.dart';

class FileSessionRepository implements SessionRepository {
  Future<Directory> _baseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final sessionsDir = Directory('${dir.path}/sessions');
    if (!await sessionsDir.exists()) {
      await sessionsDir.create(recursive: true);
    }
    return sessionsDir;
  }

  Future<File> _fileFor(String id) async {
    final base = await _baseDir();
    return File('${base.path}/$id.json');
  }

  @override
  Future<void> delete(String sessionId) async {
    final f = await _fileFor(sessionId);
    if (await f.exists()) {
      try { await f.delete(); } catch (_) {}
    }
  }

  @override
  Future<List<GraphSession>> loadAll() async {
    final base = await _baseDir();
    final list = <GraphSession>[];
    await for (final ent in base.list()) {
      if (ent is File && ent.path.endsWith('.json')) {
        try {
          final txt = await ent.readAsString();
          final json = await compute<Map<String, dynamic>, Map<String, dynamic>>(
            _decodeJsonMap,
            {'txt': txt},
          );
          list.add(GraphSession.fromJson(json));
        } catch (_) {
          // skip corrupted
        }
      }
    }
    // updatedAt desc
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<void> upsert(GraphSession session) async {
    final f = await _fileFor(session.id);
    final txt = await compute<Map<String, dynamic>, String>(
      _encodeJsonMap,
      session.toJson(),
    );
    await f.writeAsString(txt);
  }
}

SessionRepository createRepository() => FileSessionRepository();

// Top-level helpers for compute
Map<String, dynamic> _decodeJsonMap(Map<String, dynamic> payload) {
  final txt = payload['txt'] as String;
  return jsonDecode(txt) as Map<String, dynamic>;
}

String _encodeJsonMap(Map<String, dynamic> json) {
  return jsonEncode(json);
}
