# LocalStorage タブ機能実装計画

## 1. データ構造

### SessionList モデル
```dart
@JsonSerializable()
class SessionList {
  final String id;
  final List<GraphSession> sessions;
  
  SessionList({
    required this.id,
    required this.sessions,
  });

  factory SessionList.fromJson(Map<String, dynamic> json) => _$SessionListFromJson(json);
  Map<String, dynamic> toJson() => _$SessionListToJson(this);
}
```

### GraphSession モデルの拡張
```dart
@JsonSerializable()
class GraphSession {
  String title;
  DateTime lastModified;  // 新規追加
  List<ChatNode> nodes;
  
  // 既存のフィールドはそのまま維持
}
```

## 2. Storage Serviceの実装

### LocalStorageService
```dart
class LocalStorageService {
  static const String _sessionsKey = 'chat_sessions';
  
  // セッションの保存
  Future<void> saveSession(GraphSession session) async {
    final sessions = await loadSessions();
    final index = sessions.indexWhere((s) => s.id == session.id);
    
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }
    
    await _saveSessions(sessions);
  }
  
  // 全セッションの読み込み
  Future<List<GraphSession>> loadSessions() async {
    final json = await _load();
    return SessionList.fromJson(json).sessions;
  }
  
  // セッションの削除
  Future<void> deleteSession(String sessionId) async {
    final sessions = await loadSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    await _saveSessions(sessions);
  }
}
```

## 3. UI実装

### SessionDrawer Widget
- セッションのリスト表示
- 新規セッション作成ボタン
- 各セッションの編集・削除機能

### 自動保存のタイミング
以下のタイミングで`LocalStorageService.saveSession()`を呼び出す：
1. 新規チャット作成時
2. メッセージ送信時
3. LLM応答受信時
4. アプリ終了時（dispose時）

## 4. 状態管理

### ChatScreenでの実装
```dart
class _ChatScreenState extends State<ChatScreen> {
  late LocalStorageService _storageService;
  late GraphSession _currentSession;
  List<GraphSession> _allSessions = [];
  
  @override
  void initState() {
    super.initState();
    _storageService = LocalStorageService();
    _loadSessions();
  }
  
  Future<void> _loadSessions() async {
    final sessions = await _storageService.loadSessions();
    setState(() {
      _allSessions = sessions;
      _currentSession = sessions.isNotEmpty ? sessions.first : GraphSession(title: 'New Chat');
    });
  }
  
  // セッション切り替え
  void _switchSession(GraphSession session) {
    setState(() => _currentSession = session);
  }
  
  // 自動保存
  Future<void> _autoSave() async {
    _currentSession.lastModified = DateTime.now();
    await _storageService.saveSession(_currentSession);
  }
}
```

## 5. 次のステップ

1. SessionListモデルの作成とコード生成
2. LocalStorageServiceの実装
3. UI コンポーネントの実装
4. 自動保存機能の統合
5. テスト実装

コードモードに切り替えて実装を開始する。