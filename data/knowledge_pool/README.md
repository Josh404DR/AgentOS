# knowledge_pool — 本機知識節點正本

status: active_with_verification_gate
updated_at: 2026-07-20

本目錄是 URL intake 下游的本機 knowledge node 正本。2026-07-20
盤點有 29 個節點（另有本 README），其中 3 個為 `ci-live` 測試節點。
舊節點可能只有 `PASS_WITH_CAVEATS` 或沒有新版 review marker；檔案存在
不等於已完成最新的嚴格驗證。

新節點只有在 Claude review 符合嚴格 `PASS` schema，且相同 RESULT hash
已有 fresh read-only Codex Verify `PASS` receipt 時，才可由 publisher 寫入。
其他情況保留為 task candidate，不得宣稱已發布。

NotebookLM 與 Obsidian 都是可重建投影，不是 source of truth；同步失敗
不得刪除或覆寫本機節點。重複知識保留各自工單節點，以 relation 表示。

Knowledge Workspace Phase 1 提供可重建的本機衍生索引、繁中 trigram 搜尋、
節點詳情與 opaque artifact refs。discussion 與 feedback 寫入
`data\knowledge_discussions\` 的 append-only 隔離儲存，不會修改本目錄正本；
候選匯出只會寫入 `data\knowledge_candidates\`，不會派工、升格或發布。
