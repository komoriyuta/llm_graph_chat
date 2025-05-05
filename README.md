# LLM Graph Chat

FlutterベースのLLMチャットアプリケーションで、チャット履歴をグラフ構造で可視化します。

## プロジェクト構造

### モデル（`lib/models/`）

#### ChatNode (`chat_node.dart`)
チャットの各ノードを表現するクラス
- プロパティ:
  - `id`: UUID形式の一意識別子
  - `parentId`: 親ノードのID（ルートノードはnull）
  - `userInput`: ユーザーの入力テキスト
  - `llmOutput`: LLMからの応答テキスト
  - `childrenIds`: 子ノードIDのリスト
  - `timestamp`: ノード作成日時
  - `isCollapsed`: ノードの折りたたみ状態
- JSON変換機能（json_serializable使用）

### 画面（`lib/screens/`）

#### ChatScreen (`chat_screen.dart`)
アプリのメイン画面
- 主要な機能:
  - `_startChat()`: 最初のルートノード作成
  - `_handleGenerateChild()`: 子ノード生成
  - `_toggleNodeCollapse()`: ノードの折りたたみ制御
  - `_handleNodeSelected()`: ノード選択処理
- 状態管理:
  - `_currentSession`: 現在のグラフセッション
  - `_selectedNode`: 選択中のノード
  - `_isGenerating`: LLM応答生成中フラグ

### ウィジェット（`lib/widgets/`）

#### ChatGraphWidget (`chat_graph.dart`)
グラフ表示を担当する2つの主要クラス:

##### EdgePainter
```dart
class EdgePainter extends CustomPainter {
  // ノード間の接続線を描画
  // ベジェ曲線で親ノードの下端から子ノードの上端へ
}
```

##### ChatGraphWidget
```dart
class ChatGraphWidget extends StatefulWidget {
  // プロパティ:
  - session: グラフセッション
  - onGenerateChild: 子ノード生成コールバック
  - onNodeSelected: ノード選択コールバック
  - onToggleCollapse: 折りたたみ切り替えコールバック
  
  // 主要な機能:
  - ノードの自由な配置（Draggable）
  - カスタムエッジ描画（EdgePainter）
  - ノード内のテキスト入力UI
  - ズーム・パン操作（InteractiveViewer）
}
```

## 特徴的な実装

1. `Stack`と`CustomPaint`を使用したカスタムグラフ描画
2. ベジェ曲線による美しい接続線
3. ドラッグ＆ドロップによる自由なノード配置
4. ノードの折りたたみ機能
5. 直感的なズーム・パン操作

このアプリケーションは、チャットの履歴をグラフ構造で可視化し、各ノードで対話を分岐させることができる独特なUIを実現しています。

## 依存パッケージ

- `google_generative_ai`: Gemini APIクライアント
- `flutter_secure_storage`: APIキー安全保存
- `path_provider`: ファイル保存ディレクトリ取得
- `uuid`: ノードIDの生成
- `json_annotation`: JSONシリアライズ支援

## 開発用パッケージ

- `build_runner`: コード生成
- `json_serializable`: JSON変換コード自動生成

## セットアップ

1. 依存関係のインストール:
```bash
flutter pub get
```

2. コード生成の実行:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

3. Gemini APIキーの設定:
アプリ起動時に設定画面でAPIキーを入力

4. アプリの実行:
```bash
flutter run
