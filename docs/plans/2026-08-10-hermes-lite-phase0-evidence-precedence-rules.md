# Hermes Lite Phase 0 — 工單證據優先序規則（對應 G1）

updated_at: 2026-08-10 Asia/Taipei
狀態: 草案，待 Josh 核准後併入 `2026-08-09-hermes-lite-knowledge-layer-執行計畫.md` Phase 0 驗收
governance_version: 1.4.0
對應風險: `docs\plans\2026-08-09-hermes-lite-knowledge-layer-執行計畫.md` §1 Gate G1
依據: `AGENTS.md` §1 證據與優先順序、`docs\EVIDENCE_AND_REPORTING_CONTRACT.md`

## 0. 問題陳述

同一工單資料夾（`data\codex_tasks\<dispatch_id>\OUTPUTS\`）內可能同時存在
`RESULT.md`、`TEST_RESULT.md`、`VERIFY_BUNDLE.md`、`VERIFY_RESULT.md`、
`DELIVERY.md` 五種文件。這些文件是**同一工單生命週期不同階段**的快照，
不是彼此獨立、平權的意見來源——後面階段的文件建立在前面階段之上，且
`VERIFY_RESULT.md` 明確是「另一個全新 read-only session 的獨立盲審結論」
（見 `AGENTS.md` §4：「任一 Worker 完成後必須由不同的全新 Codex Verify
session 依 acceptance criteria 獨立驗證」）。

如果 RAG 系統只讀取其中一份（例如按檔名字母序取第一份，或只取
`RESULT.md`），會出現**用工單早期、尚未驗證的快照回答「最終狀態」問題**
的錯誤，即使工單實際上早已驗證通過。這不是假設風險：2026-08-10 稍早這個
session 就真實發生過一次——只讀了 `learning-candidate-dedupe-fix-20260721`
的 `RESULT.md`（裡面寫 `verified: false`、`task_status:
implemented_pending_fresh_verify`），就下結論說工單「還沒驗證」，被 Josh
糾正後才發現同資料夾內還有 `VERIFY_RESULT.md`，證實工單在同一天
（2026-07-21）已經 `verify_verdict: PASS`、55/55 測試通過。

本文件定義的優先序規則，目的是讓 RAG 系統的行為在架構層面就不會重演這個
錯誤，而不是靠 prompt 提醒「記得看全部檔案」。

## 1. 優先序規則（Precedence Rules）

### 1.1 核心原則

比照 `AGENTS.md` §1 的精神——「較低層不得覆寫較高層」——套用到單一工單
資料夾內的文件層級：**代表更晚階段、更獨立來源的文件，其「最終驗證狀態」
欄位覆蓋更早階段、更不獨立來源文件的同類欄位**。但覆蓋的是「最終狀態
判斷」，不是整份文件的事實內容——早期文件裡的 root cause、diff 位置、
scope 說明等描述性事實，只要沒有被後續文件明確否定，仍然有效，應該被
組合進回答裡（見 §2）。

### 1.2 文件優先序（高到低）

| 順位 | 文件 | 角色定位 | 覆蓋哪個欄位 |
|---|---|---|---|
| 1 | `VERIFY_RESULT.md` | 獨立 Verify session 的最終盲審結論（`AGENTS.md` §4：不同 session、read-only、獨立） | `verify_verdict`、`verified` 兩個欄位 |
| 2 | `TEST_RESULT.md` | 實際測試執行輸出（可能是 Builder self-check，也可能已含 `independent_verify_status`） | 測試通過與否、`independent_verify_status` |
| 3 | `RESULT.md` 的 `verified` 欄位 | Builder 自報的驗證狀態欄位（結構化欄位，非敘述文字） | 僅該欄位本身 |
| 4 | `RESULT.md` 其他欄位（root cause、實際變更、歷史證據 hash 等敘述內容） | Builder 自報的實作內容與方案說明 | 描述性事實，非最終驗證狀態 |
| 5 | `VERIFY_BUNDLE.md` | Verify 的輸入規格／checklist（尚未執行，是「要驗什麼」不是「驗完的結論」） | 不覆蓋任何狀態欄位，只用來解釋 VERIFY_RESULT 的 AC 對應關係 |
| 6 | `DELIVERY.md` | 交付清單（改了哪些檔、hash 是多少） | 不覆蓋驗證狀態，只回答「變更了什麼」類查詢 |

**關鍵說明**：

- `VERIFY_BUNDLE.md` 不是驗證結論，是驗證前發給 Verifier 的「考卷」
  （blind checklist）。RAG 絕對不能把 `VERIFY_BUNDLE.md` 存在本身當成
  「已驗證」的證據；它只回答「工單有沒有排入 Verify 流程」。
- `DELIVERY.md` 的 `delivery_status` 欄位（例如
  `pending_independent_verify`）跟 `VERIFY_RESULT.md` 的結論可能不同步
  ——`DELIVERY.md` 是 Builder 交付當下的快照，寫完之後不會回頭更新。
  查詢「這次改了哪些檔案」用 `DELIVERY.md`；查詢「驗證通過了沒」永遠讓
  `VERIFY_RESULT.md` 蓋過 `DELIVERY.md`。
- 如果 `VERIFY_RESULT.md` 不存在，但 `RESULT.md` 的 `verified` 欄位是
  `false` 且 `task_status` 含 `pending_fresh_verify`／`awaiting_verify`
  類字樣，正確回答是「已實作，待獨立驗證」，不是「未完成」或
  `unknown`——實作與驗證是兩件事，不能混為一談。

### 1.3 判斷演算法（可直接實作的邏輯）

```
function resolve_verification_status(task_folder):
    files = list_outputs(task_folder)  # 掃描 OUTPUTS/ 底下實際存在的檔案

    if "VERIFY_RESULT.md" in files:
        v = parse(VERIFY_RESULT.md)
        if v.verify_verdict == "PASS" and v.verified == true:
            final_status = "verified_pass"
        elif v.verify_verdict == "FAIL":
            final_status = "verified_fail"
        elif v.verify_verdict == "NEEDS_HUMAN_DECISION":
            final_status = "escalated_pending_josh"
        source_of_truth = "VERIFY_RESULT.md"

    elif "TEST_RESULT.md" in files:
        t = parse(TEST_RESULT.md)
        if t.independent_verify_status == "pending":
            final_status = "implemented_tests_pass_awaiting_independent_verify"
        source_of_truth = "TEST_RESULT.md"
        # 注意：TEST_RESULT.md 的 builder_self_check=PASS 不能單獨升級為
        # "verified"，因為 self-check 不是獨立驗證（見 AGENTS.md §4）

    elif "RESULT.md" in files:
        r = parse(RESULT.md)
        if r.verified == true:
            final_status = "builder_reported_verified"  # 罕見，通常應有 VERIFY_RESULT 佐證
        else:
            final_status = "implemented_pending_verify"
        source_of_truth = "RESULT.md (verified field)"

    else:
        final_status = "unknown_no_result_artifact"
        source_of_truth = "none"

    return final_status, source_of_truth
