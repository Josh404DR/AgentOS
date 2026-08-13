# AgentOS Harness 診斷 v1.0（供後續所有制度檔引用）

governance_parent: E:\AgentOS\AGENTS.md
written_by: Claude Fable 5（一次性 session，2026-07-08）
evidence_basis: GitHub 快照（github.com/Josh404DR/AgentOS），非 live 環境
status: reviewed_by_claude（自審，非獨立盲審）

> 誠實聲明：本診斷來自 repo 靜態證據，未接觸 live E:\AgentOS、live governance_status.json、
> live Claude Code/Cowork 設定（可用 subagent 型別、MCP、model/effort 參數）。
> 標記 [推定] 的項目需在 live 環境用一次快速檢查確認，方法附在各項末尾。

---

## 漏洞 #1（最漏 token）：每個 session 的「開機成本」過高，且無禁讀清單

**證據**
- 入口鏈：`CLAUDE.md` → `AGENTS.md`（6.9KB）→ `current_state.md`（5.6KB）→ `agents/roles/claude.md`
  → `docs/EVIDENCE_AND_REPORTING_CONTRACT.md`（11KB）→ 視任務再讀 routing/contract 文件。
  單是「知道自己是誰、能做什麼」就要 3～5 萬字元。
- 三方協定（Brain/Worker/Planner/Verifier）在至少 5 個檔案各完整寫一遍：
  `AGENTS.md` §2、`README.md`、`docs/ARCHITECTURE.md`、`agents/roles/claude.md`、
  `agents/roles/codex.md`、`agents/roles/hermes.md`。任何一份改了其他就漂移（已實際發生，見漏洞 #2）。
- repo 內有大量「模型絕不該讀」的目錄，但沒有任何文件明說：
  `data/memory/sync_logs/`（30+ 檔）、`exports/obsidian_agentos/`（100+ 檔）、
  `data/routing_decisions/`（50+ 目錄）、`data/escalations/` 歷史項、`assets/github-ready/`（專案副本）。
  模型用 Glob/Grep 掃 repo 時這些全會進 context。

**修法（已落實於本次交付）**
1. `CLAUDE.md` 重寫為精簡路由頁（目標 <2KB），內含「分層載入表」：必讀 / 按需讀 / 禁讀。見新版 `CLAUDE.md`。
2. 硬規則：主對話不得對 repo 全域 Glob/Grep；掃描一律派 subagent 或用 `rg` 限定目錄，
   只回傳「檔案:行號 + 一行摘要」。見 `10_DISPATCH_RULES.md` §2。
3. 三方協定描述收斂：`AGENTS.md` §2 為唯一正本，其餘檔案改為一行引用。
   （本次未直接改 README/ARCHITECTURE——那是治理變更需 Josh 核准；已列入 `40_MAINTENANCE_PROTOCOL.md` 待辦。）

---

## 漏洞 #2（最易失焦）：正本文件互相矛盾，弱模型會隨機選邊

**證據（逐條可查）**
- `agents/roles/claude.md` 說 Claude「**Read-Only by Default**」且職責寫成 review/inspection；
  `AGENTS.md` §2 與 `CLAUDE.md` 說 Claude 是「主要 workspace 實作者」。這是直接衝突。
  同一檔案上半段寫 Worker（implementation），下半段的 Responsibilities 卻整段是舊 Inspector 職責。
- `README.md` 硬編碼 `governance_status: aligned`，而 `current_state.md`（2026-07-05）記錄
  live 狀態是 `review_required, drift_count: 3`。README 不該存活狀態。
- `current_state.md` §3 仍詳述 Antigravity 四帳號串接為「臨時狀態」，但 §7（2026-07-08 稽核後）
  已宣告「Antigravity 凍結」。弱模型讀到 §3 會繼續投入被凍結的方向。
- `docs/INDEX.md` 已標 6 份文件 `planned-not-implemented`，但 `README.md` 的 Source of Truth
  清單仍列 `PRE_FLIGHT_TEST_PLAN.md` 等未實作文件為正本。

**修法**
1. 衝突裁決規則寫死（`20_JUDGMENT_RUBRICS.md` §5）：任何角色/狀態衝突，
   以 `AGENTS.md` §1 證據優先序裁決，且**必須回報 `conflicts_found=<細節>`，不得靜默選邊**。
2. 待 Josh 核准的三個具體修正（列於 `40_MAINTENANCE_PROTOCOL.md` 待辦區）：
   a. `agents/roles/claude.md` 刪除 Read-Only by Default 與舊 Inspector 職責段，改引用 AGENTS.md。
   b. `README.md` 移除硬編碼 governance_status，改指向 `data/governance/governance_status.json`。
   c. `current_state.md` §3 Antigravity 段補一行「2026-07-08 起凍結，見 §7」。
3. 制度面：`current_state.md` 只准四節（Source of Truth／Blockers／Priority／Frozen），
   每節每項必附日期；規範見 `40_MAINTENANCE_PROTOCOL.md` §3。

---

## 漏洞 #3（最易出錯）：主 session 自己下場執行 + 度量迴路是斷的

