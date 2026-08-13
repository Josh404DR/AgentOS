# Hermes Lite Phase 0 — 成本分流設計（對應 G5）

updated_at: 2026-08-10 Asia/Taipei
狀態: 草案，待 Josh 核准後併入 `2026-08-09-hermes-lite-knowledge-layer-執行計畫.md` Phase 0 驗收
governance_version: 1.4.0
對應風險: `docs\plans\2026-08-09-hermes-lite-knowledge-layer-執行計畫.md` §1 Gate G5
依據: `AGENTS.md`（Gemini 全職窗口燒錢教訓）、`docs\EVIDENCE_AND_REPORTING_CONTRACT.md`、
`data\metrics\METRICS_LOG.jsonl` 既有欄位格式

## 0. 問題陳述

AgentOS 治理史上已經真實付過一次學費：Gemini 曾被當成全職對話窗口用，
任何問題不分難易都丟給大模型，結果燒錢燒到必須整個改成工單制／派工制
才收斂。Hermes Lite 這個「隨問隨答」的介面，本質上跟當年 Gemini 全職
窗口是同一種使用模式——如果沒有在架構層面就把「便宜的問題」擋在模型
呼叫之外，只是換了個名字重犯同一個錯。

本文件的目的不是寫一條「盡量少呼叫模型」的原則性宣示，而是給出一套
**Phase 1 索引管線可以直接照著寫的路由邏輯**：輸入一個問題字串，輸出
「走確定性路徑」或「走模型推理路徑」的判斷結果，以及對應的成本追蹤與
超支停用機制。

## 1. 問題範例庫（13 題，涵蓋難度光譜）

以下問題依「確定性程度」由高到低排列。每題附路由判斷與依據。

