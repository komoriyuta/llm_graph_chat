# LLM Graph Chat アプリケーション開発計画

## 1. 目的

Flutterを使用して、LLM（初期はGoogle Gemini）とのチャット履歴をインタラクティブなグラフ構造で表現するアプリケーションを開発する。

*   チャットの各ターンがグラフ上のノードに対応する。
*   ノード上で直接ユーザー入力とLLM応答の表示を行う。
*   ノードは分岐（複数の子ノードを持つこと）が可能。
*   すべてのグラフ構造とチャット履歴は、セッションごとにJSONファイルとして永続化する。
*   LLMのAPIキーは `flutter_secure_storage` を使用して安全に保存する。

## 2. 依存関係 (`pubspec.yaml`)

### dependencies:
*   `google_generative_ai`: Google Gemini APIクライアント。
*   `flutter_secure_storage`: APIキーの安全な保存。
*   `graphview`: グラフ構造の描画。
*   `path_provider`: アプリケーションのファイル保存ディレクトリへのアクセス。
*   `uuid`: ノードやセッションの一意なID生成。
*   `json_annotation`: JSONシリアライズのためのアノテーション。

### dev_dependencies:
*   `build_runner`: コード生成ツール（`json_serializable` など）。
*   `json_serializable`: DartオブジェクトとJSON間の変換コードを自動生成。

**設定:**
*   `flutter pub get` を実行して依存関係をインストール。
*   `flutter pub run build_runner build --delete-conflicting-outputs` を実行してJSONシリアライズ用のコードを生成。
*   `flutter_secure_storage` のためのネイティブ設定（Android/iOS）を確認（通常は不要）。

## 3. データモデル (`lib/models/`)

`json_serializable` を使用してJSON変換を容易にする。

*   **`ChatNode` (`chat_node.dart`)**:
    *   `id`: `String` (UUID v4) - ノードの一意なID。
    *   `parentId`: `String?` - 親ノードのID (ルートノードは null)。
    *   `userInput`: `String` - このノードでのユーザー入力。
    *   `llmOutput`: `String` - このノードでのLLM応答 (初期は空、後で更新)。
    *   `childrenIds`: `List<String>` - 子ノードのIDリスト。
    *   `timestamp`: `DateTime` - ノード作成日時。
    *   `fromJson`, `toJson` ファクトリ/メソッド。

*   **`GraphSession` (`graph_session.dart`)**:
    *   `sessionId`: `String` (UUID v4) - セッションの一意なID。
    *   `createdAt`: `DateTime` - セッション作成日時。
    *   `nodes`: `List<ChatNode>` - セッションに含まれるすべてのノードのリスト。
    *   `fromJson`, `toJson` ファクトリ/メソッド (`explicitToJson: true` を指定)。

## 4. ファイル管理 (`lib/services/file_service.dart`)

*   **`FileService` クラス**:
    *   `getApplicationDocumentsDirectory()` (`path_provider`) を使用して保存先ディレクトリを取得。
    *   `Future<String> createNewSession()`: 新しい `GraphSession` を作成し、`session_yyyymmdd_hhmmss.json` という形式のファイル名でJSONとして保存。保存したファイルパスを返す。
    *   `Future<List<String>> listSessionFiles()`: 保存ディレクトリ内の `.json` ファイルのリスト（ファイルパス）を返す。
    *   `Future<GraphSession> loadSession(String filePath)`: 指定されたファイルパスからJSONを読み込み、`GraphSession` オブジェクトを返す。
    *   `Future<void> saveSession(GraphSession session, String filePath)`: 与えられた `GraphSession` オブジェクトをJSONに変換し、指定されたファイルパスに上書き保存する。

## 5. API連携 (`lib/services/`)

*   **`GeminiService` (`gemini_service.dart`)**:
    *   APIキーを引数に取るコンストラクタ。
    *   `Future<String> getResponse(List<Map<String, String>> history, String prompt)`: チャット履歴と新しいプロンプトを受け取り、Gemini APIにリクエストを送信し、応答テキストを返す。履歴の形式はGemini APIの要件に合わせる。