**證據**
- `progress_log.md` 2026-07-06 段落自己記錄了事故：Claude 主 session 直接讀 `logs\*`
  拿到 stale/空結果，最後靠 Josh 手貼 `type`/`schtasks` 輸出才解決。
  這正是「指揮官下場」的代價：主對話塞滿低價值讀取、又拿到錯誤事實。
- `current_state.md` §1 自己承認：`METRICS_LOG.jsonl` 僅 5 筆且 token/duration 全 `unknown`，
  「不可作為效能依據」。等於路由與 effort 決策沒有任何回饋資料，
  `COST_SAVING_ROUTING_PROTOCOL.md` 的成本表全靠直覺維護。
- 測試 fixture 與真實 escalation 混在同一 `data/escalations/` 目錄
  （`current_state.md` §4 特別警告「不得誤判」）——需要一條人肉警語才能避免誤讀，
  就代表結構本身在製造錯誤。
- 驗證合約（Codex Blind Verify）設計良好，但只涵蓋「工單制」工作；
  Claude 主 session 的日常互動（像 progress_log 那次）完全在合約外，無 read-back、無二驗。

**修法**
1. 「指揮官不下場」成文化：大量讀取／掃描／批次改檔一律委派，主對話只進結論。
   完整規則與降級路徑（Cowork 無 subagent 時怎麼辦）見 `10_DISPATCH_RULES.md`。
2. 度量最低要求：每次委派結束，回報末行附 metrics（格式見 `10_DISPATCH_RULES.md` §5），
   wall_time 一律實測。token 部分：AGENTS.md §4 現行規定「不得捏造估算值」，
   故先只補 wall_time 迴路；「允許明確標記 estimate 的 token 粗估」列為治理變更提案
   （見 40_MAINTENANCE §3），Josh 核准前不生效。
3. fixture 隔離 [推定需 Josh 核准移動檔案]：新 fixture 一律寫入 `tests/fixtures/escalations/`，
   `ESCALATION_INDEX.jsonl` 新增欄位 `is_fixture: true|false`。舊資料不動（治理規定不刪不搬）。

---

## 次要發現（不進前三，但列入維護待辦）

- `docs/temp_routing_rules.txt`：temp 檔活在 docs 正本區，應歸納或標 historical。
- `projects/josh-resume-portfolio-update/` 內多個 `.fuse_hidden*` 殘檔（Linux 掛載殘留），
  是垃圾但刪除需 Josh 核准。
- `exports/obsidian_agentos/視圖節點/` 內有截斷檔名（如 `ation-02-monitoring-platform.md`），
  匯出腳本 `export_obsidian_view_nodes.*` 的檔名裁切邏輯疑似有 bug [推定，可用一個長 ID 測試重現]。

## Live 環境待確認清單（第一個接手 session 花 10 分鐘做完）

confirmed_at: 2026-07-08T16:40 Asia/Taipei
confirmed_by: Claude Cowork（claude-sonnet-4-6），本 session 親自執行

1. **Harness 確認**
   - 環境：Claude **Cowork**（非 Claude Code CLI）
   - 可用 subagent/Task 工具：`mcp__dispatch__start_task` ✅，`Agent` tool ✅
   - 結論：走 `10_DISPATCH_RULES.md` **主路徑**（非降級路徑）
   - 注意：主對話 `SendUserMessage` 有已知 bug（本 session 全程），
     訊息回傳 "delivered" 但 user 看不到；workaround = 派 dispatch 子 session 傳訊

2. **可用 model 清單**
   - claude-opus-4-8（opus）
   - claude-sonnet-4-6（sonnet，當前 session）
   - claude-haiku-4-5-20251001（haiku）
   - 支援 per-agent model 指定：**是**（Agent tool 的 `model` 參數，接受 "sonnet"/"opus"/"haiku"/"fable"）

3. **governance_status.json**（磁碟實測結果，2026-07-09 複查）
   - `governance_status`: **review_required**
   - `governance_version`: 1.2.0
   - `drift_count`: 4
   - `checked_at`: 2026-07-08T14:32:51 +08:00
   - 檔案本身：**29 行、JSON 合法（可完整解析）**，`drift` 陣列 4 筆齊全：
     - `current_state.md`（hash_changed）
     - `dashboard\DASHBOARD_SCOPE.md`（hash_changed）
     - `scripts\hermes_claude_bridge.ps1`（hash_changed）
     - `scripts\hermes_codex_bridge.ps1`（hash_changed）
   - 說明：先前（2026-07-08）版本記錄「本身截斷（20 行，JSON 不完整）」，此為 uncertain
     ——可能為當時檢視工具（PowerShell 主控台或 pipeline）顯示截斷，非檔案本身損毀；
     實際成因已無法回溯。本次 2026-07-09 磁碟實測未重現截斷，不再視為已確認事實。

4. ✅ 已寫回本節，[推定] 改為事實完成；governance_status.json 段於 2026-07-09 依磁碟實測更正。

<!-- v1.0 2026-07-09: 初始版本標記；第一輪驗收修正 核准: Josh -->
