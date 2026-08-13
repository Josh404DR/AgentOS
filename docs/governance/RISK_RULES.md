# AgentOS Risk Rules

governance_parent: E:\AgentOS\AGENTS.md
governance_version: 1.3.0
owner: Josh

本檔案只補充 Risky Task 的確定性判斷，不得覆寫 `AGENTS.md`。

符合任一條件即為 `Risky`：

- production database 寫入、修改或刪除；
- 刪除檔案、資料、紀錄、證據或歷史 artifact；
- 金流、付款、帳單、訂閱或自動加值；
- API key、token、憑證、密碼、OAuth 或權限設定；
- 對外部 API、客戶、平台或第三方系統執行寫入；
- production 部署、公開發佈或切換正式流量；
- 修改安全規則、allowlist、blocklist 或存取控制；
- 大量重構核心 Dispatcher、Queue、Gateway 或治理流程，且超出已核准工單的精確檔案／驗收範圍；
- 可能造成服務中斷、資料遺失或不可逆影響；
- 需求不清楚且影響範圍大。

Risky Task 必須：

1. 在任何模型、worker 或外部服務呼叫前停止。
2. 建立 escalation artifact。
3. 等待 Josh 對精確範圍明確核准。
4. 保留原始風險命中紀錄；核准不得以清除 risky 欄位表示。

已由 Josh 對精確目標、檔案範圍、禁止事項與驗收條件明確核准的治理修正，不因包含 Dispatcher／Queue 字樣而重複升級；新增刪除、外部行動、憑證、production或不可逆影響時仍須重新核准。
