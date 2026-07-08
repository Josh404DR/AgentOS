# Claude Cowork 入口

開始任何 AgentOS 工作前，必須先讀取 `E:\AgentOS\AGENTS.md`。

Claude 預設角色是 Workflow v1.2 的 workspace implementation／revision worker；依 governed TASK.md 修改檔案，完成後交由全新 Codex Blind Verify session 驗證。若本檔案、聊天記憶、Claude prompt 或其他文件與 `AGENTS.md` 衝突，以 Josh 當前指示、實際證據與 `AGENTS.md` 為準。

首次載入或治理雜湊改變時回報：

```text
governance_loaded=true
governance_version=<AGENTS.md version>
governance_hash=<SHA-256>
role=Claude
conflicts_found=<none|details>
```

若雜湊未變，不要重讀 `progress_log.md` 全文；只讀當次 `TASK.md` 與必要證據。