```

### 1.4 矛盾情境的組合回答規則

當多份文件同時存在且「最終狀態」欄位彼此矛盾時（例如
`RESULT.md.verified=false` 但 `VERIFY_RESULT.md.verified=true`），RAG
**不得**只回報單一份文件的結論，也**不得**把矛盾本身當成回答不了的理由
（不可回 `unknown`）。正確做法：

1. 以 §1.2 優先序決定「最終狀態」，作為回答的主結論。
2. 在回答裡明講時間序與脈絡，讓使用者知道這不是資料錯誤，而是工單生命週期
   的正常演進。範本句型：

   > 「雖然初版 RESULT.md（Builder 自報，`verified: false`）顯示待驗證，
   > 但後續獨立的 VERIFY_RESULT.md（`verified_at: <日期>`）已判定
   > `PASS`，因此本工單狀態為**已驗證通過**。」

3. 附上兩份文件的路徑與關鍵欄位值，讓使用者可以自行核對（比照
   `docs\EVIDENCE_AND_REPORTING_CONTRACT.md` 的可稽核精神）。
4. 如果 `VERIFY_RESULT.md` 的 `verified_at` 早於 `RESULT.md` 的最後修改
   時間（理論上不該發生，但要防呆），標記
   `governance_status=review_required`，比照 `AGENTS.md` §1 的規則，不
   自行選邊，交由人工複核。

## 2. 與 `EVIDENCE_AND_REPORTING_CONTRACT.md` 標籤的對應

`resolve_verification_status()` 的內部狀態值，對外回答時應轉換成
`docs\EVIDENCE_AND_REPORTING_CONTRACT.md` §1 定義的權威標籤，不要自創新詞：

| 內部狀態 | 對外標籤 |
|---|---|
| `verified_pass` | `verified_by_codex`（若 verifier 是 Codex）|
| `verified_fail` | `blocked` 或 `partial`，依 FAIL 的 AC 範圍 |
| `escalated_pending_josh` | `blocked`（附 escalation 路徑）|
| `implemented_tests_pass_awaiting_independent_verify` | `locally_verified` |
| `implemented_pending_verify` | `claimed_by_agent` 或 `artifact_created` |
| `builder_reported_verified` | 降級為 `claimed_by_agent`，並在回答中註明「缺獨立 VERIFY_RESULT 佐證，異常情況」|
| `unknown_no_result_artifact` | 回 `unknown`（誠實承認，符合計畫 §1 G8 的「答不出來就誠實說 UNKNOWN」原則）|

## 3. 回歸測試案例：`learning-candidate-dedupe-fix-20260721`

### 3.1 測試資料位置

`E:\AgentOS\data\codex_tasks\learning-candidate-dedupe-fix-20260721\`，
內含：

- `TASK.md`：`dispatch_id=learning-candidate-dedupe-fix-20260721`，
  `task_type=Simple`，修復 `collect_learning_candidates.ps1` 的 dedupe
  bug。
- `OUTPUTS\RESULT.md`：`task_status: implemented_pending_fresh_verify`、
  `builder_self_check: PASS`、**`verified: false`**、
  `verify_level: full_blind_verify(...)`。文末「未解狀態」明講
  「full blind Codex Verify 尚未執行，因此本單不得標記 verified 或正式
  PASS」。
- `OUTPUTS\TEST_RESULT.md`：`independent_verify_status: pending`、
  `verified: false`；`tests\learning_collector\run_tests.ps1`：
  `passed=55 failed=0 total=55`，`TEST_SUITE_RESULT=PASS`。
- `OUTPUTS\VERIFY_BUNDLE.md`：`verify_mode: full_blind_read_only`，列出
  AC1–AC6 checklist，是**驗證前**發給 Verifier 的輸入，本身不含結論。
- `OUTPUTS\VERIFY_RESULT.md`：`verify_verdict: PASS`、**`verified: true`**、
  `verify_mode: full_blind_read_only`、
  `verifier_thread_id: 019f837a-1534-7b22-8b05-31d8416756c1`、
  `verified_at: 2026-07-21 Asia/Taipei`；AC1–AC6 逐項 PASS，
  `Final Verdict: PASS`。
- `OUTPUTS\DELIVERY.md`：`delivery_status: pending_independent_verify`
  （此欄位是交付當下快照，**不**因後續 VERIFY_RESULT.md 通過而回頭更新，
  屬正常現象，不代表矛盾）。

### 3.2 測試輸入（查詢問題）

以下三題皆須通過：

1. **Q1**：「`learning-candidate-dedupe-fix-20260721` 這張工單驗證通過了嗎？」
2. **Q2**：「learning candidate dedupe fix 這個修復是已驗證還是還在等驗證？」
3. **Q3**（防呆重點題，直接對應真實踩過的錯誤）：「只看 RESULT.md 的話，
   這張工單是不是還沒驗證？」——此題刻意誘導系統只回答表面欄位，用來確認
   系統不會落入跟本 session 稍早一樣的陷阱。

### 3.3 預期輸出

Q1／Q2 預期回答（語意層級，措辭可調整）：

> 已驗證通過（PASS）。獨立 Verify session（`verified_at: 2026-07-21`）
> 在 `VERIFY_RESULT.md` 判定 `verify_verdict: PASS`，AC1–AC6 全數
> PASS，含完整 learning collector 測試套件 55/55 通過。雖然本工單早期
> 的 `RESULT.md` 標記 `verified: false`（當時 Verify 尚未執行），但該
> 欄位已被後續獨立驗證結果覆蓋，不代表最終狀態。
>
> 對外標籤：`verified_by_codex`。
> 證據路徑：
> `data\codex_tasks\learning-candidate-dedupe-fix-20260721\OUTPUTS\VERIFY_RESULT.md`
> （主要依據），
> `data\codex_tasks\learning-candidate-dedupe-fix-20260721\OUTPUTS\RESULT.md`
> （脈絡，說明早期狀態）。

Q3 預期回答：

> 不是。RESULT.md 的 `verified: false` 只是 Builder 完成實作當下、
> Verify 尚未執行的快照。同一工單資料夾內還有 `VERIFY_RESULT.md`，是
> 另一個全新 session 在 2026-07-21 做的獨立盲審，結論是 `PASS`。依證據
> 優先序規則，`VERIFY_RESULT.md` 覆蓋 `RESULT.md` 的 `verified` 欄位，
> 因此工單的最終狀態是**已驗證通過**，不是「還沒驗證」。

### 3.4 判斷依據（斷言邏輯）

自動化測試斷言（pseudo-assertion，供實作 RAG 測試套件時直接對照）：

```
assert resolve_verification_status(
    "learning-candidate-dedupe-fix-20260721"
) == (
    final_status = "verified_pass",
    source_of_truth = "OUTPUTS/VERIFY_RESULT.md"
)

