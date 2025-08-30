import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/graph_session.dart';
import '../models/session_list.dart';

class LocalStorageService {
  static const String _sessionsKey = 'chat_sessions';
  static const String _darkModeKey = 'dark_mode';
  static const String _nodeWidthKey = 'node_width';
  static const String _nodeHeightKey = 'node_height';

  static const double defaultNodeWidth = 300.0;
  static const double defaultNodeHeight = 200.0;
  
  // セッションの保存
  Future<void> saveSession(GraphSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await loadSessions();
    
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }
    
    final sessionList = SessionList(sessions: sessions);
    await prefs.setString(_sessionsKey, jsonEncode(sessionList.toJson()));
  }
  
  // 全セッションの読み込み
  Future<List<GraphSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_sessionsKey);
    
    if (jsonStr == null) {
      return [];
    }
    
    try {
      final json = jsonDecode(jsonStr);
      final sessionList = SessionList.fromJson(json);
      return sessionList.sessions;
    } catch (e) {
      print('Error loading sessions: $e');
      return [];
    }
  }

  // 全セッション一括保存（状態管理側からのバルク書き込み用）
  Future<void> writeSessions(List<GraphSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionList = SessionList(sessions: sessions);
    await prefs.setString(_sessionsKey, jsonEncode(sessionList.toJson()));
  }
  
  // セッションの削除
  Future<void> deleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await loadSessions();
    
    sessions.removeWhere((s) => s.id == sessionId);
    
    final sessionList = SessionList(sessions: sessions);
    await prefs.setString(_sessionsKey, jsonEncode(sessionList.toJson()));
  }
  
  // セッションの更新
  Future<void> updateSession(GraphSession session) async {
    await saveSession(session);
  }
  
  // 全セッションのクリア
  Future<void> clearSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionsKey);
  }

  // ダークモード設定の保存
  Future<void> setDarkMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDarkMode);
  }

  // ダークモード設定の読み込み
  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  // ノードの幅設定の保存
  Future<void> setNodeWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_nodeWidthKey, width);
  }

  // ノードの幅設定の読み込み
  Future<double> getNodeWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_nodeWidthKey) ?? defaultNodeWidth;
  }

  // ノードの高さ設定の保存
  Future<void> setNodeHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_nodeHeightKey, height);
  }

  // ノードの高さ設定の読み込み
  Future<double> getNodeHeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_nodeHeightKey) ?? defaultNodeHeight;
  }
}