| # | 問題範例 | 路由 | 判斷依據 |
|---|---|---|---|
| Q1 | 「`telegram-1424` 現在是什麼狀態？」 | **確定性** | 命中「單一工單 + 狀態」樣式；直接定位 `data\codex_tasks\` 內含 `1424` 的資料夾，套用 `2026-08-10-hermes-lite-phase0-evidence-precedence-rules.md` 的 `resolve_verification_status()` 演算法，組字串回答，不需模型生成語意 |
| Q2 | 「今天有幾筆 escalation 還沒處理？」 | **確定性** | 命中「計數 + 時間範圍 + 狀態」樣式；掃 `ESCALATION_INDEX.jsonl` today 分區，套用 G2 規則（逐筆確認資料夾內是否已有 `RESOLUTION.json`，不信 index 的 `status` 欄位），計數後組字串 |
| Q3 | 「learning-candidate dedupe bug 修好了嗎？」 | **確定性** | 「修好了嗎」= 單一已知工單/主題的狀態查詢；可用關鍵字/別名表（見 §2.3）映射到 `learning-candidate-dedupe-fix-20260721`，走 Q1 同一套邏輯 |
| Q4 | 「Hermes Lite 現在能不能用？」 | **確定性** | 讀取 Hermes Lite 自身健檢欄位（排程 enabled、process 最後心跳時間、最近一次連線成功時間戳）判斷 up/down，屬結構化狀態查詢，不需推理 |
| Q5 | 「`METRICS_LOG.jsonl` 裡 verdict 是 FAIL 的有幾筆？」 | **確定性** | 明確欄位 + 明確條件 + 計數，直接掃 jsonl 用等值比對，屬最典型的結構化查詢 |
| Q6 | 「最近一筆 escalation 是什麼時候建立的？」 | **確定性** | 單一欄位（`created_at`）取最大值，無需推理 |
| Q7 | 「幫我比較一下 P-1 跟 P-3 的差異」 | **模型推理** | 「比較」需要讀取兩份以上文件內容、做語意層級的異同摘要，不是欄位查詢；無法用固定樣式組字串回答 |
| Q8 | 「這一週的 escalation 有沒有什麼共通模式？」 | **模型推理** | 開放式歸納問題，需要跨多筆記錄做語意聚類/歸因，非結構化查詢能覆蓋 |
| Q9 | 「telegram-1424 跟 telegram-1427 是不是同一個根因？」 | **模型推理** | 跨工單關聯分析，需要讀兩份 RESULT/根因描述做語意比對，非欄位比對 |
| Q10 | 「為什麼上週 Simple 任務的失敗率比較高？」 | **模型推理** | 需要對 `METRICS_LOG.jsonl` 做統計聚合再做歸因解釋，「為什麼」類問題本質上要求推理，非純計數 |
| Q11 | 「有沒有工單提到 DNS 連不上 Telegram？」 | **模型推理**（含確定性前處理） | 全文語意搜尋非結構化欄位比對；但**關鍵字全文比對**（如 grep `"DNS"` 或 `"telegram"`）可以先做確定性篩選縮小候選集，只有「篩選後仍需判斷相關性/總結多筆」時才進模型推理，見 §2.4 混合路徑 |
| Q12 | 「現在任務看板第 2 節有幾張卡住的項目？」 | **確定性** | 「有幾張」= 計數 + 明確來源文件（`PROJECT_TASK_BOARD_2026-08-09.md` 第2節），可用固定 parser（表格列數）計數，不需模型 |
| Q13 | 「這張工單的 evidence 標籤是什麼，可信嗎？」 | **混合** | 「evidence 標籤是什麼」是確定性查詢（讀 Evidence Block 欄位）；「可信嗎」是評估性問題，需要模型判斷欄位是否完整、有無 `governance_status=review_required` 等旗標並給出說明 |

**觀察**：確定性路徑能覆蓋的問題有一個共同特徵——答案是「某個檔案/某些
檔案裡已經存在的欄位值，經過確定的規則（比對、計數、取最大/最小、套用
既有優先序演算法）組合而成」，不需要生成新的語意內容。模型推理路徑的
共同特徵——答案需要「跨文件內容摘要」「歸納」「比較」「歸因」，也就是
生成規則沒有事先窮舉、必須臨場判斷的內容。

## 2. 路由判斷邏輯（可直接實作）

### 2.1 整體流程

```
function route_query(question: str) -> RoutingDecision:
    normalized = normalize(question)  # 全形轉半形、繁簡不轉、去除語尾贅字（嗎/呢/啊）

    # Step 1：結構化查詢樣式比對（見 2.2）
    match = match_deterministic_pattern(normalized)
    if match is not None:
        return RoutingDecision(
            path = "deterministic",
            handler = match.handler_name,
            params = match.extracted_params,
        )

    # Step 2：關鍵字全文篩選是否能把問題收斂成確定性子查詢（見 2.4）
    narrowed = try_narrow_to_deterministic(normalized)
    if narrowed is not None:
        return RoutingDecision(
            path = "deterministic",
            handler = narrowed.handler_name,
            params = narrowed.extracted_params,
        )

    # Step 3：都沒命中，fallback 到模型推理，但仍先做確定性的「證據收集」
    # 只有生成語意摘要/比較/歸因的最後一步才呼叫模型
    return RoutingDecision(
        path = "model_inference",
        handler = "llm_reasoning_with_retrieved_context",
        params = {"raw_question": question},
    )