assert external_label(final_status) == "verified_by_codex"

# 防呆：確認系統有讀到 VERIFY_RESULT.md，不是只看 RESULT.md
assert "VERIFY_RESULT.md" in cited_evidence_paths(answer_to_Q1)

# 防呆：確認 RESULT.md 的 verified=false 沒有被誤判成最終結論
assert answer_to_Q1 does NOT contain ("尚未驗證" or "還沒驗證" or "unknown")
    unless answer also cites VERIFY_RESULT.md and explains the override

# 脈絡完整性：答案應同時提及兩份文件的時間關係，而非只丟結論
assert answer_to_Q1 mentions both "RESULT.md" (early state)
    and "VERIFY_RESULT.md" (final, overriding state)
```

若任一斷言失敗，視為 G1 gate 未通過，Phase 0 不得結案。

## 4. 實作備註（給 Phase 1 索引管線的具體要求）

1. 索引管線在建立單一工單的「文件集合」時，必須把
   `RESULT.md`／`TEST_RESULT.md`／`VERIFY_BUNDLE.md`／`VERIFY_RESULT.md`／
   `DELIVERY.md` 視為**同一個邏輯實體**（同一 `dispatch_id`）的不同階段
   快照，而不是各自獨立的檢索單位。檢索時若命中其中一份，必須連帶把同資料
   夾其餘四份的存在與否、關鍵欄位一併取出，供 §1.3 演算法判斷用，不能只
   回傳命中的那一份給生成模型。
2. `verified` 欄位在 `RESULT.md` 與 `VERIFY_RESULT.md` 中意義不同（前者
   是 Builder 自報，後者是獨立驗證結論），索引時必須標記欄位來源
   （`source_file`），不能把兩者的 `verified: true/false` 直接合併成單一
   全域欄位，否則會出現「兩個 true/false 打架，不知道信哪個」的二次
   矛盾。
3. 本規則只涵蓋單一工單資料夾內的文件優先序，不處理跨工單的證據優先序
   （例如同一根因被兩張不同工單各自宣稱修復）——那屬於另一個尚未定義的
   問題，Phase 1 若遇到需另開規則，不得套用本文件的規則硬套。

## 5. 與既有治理文件的一致性聲明

本規則不新增任何 `AGENTS.md` 未定義的權威層級，只是把 `AGENTS.md` §1
「較低層不得覆寫較高層」的精神，具體映射到單一工單資料夾內的文件集合，
並用 `docs\EVIDENCE_AND_REPORTING_CONTRACT.md` §1 既有的標籤系統對外回報。
若未來 `AGENTS.md` 或 `EVIDENCE_AND_REPORTING_CONTRACT.md` 修訂導致本文件
與之衝突，依 `AGENTS.md` §1 證據優先序，以正本為準，本文件需同步修正。
