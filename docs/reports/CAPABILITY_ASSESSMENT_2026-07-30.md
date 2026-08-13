# AgentOS 五項能力規格化分析（2026-07-30）

作者：Claude（基於實掃 `E:\AgentOS\` repo 內容，非對話記憶）
方法：委派唯讀調查 agent 全面掃描 + Claude 抽查關鍵檔案核實
範圍限制：`E:\AI_Projects_Hub\`（hermes-agent 本體）不在本次可讀範圍，
涉及 Hermes 內部的部分標註「需另查」。

## 總表

| # | 能力 | 判定 | 一句話 |
|---|---|---|---|
| 1 | 知識學習（Telegram→評估→實作） | 🟡 部分 | URL→知識節點全通，「知識→實作工單」最後一哩要人工 |
| 2 | 從錯誤學經驗 | 🟡 部分 | 自動偵測重複失敗+產生候選+升級；「教訓→行為改變」要Josh核准後人工開票 |
| 3 | 決策路徑自動化 | 🟡 有（自動擋，非自動決） | 非Risky全自動流過；所有Risky 100%升Josh，無分級自動核准 |
| 4 | 自主運作 | 🟢 部分偏高 | Telegram→工單→headless Codex CLI執行整條不需人；剩escalation決策與桌面板遺留 |
| 5 | Telegram全遠端維運 | 🟡 大部分有 | 收工單/URL/核准都能；不能pause/resume/retry；owner確認碼機制啟用狀態unknown |

## 1. 知識學習能力 — 🟡 部分

現有機制（檔案級證據）：
- `docs\decisions\ADR-0008-url-intake-knowledge-pipeline.md`：正式管線
  Telegram丟URL → `scripts\fetch_url_source.py`/`threads_url_intake.ps1`
  抓源（untrusted隔離）→ Codex摘要 → Claude review →
  `data\knowledge_pool\` 知識節點 → NotebookLM/Obsidian同步。
  有2026-07-30實跑證據（`data\url_intake\`的PIPELINE.log與對應工單）。
- `dashboard\backend\knowledge_workspace.py`：`KnowledgeIndex` 索引
  `data\codex_tasks\`（7種artifact）+ `data\knowledge_pool\`，
  SQLite+FTS5繁中trigram搜尋，每300秒reconcile。
- 半成品：`/api/v1/knowledge/{id}/candidate` 匯出候選到
  `data\knowledge_candidates\*.json`，狀態止於`candidate_only`——
  README明言「不會派工、升格或發布」。

缺口：
1. 「候選→實作工單」沒有自動化；candidate落盤後需人工開票。
2. 入口只吃URL；純文字Telegram訊息（例如你轉貼的一段觀點）不走知識管線。

## 2. 從錯誤學經驗 — 🟡 部分

現有機制：
- `docs\PROJECT_FINDINGS_REGISTRY.md`：唯一問題登記表（狀態機
  open/ticketed/fixed_verified/stale_needs_recheck），人工回填。
- `docs\claude_ops\40_MAINTENANCE_PROTOCOL.md` + `50_LESSONS.md`：
  教訓append-only落盤，「制度化」須Josh核准。
- 唯一自動機制：`scripts\collect_learning_candidates.ps1`（確定性腳本，
  不呼叫模型）——掃`METRICS_LOG.jsonl`+`ESCALATION_INDEX.jsonl`，
  同一fail_reason達2次即產生`data\learning_candidates\LC-*.json`附
  確定性建議，並自動升escalation給Josh。

缺口：自動的只到「偵測+建議+升級」；把教訓變成行為改變（改規則/
改腳本）全程要人。無閉環。

## 3. 決策路徑自動化 — 🟡 自動擋、非自動決

現有機制：
- `docs\governance\RISK_RULES.md`：10條確定性Risky判定。
- `scripts\decide_escalation.ps1`：不自動決定任何事——是「登記Josh
  決定」的工具（HMAC一次性receipt、防重放、防<10秒可疑快決）。
- `task_queue_runner.ps1`的`Get-EscalationDecisionGate`：有escalation
  無合法DECISION的工單一律卡住。
- `docs\decisions\` ADR-0001~0011含回頭條件，Dashboard DecisionMap可視化。

缺口：無分級自動核准——低風險決策也要Josh點approve。這是設計選擇
（fail-closed），不是缺陷；但若要提高自主度，可考慮「白名單類型
自動核准+事後報備」機制（需Josh明確授權範圍）。

## 4. 自主運作 — 🟢 部分偏高

全自動環節（實證，不需人）：
- 開機自啟：Windows排程任務`HermesGatewayAutostart`/`HermesLiteAutostart`/
  `AgentOS-Dashboard`/`NotebookLM Conveyor`（`config\runtime_registry.json`
  共17個runtime定義）。
- **Telegram工單→執行整條鏈**：plugin產生TASK.md →
  `workflow_supervisor.ps1` → `task_queue_runner.ps1`（5秒輪詢+
  ACTIVE_TASK_INDEX+節流全掃）→ `dispatch_task_packet.ps1`
  **headless執行Codex CLI**（`codex -a never exec --sandbox
  workspace-write/read-only`，已抽查core確認第707行）——此路徑
  不需要人貼prompt。
- 自動產Verify子單（`create_codex_verify_task.ps1`）、governance gate。

仍需人的環節：
1. 所有escalation決策（§3）。
2. 桌面板遺留：repo內仍有`PROMPT_FOR_CODEX*.md`人工轉貼模式與CLI
   自動路徑並存（本session的F02/F14系列就是走桌面板）。
3. `watchdog.ps1`在registry中`enabled: false`（legacy）——gateway自癒
   目前靠排程任務層級，非常駐監控。
4. governance baseline核准。

## 5. Telegram全遠端維運 — 🟡 大部分有

現有機制（`integrations\hermes_plugins\agentos-typed-dispatch\__init__.py`
v0.8.0，掛在Hermes gateway上）：
- 能收：一般聊天、`[TYPE:]` typed dispatch、任意URL（→知識管線）、
  Threads URL、`[工單]`/`[成形]`、中文自然語工單pattern、本機檔案
  路徑、`[待核准]`、`[確認 <task_id> <decision> <6位code>]`。
- 能發：各管線完成/失敗摘要（上限3200字）、待核准清單、確認結果。
- 能控制：owner-only escalation決策已實作（constant-time比對
  `AGENTOS_OWNER_TELEGRAM_ID`、6位一次性code、10分鐘TTL、原子
  consume防重放，已抽查core確認106/240/334行）→成功後呼叫
  `decide_escalation.ps1`完成approve/modify/stop。

缺口：
1. **啟用狀態unknown**：需設定`AGENTOS_OWNER_TELEGRAM_ID`並重啟
   Hermes，repo內查不到已設定證據（同F07登記）。
2. 不能從Telegram做pause/resume/retry workflow（只在Dashboard
   `DispatchFlow.tsx`的`controlWorkflow`）。
3. Hermes本體的Telegram平台能力需另查hermes-agent。

## 6. 附加：節點圖插件現況

- 真節點圖已存在：`dashboard\frontend\components\DecisionMap.tsx`
  （SVG、可拖曳ADR節點、edges、增改狀態）——但這是**決策圖**不是
  **執行流程圖**。
- 流程視圖：`DispatchFlow.tsx`（workflow stages/nodes、supervisor
  狀態、**已有pause/resume/retry按鈕**）。
- 介入機制：`ApprovalQueue.tsx`（approve/modify/stop escalation）、
  knowledge discussion/feedback API（append-only落盤）。
- 真正缺口（呼應Josh的插件需求）：**回饋不回流**——使用者在前端的
  discussion/feedback只落盤，沒有機制把它轉成agent可執行的修正
  指令；「卡住→通知→一句話回覆→變成工單」迴路不存在。

## 結論與建議優先序

系統比「純桌面板」印象自主得多：Telegram→工單→headless Codex整條
鏈已存在。要達成Josh的五項全達標，剩三塊拼圖，都不大：

1. **啟用F07**（設`AGENTOS_OWNER_TELEGRAM_ID`+重啟Hermes）——
   零開發，立刻讓手機能做escalation決策，Q5達標一半。
2. **候選→工單自動化**（Q1最後一哩）：knowledge candidate落盤後
   自動產生draft TASK.md進queue（仍走escalation gate要你核准）。
3. **卡住回報迴路**（Q6插件+Q5另一半）：workflow卡住/escalation時
   主動推Telegram通知，你回一句話→轉成修正工單。DispatchFlow的
   pause/resume/retry再橋接到Telegram指令。

未核實事項（誠實揭露）：hermes-agent本體未掃；Telegram plugin實際
運行狀態（是否已載入、owner ID是否已設）為unknown；前端
`FailurePath.tsx`/`TaskUniverse.tsx`/`StatusAssistant.tsx`未逐一細讀。
