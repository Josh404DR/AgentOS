# Task Template: CODEX_BUILD (v2, 2026-07-29)

governance_parent: E:\AgentOS\AGENTS.md
依據：2026-07-29 一連串 Claude↔Codex 協作（Pillar B/C、Antigravity CLI 修復、
round-cap 重放漏洞、Queue reparenting 缺陷與效能退化、Evidence Contract 分級）
反覆驗證有效的結構，把它固定下來，之後每次委派不用重新從零手寫。
v1 只有骨架（Goal/Scope/Acceptance/Constraints/Output），這版補上「背景與根因」
「誠實揭露限制」「與既有工單的連結」「明確不做」「逐案測試矩陣」——這些欄位是
這幾天真正抓到 bug、避免自我美化、避免範圍污染的關鍵，不是形式。

[ROLE_HEADER]
Use `prompts/role_headers/codex_builder.md`.

---

## 工單 Frontmatter（每次填空，直接放進 TASK.md）

```yaml
dispatch_id: <日期-描述性slug，例如2026-07-29-xxx-fix>
parent_dispatch_id: <有母票才填，否則 none>
related_dispatch_id: <關聯但非母子關係的其他工單，用於「連結」，否則 none>
type: BUILDER_TASK
assigned_to: Codex Builder
route_to: Codex
codex_mode: build|plan
task_kind: workspace_change|read_only|...
task_type: Simple|Complex
task_status: ready
dispatch_status: ready_to_route
requires_josh_approval: true|false
approval: <Josh 何時、在哪個對話、核准了什麼精確範圍——不得只寫"已核准">
source: <這張工單是從哪個發現/稽核/事故產生的，沒有就 none>
governance_version: <目前 AGENTS.md 版本>
governance_hash: <目前 AGENTS.md SHA-256>
```

`related_dispatch_id`／`source` 這兩欄就是 Josh 要的「連結」：任何工單只要是
延伸自另一張工單的發現（缺陷、退化、後續修正），都要讓 Codex 一眼看到脈絡，
不用回頭問「這是為什麼要做」。

---

## [TASK]

### 任務目標
一句話講清楚要改什麼、為什麼。

### 本任務只允許修改
明確列出檔案清單。沒列到的檔案，Codex 發現「好像也該順手改」時要停手回報，
不能先斬後奏。

### 背景與根因（有實測證據時必填，不是憑印象）
- 這個問題是怎麼被發現的（哪張工單、哪次 Verify FAIL、哪個 benchmark 數字）。
- 根本原因：指到函式名稱、行號、具體邏輯缺陷，不要只描述症狀。
- 如果是接續前一張工單的修正，簡述前一張改了什麼、留下什麼沒解決。

### 已核准決策
逐項列出這次工單被核准要做的事，每項給足夠細節讓 Codex 不用回頭猜測意圖
（可包含具體程式碼片段、資料結構、欄位定義）。

### 誠實揭露：委派者自己驗證不到的部分
如果是 Claude 先做了部分修改才交給 Codex，明確寫出「我自己驗證不了什麼」
（例如沒有 PowerShell 執行環境、無法跑 benchmark、無法確認 git 歷史）。這一段
不是免責聲明，是明確告訴 Codex 這次驗證的重點應該放在哪裡。

### 與既有工單／escalation 的關係
列出這張工單跟其他工單、Dashboard escalation 的關聯，以及「這張工單完成後，
其他工單或 escalation 要不要連動更新狀態」——這個判斷通常留給 Josh 決定，
本工單只負責把關聯講清楚，不要自己代為關閉別的 escalation。

### 明確不做
逐條列出容易被誤會成「順便做一下」但其實不在範圍內的事。這是防止範圍污染
最有效的一段，不能省略。

---

## Acceptance Criteria
逐條列號、可機械檢查（能對應到具體指令、測試檔或輸出格式）。

## 測試要求
如果有明確的案例矩陣（例如不同輸入組合各自的預期行為），逐條列出，不要只寫
「請充分測試」。至少要涵蓋：正常情況、邊界情況（空值/衝突值/舊格式相容）、
會不會在異常輸入下 crash。

## 完成條件（完成後必須輸出，不得只回覆「已完成」）
1. 修改摘要。
2. 修改檔案清單。
3. 關鍵邏輯/判斷流程說明。
4. 所有測試案例與實測結果（不是預期結果）。
5. 尚存限制／已知不完美之處。
6. git diff（或 scoped diff）。
7. commit hash；若未 commit，明確填寫 `not_created`。
8. 完整 Evidence Block（依 `docs\EVIDENCE_AND_REPORTING_CONTRACT.md` 第3節
   分級規則：workspace/production變更用 full 16欄；純讀取查證用 lightweight
   7欄，且 `evidence_sources`／`verification_summary` 要指出具體查了什麼）。

## Constraints
- 遵守 AGENTS.md 目前版本；不捏造；實作者不自驗。
- 不得刪除既有歷史/證據，即使證據顯示自己這次的結果不理想（例如效能退化、
  測試失敗），也要如實記錄，不得刪除或美化成看起來更好的數字。
- 不得修改本工單 impact_scope 之外的檔案。
- 完成後必須交由另一個全新、獨立、read-only 的 Codex Verify session 驗證，
  不得自行宣稱最終 PASS。
