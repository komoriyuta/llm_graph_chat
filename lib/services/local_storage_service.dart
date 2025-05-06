import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/graph_session.dart';
import '../models/session_list.dart';

class LocalStorageService {
  static const String _sessionsKey = 'chat_sessions';
  static const String _darkModeKey = 'dark_mode';
  
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
}