```

**關鍵設計原則**：Step 3 的模型推理路徑，前置的「證據收集」（找出哪些
工單/檔案相關）**仍然盡量用確定性方法**（關鍵字比對、metadata 過濾）
完成，只把「讀懂內容並生成摘要/比較/歸因」這個真的需要語言理解的步驟
交給模型。這樣即使問題最終判定要呼叫模型，送進 prompt 的 context 也已
經被大幅收斂，不會把整批原始檔案塞給模型（這正是 Gemini 舊模式燒錢的
主因之一——不分青紅皂白把大量原始資料塞進 context）。

### 2.2 確定性查詢樣式表（regex/關鍵字比對，直接可實作）

| 樣式 ID | 觸發規則（regex，示意） | Handler | 範例命中 |
|---|---|---|---|
| P_STATUS_SINGLE | `.*(工單\|task\|telegram-\d+\|[\w-]{10,}).*(狀態\|status\|驗證通過\|完成了嗎\|修好了嗎\|能不能用).*` | `resolve_verification_status(task_id)` | Q1, Q3, Q4 |
| P_COUNT_FILTERED | `.*(有幾筆\|幾張\|多少筆\|count).*(escalation\|工單\|task\|FAIL\|PASS).*` | `count_records(source, filters)` | Q2, Q5, Q12 |
| P_LATEST | `.*(最近\|最新\|上一筆\|last).*(escalation\|工單\|task).*(時間\|建立\|created).*` | `get_max(field="created_at", source)` | Q6 |
| P_FIELD_LOOKUP | `.*(這張工單\|task_id).*(的\|之).*(標籤\|label\|欄位\|field).*(是什麼\|為何).*` | `lookup_field(task_id, field_name)` | Q13 前半 |

**比對規則**：

1. 先跑 `P_STATUS_SINGLE` / `P_COUNT_FILTERED` / `P_LATEST` / `P_FIELD_LOOKUP`
   四個 regex，依上表順序，命中第一個即用該 handler，不繼續往下比對。
2. `task_id` 抽取：優先抓 `telegram-\d+` 或明確的 `dispatch_id` 格式
   （`YYYY-MM-DD-slug` 或 `telegram-telegram-<chat_id>-<msg_id>-<timestamp>...`），
   抓不到完整 ID 時，用 §2.3 的別名表做模糊映射；映射不到就視為**不命中**，
   繼續往下一步。
3. 樣式表是**允許清單**（allowlist），不是黑名單排除法——沒命中任何樣式
   一律視為需要判斷是否進一步收斂或進模型推理，不會有「預設走確定性」
   的情況，避免誤判複雜問題成簡單問題而答錯。

### 2.3 別名/主題映射表（給 P_STATUS_SINGLE 用）

問題常常不會給出完整 dispatch_id（如 Q3 只說「learning-candidate dedupe
bug」）。維護一份輕量映射表 `data\hermes_lite\topic_alias_map.json`：

```json
{
  "learning-candidate dedupe": "learning-candidate-dedupe-fix-20260721",
  "learning candidate dedupe": "learning-candidate-dedupe-fix-20260721",
  "dedupe bug": "learning-candidate-dedupe-fix-20260721",
  "escalation classifier 1424": "telegram-telegram-1449022024-1424-20260808-130009-186078",
  "escalation classifier 1427": "telegram-telegram-1449022024-1427-20260808-133214-217789"
}
```

**產生方式**：不是手動窮舉所有可能問法。索引管線建置時，從每個
`TASK.md` 的標題/摘要欄位自動抽取關鍵詞組合成候選別名（例如
`dispatch_id` 中 slug 部分去除日期戳、底線轉空白），寫入映射表；比對時
用簡單的子字串/edit-distance 模糊比對，不需要模型。若模糊比對信心分數
低於門檻（建議 0.6，用簡單 token overlap 比例即可，不需向量模型），視為
「映射失敗」，回退到 Step 2/3。

### 2.4 混合路徑：關鍵字篩選 + 有限模型推理（Q11、Q13 這類）

```
function try_narrow_to_deterministic(question) -> NarrowedQuery | None:
    keywords = extract_keywords(question)  # 簡單斷詞 + 停用詞過濾，不用模型
    candidates = grep_full_text(keywords, sources=["TASK.md", "RESULT.md", "*.log"])

    if len(candidates) == 0:
        return NarrowedQuery(handler="answer_not_found", params={})  # 直接答「查無相關工單」，不呼叫模型

    if len(candidates) == 1 and is_simple_lookup(question):
        # 只有一筆候選，且問題本身其實是查單一欄位（例如 Q13 前半）
        return NarrowedQuery(handler="lookup_field", params={"task_id": candidates[0]})

    return None  # 多筆候選需要跨文件判斷相關性/摘要，交給 Step 3 模型推理
    # 但此時 candidates 清單會被一併傳給模型推理路徑，作為已收斂的 context，
    # 不會讓模型自己重新做全文檢索