*   **`SecureStorageService` (`secure_storage_service.dart`)**:
    *   `Future<void> saveApiKey(String apiKey)`: APIキーを `flutter_secure_storage` に保存。
    *   `Future<String?> loadApiKey()`: APIキーを `flutter_secure_storage` から読み込み。

## 6. UI実装 (`lib/screens/` & `lib/widgets/`)

*   **APIキー入力画面 (`api_key_screen.dart`)**:
    *   アプリ初回起動時やAPIキーが未設定の場合に表示。
    *   `TextField` でAPIキーを入力し、`SecureStorageService` を使って保存。
*   **セッション選択/開始画面 (`session_list_screen.dart`)**:
    *   アプリ起動時に表示（APIキー設定後）。
    *   `FileService.listSessionFiles` で既存のセッションファイル一覧を表示 (`ListView`)。
    *   「新規セッション」ボタン: `FileService.createNewSession` を呼び出し、返されたファイルパスをメイン画面に渡して遷移。
    *   既存ファイルを選択: 選択したファイルパスをメイン画面に渡して遷移。
*   **メイン画面 (`main_screen.dart`)**:
    *   `StatefulWidget` として実装。
    *   コンストラクタでセッションファイルパス (`sessionFilePath`) を受け取る。
    *   状態変数 `late GraphSession _currentSession;` を持つ。
    *   `initState()`: `FileService.loadSession(widget.sessionFilePath)` を呼び出し、結果を `_currentSession` にセットして `setState`。
    *   `build()`:
        *   `AppBar` など基本レイアウト。
        *   `_currentSession` が初期化されるまでローディング表示。
        *   `GraphWidget` を表示。
*   **グラフ表示Widget (`graph_widget.dart`)**:
    *   `graphview` パッケージを使用。
    *   `_currentSession.nodes` から `Graph` オブジェクトを構築。
    *   `SugiyamaConfiguration` などでレイアウトを設定。
    *   各ノードの描画には `ChatNodeWidget` を使用。
*   **ノードWidget (`chat_node_widget.dart`)**:
    *   `ChatNode` データを受け取る。
    *   `TextField` (ユーザー入力用、`userInput` が空の場合のみ表示/編集可能？)。
    *   `Text` (LLM応答表示用、`llmOutput`)。
    *   入力完了時のコールバック (`onSubmitted`)。
    *   分岐ボタン（タップなどで発火）。

## 7. 処理フロー

```mermaid
graph TD
    A[アプリ起動] --> B{APIキー確認};
    B -- 未設定 --> C[APIキー入力画面];
    C -- 入力完了 --> D[APIキー保存];
    B -- 設定済み --> E[APIキー読み込み];
    D --> E;
    E --> F[セッション選択/開始画面];
    F -- 新規セッション --> G[FileService.createNewSession];
    F -- 既存セッション選択 --> H[FileService.listSessionFiles];
    H --> I[ファイル選択];
    G --> J[メイン画面へ (ファイルパス渡し)];
    I -- 選択 --> J;

    subgraph メイン画面 (StatefulWidget)
        K[initState: FileService.loadSession(filePath)] --> L[GraphSessionデータを状態(_currentSession)に保持];
        L --> M[グラフ描画 (graphview, _currentSession.nodes)];
        N(ChatNodeWidget) -- 入力 --> O{入力完了};
        O -- 送信 --> P[新しいChatNode作成];
        P --> Q[_currentSession.nodesに追加];
        Q --> R[setState()でUI更新];
        R --> S(非同期処理);
        S -- ファイル保存 --> T[FileService.saveSession(_currentSession, filePath)];
        S -- API呼び出し --> U[GeminiService呼び出し (履歴抽出)];
        U --> V[LLM応答取得];
        V --> W[対応するChatNodeのllmOutput更新];
        W --> X[setState()でUI更新];
        X --> Y(非同期処理);
        Y -- ファイル保存 --> Z[FileService.saveSession(_currentSession, filePath)];

        N -- 分岐ボタン --> AA[新しい空のChatNode作成];
        AA --> BB[_currentSession.nodesに追加];
        BB --> CC[setState()でUI更新];
        CC --> DD(非同期処理);
        DD -- ファイル保存 --> EE[FileService.saveSession(_currentSession, filePath)];
    end
```

## 8. 次のステップ

*   この計画に基づき、`code` モードに切り替えて実装を開始する。