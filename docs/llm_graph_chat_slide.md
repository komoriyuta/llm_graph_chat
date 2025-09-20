---
marp: true
size: 16:9
---

<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:24px;">
  <div>
    <h1 style="margin:0;">LLM Graph Chat</h1>
    <p style="margin:4px 0 0; font-size:18px;">LLMとの会話をツリー状に可視化するチャットアプリ</p>
  </div>
  <img src="../web/icons/favicon.svg" style="width:64px; height:64px; box-shadow:0 6px 16px rgba(0,0,0,0.22); border-radius:18px; padding:6px; background:rgba(255,255,255,0.85);" alt="LLM Graph Chat Favicon" />
</div>

<div style="display:flex; gap:32px; align-items:flex-start;">
  <div style="flex:1;">
    <ul style="padding-left:1.1em; font-size:0.95em; line-height:1.5;">
      <li><strong>会話の地図を描く</strong>: ノードごとにユーザー入力とLLM応答を一覧し、枝分かれで思考の幅を可視化</li>
      <li><strong>分岐して深掘り</strong>: 任意ノードから派生質問や再生成が可能で、比較検討やブレインストーミングがしやすい</li>
      <li><strong>Gemini連携 & モデル選択</strong>: 複数Geminiモデルから用途に合わせて選択、設定画面でAPIキーを安全に管理</li>
      <li><strong>Flutterマルチプラットフォーム</strong>: 1つのコードベースでモバイル / デスクトップ / Web へ展開</li>
    </ul>
    <p style="margin-top:18px; font-weight:600;">アイデア整理・探索・チームディスカッションに。</p>
  </div>
  <div style="width:400px; display:flex; flex-direction:column; align-items:center; gap:14px;">
    <img src="../image.png" style="width:100%; border-radius:12px; box-shadow:0 8px 20px rgba(0,0,0,0.18);" alt="アプリのスクリーンショット" />
    <div style="display:flex; gap:12px; justify-content:center;">
      <div style="display:flex; flex-direction:column; align-items:center; gap:6px;">
        <img src="assets/web_demo_qr.png" style="width:100px;" alt="WebデモQRコード" />
        <span style="font-size:12px; font-weight:600;">Webデモ</span>
      </div>
      <div style="display:flex; flex-direction:column; align-items:center; gap:6px;">
        <img src="assets/github_repo_qr.png" style="width:100px;" alt="GitHubリポジトリQRコード" />
        <span style="font-size:12px; font-weight:600;">GitHub</span>
      </div>
    </div>
  </div>
</div>