```

這一步的意義：即使問題最終要進模型推理路徑，也已經先用零成本的
grep/關鍵字比對把候選文件從「全部工單」收斂到「幾筆候選」，大幅降低送進
模型的 token 量，這才是真的省錢，而不只是「不呼叫模型」這一個開關。

### 2.5 路由決策的可測試性

每條規則都必須有對應的單元測試（沿用 Phase 1 §3 驗收的 10 題測試問題 +
本文件 §1 的 13 題範例），斷言：

```
assert route_query("telegram-1424 現在是什麼狀態？").path == "deterministic"
assert route_query("幫我比較一下 P-1 跟 P-3 的差異").path == "model_inference"
assert route_query("今天有幾筆 escalation 還沒處理？").path == "deterministic"
assert route_query("這一週的 escalation 有沒有什麼共通模式？").path == "model_inference"
```

新增查詢樣式時，必須同步在 §2.2 或 §2.3 補上規則與測試，不能只改程式碼
不改文件——這是避免規則跟實作長期漂移的最低要求。

## 3. Token 用量追蹤機制

### 3.1 記錄格式：擴充 `METRICS_LOG.jsonl`，不另開新檔

現有 `METRICS_LOG.jsonl`（`data\metrics\METRICS_LOG.jsonl`）欄位已包含
`task_id`、`task_type`、`worker`、`verdict`、`token_actual`（或新版
`tokens`）、`duration_actual`（或 `wall_time`）、`recorded_at`、
`governance_version`、`model` 等欄位（見既有 71 筆記錄的欄位聯集）。
Hermes Lite 每次查詢**沿用同一份檔案**寫入一筆記錄，欄位對應如下，不
新創獨立的日誌格式：

```json
{
  "task_id": "hermes-query-20260810-153012-4f2a",
  "task_type": "HermesQuery",
  "worker": "Hermes Lite",
  "verifier": "n/a",
  "verdict": "answered",
  "retry_count": 0,
  "fail_reason": "",
  "escalation_required": false,
  "token_actual": 0,
  "duration_actual": "180ms",
  "final_status": "answered_deterministic",
  "recorded_at": "2026-08-10T15:30:12.0000000+08:00",
  "model": "n/a",
  "note": "route=deterministic;handler=resolve_verification_status;question_hash=<sha256前8碼>"
}
```

模型推理路徑範例：

```json
{
  "task_id": "hermes-query-20260810-153512-9c1d",
  "task_type": "HermesQuery",
  "worker": "Hermes Lite",
  "verifier": "n/a",
  "verdict": "answered",
  "retry_count": 0,
  "fail_reason": "",
  "escalation_required": false,
  "token_actual": 3420,
  "duration_actual": "6.2s",
  "final_status": "answered_model_inference",
  "recorded_at": "2026-08-10T15:35:12.0000000+08:00",
  "model": "claude-haiku",
  "note": "route=model_inference;narrowed_candidates=3;question_hash=<sha256前8碼>"
}
```

**欄位規則**：

- `task_id` 用 `hermes-query-<YYYYMMDD>-<HHMMSS>-<4碼隨機>` 格式，跟既有
  `dispatch_id` 命名風格一致但加前綴區分，避免跟真正的工單 ID 混淆。
- 確定性路徑 `token_actual` 固定寫 `0`（不是 `"unknown"`）——這是刻意的
  區分：`"unknown"` 表示「應該有值但沒量到」，`0` 表示「這條路徑本來就
  不消耗 token，量到的真實值就是零」，兩者語意不同，不能混用，否則週報
  統計時會分不清楚是真零還是漏記。
- `note` 欄位不放完整問題原文（避免 log 洩漏使用者提問內容到長期存檔，
  且 `note` 目前是自由文字欄位，其他工具可能會 grep 它），只放
  `question_hash` 前 8 碼供比對同一問題重複出現的頻率，加上
  `route`/`handler`/`narrowed_candidates` 等可直接統計的結構化資訊。
- `governance_version` 欄位比照既有記錄一併寫入，方便未來治理版本回溯。

### 3.2 上線後第一週追蹤方式

1. **每日**：跑一支輕量腳本（比照現有 metrics 相關腳本風格，不用模型）
   統計當日 `task_type == "HermesQuery"` 的記錄，輸出：
   - 當日查詢總數、`route=deterministic` 佔比、`route=model_inference` 佔比
   - 當日 `model_inference` 路徑的 `token_actual` 總和
   - 累計（自上線日起）`model_inference` 路徑 token 總和
2. **第七天**：產出一份週報（沿用本專案既有「書面產出」慣例，存到
   `data\metrics\hermes_lite_week1_token_report.md` 或等效路徑），內容
   包含上述每日數字的彙總表，附上是否超過 §3.3 門檻的結論，交 Josh 過目。
3. 追蹤期間若 `deterministic` 佔比明顯低於預期（例如低於 60%，代表§2
   的規則設計覆蓋率不夠，太多問題落到模型推理），視為**規則設計需要
   補強**的訊號，優先於「調高門檻」處理——不能靠放寬預算來掩蓋分流規則
   本身覆蓋不足的問題。

### 3.3 用量門檻與超支處理

**門檻設定基礎**：Phase 1 驗收標準是 10 題測試問題（`§3` 執行計畫），
估計實際上線第一週單日查詢量在個位數到十位數區間（Josh 一人使用，非多
人並發服務）。以此保守估計：

- 假設每日模型推理路徑查詢數上限抓 **20 筆**（遠高於預期使用量，留緩衝）
- 每筆模型推理查詢的 token 上限參考「已收斂 context」假設（§2.4 混合
  路徑已把送入模型的原始資料收斂到幾筆候選文件，而非整批工單），估計
  單筆 **不超過 8,000 tokens**（輸入+輸出合計）
- **單日門檻：20 筆 × 8,000 tokens = 160,000 tokens/day**
- **第一週累計門檻：700,000 tokens**（7 天 × 100,000，抓比單日門檻總和
  略保守的數字，因為第一週會有除錯/重跑，用量本來就會偏高，不能用理想
  值卡太緊導致還沒穩定就先觸發停用）

這兩個數字是**估算值**，需標記 `estimate=true`，且必須在 Phase 0 驗收
時交給 Josh 確認是否合理（他可能有更明確的預算概念），不是本文件單方面
定案。

**超支處理機制（自動降級，不是等人工發現才處理）**：

1. 追蹤腳本（§3.2）每次寫入新記錄後即時檢查累計值，一旦當日或累計超過
   §3.3 門檻，立即在 `data\hermes_lite\` 下寫入一個旗標檔
   `MODEL_INFERENCE_SUSPENDED.flag`（內容為觸發時間、觸發原因、累計值）。
2. 路由邏輯（§2.1 Step 3）在呼叫模型前，**必須先檢查該旗標檔是否存在**。
   若存在，不呼叫模型，直接回覆固定文字：
   > 「這類問題目前需要人工確認（本週模型查詢用量已達上限，為避免
   > 重演 Gemini 全職窗口燒錢的舊模式，本功能已自動暫停，將於下週一
   > 重新評估）。你可以查看 `<相關工單/檔案路徑>` 自行確認，或直接問
   > Josh。」
   確定性路徑不受此旗標影響，繼續正常回答——這樣即使模型推理路徑被
   停用，Hermes Lite 仍能回答結構化查詢，不是整個功能歸零。
3. 旗標檔**不自動清除**，需要 Josh 明確決定「本週門檻是否要調整」後，
   由人工刪除旗標檔或更新門檻設定才會恢復，避免自動復原又在無人注意的
   情況下重新燒錢。
4. 觸發旗標當下，同步寫一筆 `METRICS_LOG.jsonl` 記錄
   （`final_status: "model_inference_auto_suspended"`），讓這個事件本身
   可被稽核追蹤，不是只留在旗標檔裡。

## 4. 與既有治理文件的一致性聲明

- 本設計不新增獨立的 token 記錄格式，刻意沿用 `METRICS_LOG.jsonl` 既有
  欄位集合（`task_id`/`task_type`/`worker`/`verdict`/`token_actual`/
  `duration_actual`/`final_status`/`recorded_at`/`model`/`note`/
  `governance_version`），只新增 `task_type: "HermesQuery"` 這個新值，
  以維持既有 metrics 分析工具（若未來要統計全專案 token 用量）可以直接
  沿用同一份資料源，不需要另外合併兩份日誌。
- 門檻數字明確標記為 `estimate=true`，依 `CLAUDE.md` 三條硬規則第 3 條
  （不捏造，估算須標 estimate），且需 Josh 核准後才能視為正式門檻。
- 超支停用機制是「技術層面自動執行」，不是「prompt 提醒模型少用」，
  呼應 `docs\plans\2026-08-09-hermes-lite-knowledge-layer-執行計畫.md`
  §1 G4 的精神（唯讀邊界要技術層面保證，不能只靠角色描述）——同樣的
  邏輯用在這裡：成本邊界也要技術層面保證，不能只靠路由邏輯「盡量」不
  呼叫模型。
- 若未來 `AGENTS.md` 或 metrics 相關治理文件修訂導致本文件欄位定義與之
  衝突，依 `AGENTS.md` §1 證據優先序，以正本為準，本文件需同步修正。
