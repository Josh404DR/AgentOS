# AgentOS 專案任務看板

updated_at: 2026-08-09 Asia/Taipei
維護者: Claude Cowork（依 Josh 指示建立，供接下來的方針提案對照現況）
governance_version: 1.4.0
governance_hash: 759F5EE67C5706DD7BF9B193913DFA6B6EEF03292FC0B8FA264F40A9A9E146D2

本文件是任務追蹤看板，不是治理正本。狀態以 `E:\AgentOS` 實際檔案/git/governance_status.json 為準；本文件內容若與現場證據衝突，以現場證據為準，並回頭更新本文件。

---

## 1. 已完成（2026-08-08 治理 drift 清理，§0-§12）

完整過程記錄在 `E:\AgentOS\PROMPT_FOR_CODEX_governance_drift_cleanup_20260808.md`，以下只列結果。

| # | 項目 | 結果 | Commit |
|---|---|---|---|
| 0 | AGENTS.md／CLAUDE.md 首次進版控 | 完成 | `3a00833` |
| 1 | typed-dispatch plugin + 依賴腳本 | 完成，已驗證上線版本一致 | `6c1d0b2` |
| 2 | task_queue_runner.ps1 + 依賴腳本 | 完成，risky escalation 已核准 | `cf43447` |
| 3 | current_state.md 同步至現行內容 | 完成 | `8e658d5` |
| 4 | ci-queue-01-always-fail 測試污染修復 | 完成，貫穿既有 `-Environment`/`is_fixture` 機制 | `6836cc0` |
| 5 | write_task_metric.ps1 補追蹤 + 治理基線第一次核准 | 完成，drift 36→24 | `3d390a1` |
| 9.1 | 早上發現漏寫進行動項目的 9 支檔案（hermes bridge、typed_dispatch、url_intake、codex_build.md、ARCHITECTURE.md） | 全部審查並 commit | `14bf027`/`6edf22c`/`b138a27`/`1bf598b`/`3136fb7`，drift 24→15 |
| 10.4 | 剩餘 15 項 drift 內容審查 | 全部 commit（dashboard frontend 經 Josh 確認、docs 類純文件、publish_url_knowledge.ps1） | `be55b46`/`669097b`/`e18d803` |
| 額外 | 檔案搬遷收尾、個人筆記刪除記錄、.gitignore 補齊 | 完成 | `a06aa87`/`9457e7c`/`500dd34` |
| 11.1 | 治理基線第二次核准 | drift 15→0，`governance_status=aligned` | （baseline 核准，無新 commit） |
| 11.2 | `data/codex_tasks/` 排除進版控（Josh 決定：只擋未來新增，已追蹤的 2379 個舊檔維持現狀不動） | 完成，含修正 `.gitignore` 反斜線 bug | `1e81fee`/`d1cb4b9` |
| 11.3 | SCC 5 筆 escalation 確認 | 確認狀態不變，非執行項目 | 無 |
| 12 | 治理規則本身收尾：AGENTS.md 新增「收尾稽核義務」、40_MAINTENANCE_PROTOCOL 新增 §8、50_LESSONS 補 3 則教訓 | 完成 | `8d57643`，AGENTS.md → v1.4.0 |

**分支狀態**：以上全部在 `task/result-chain-upgrade-20260713`，本機 commit，**尚未 push**。

---

## 2. 待處理 — 只有 Josh 能做（不可委派給 worker）

**2026-08-10 更新**：Josh 明確裁決優先序調整為「先把 Hermes Lite 功能拉上來」，以下三項改為主動延後，不再是今天的 gate，之後有空再處理，不影響 Hermes Lite Phase 0 啟動。Escalation 佇列已由 Josh 手動於 dashboard 清空（含發現並修復一個真實的時間戳記字串比對 bug，見 §3）。

| 項目 | 現況 | 動作 |
|---|---|---|
| Python launcher 修復 | `data\codex_tasks\2026-07-06-python-runtime-repair` 卡 `approval_required`，狀態未變 | **延後**，非目前阻塞項；需要時再執行 `winget install -e --id Python.Python.3.13 --scope user` |
| `E:\ai_tool_core` OAuth 憑證明碼外露（`client_secret.json`／`token.json`） | 2026-08-07 稽核發現，狀態未知是否已處理 | **延後但不遺忘**——涉及帳密安全，建議找空檔花 5 分鐘確認一次，不能跟治理雜訊一起無限期擱置 |
| scc-ai-tool-core 5 筆 escalation | **完成（2026-08-10）**：Josh 於 dashboard 逐筆處理 | 無動作 |
| Codex 額度／治理規則政策決定 | 是否升級方案、要不要在治理規則加「額度不足自動降級」邏輯 | 決定後才能開票執行，不急 |

## 3. 待處理 — 可委派給 code 執行端

| 項目 | 現況 | 建議做法 |
|---|---|---|
| ~~README.md Source of Truth 清單清理~~ | **完成（2026-08-10）**，commit `b000c75` | 移除 `PRE_FLIGHT_TEST_PLAN.md`（`planned-not-implemented`），一併同步既有待處理的角色描述更新；內容核對與稽核所見一致，非權限定義層級變更 |
| ~~`docs/temp_routing_rules.txt` 歸檔~~ | **完成（2026-08-10）**，commit `d3ea8d4` | 內容已被 `docs\COST_SAVING_ROUTING_PROTOCOL.md` 取代，移至 `archive\docs\`，比照 `archive\scripts\`/`archive\Cursor_use\` 既有慣例 |
| ~~CI `pytest_dependency` 持續 FAIL~~ | **完成（2026-08-10）**，commit `ad7dffa` | 補進 `dashboard/backend/requirements.txt`（非一次性 pip install），驗證 `python_suites` suite 轉 PASS |
| Escalation 佇列重新盤點 | **完成（2026-08-10）**：35 筆全部分類完畢，見下方明細 | 已完成，結果見下 |
| **新發現：Escalation 分類器誤判核准指令為新 Risky 工單** | 根因已查明並實測重現：`classify_task.ps1` 否定詞正則假設「否定詞與風險詞同一行」，1427 是條列式「明確禁止：」清單（否定詞另起一行），跨行抓不到否定，導致「移除」命中 `deletion` 規則、被誤判成新 Risky 工單。**2026-08-10 Claude 決策（Josh 授權）：APPROVE 轉正式派工**（標 Risky），下次交接開票；1424 本身的核准仍需 Josh 親自用不觸發 bug 的措辭送出（見 `docs\plans\2026-08-10-claude-decisions.md` 第1項的建議措辭） | 技術方案已寫入 `docs\plans\2026-08-10-escalation-classifier-1424-1427-misjudgment.md`，可直接轉 TASK.md |
| `~46` 支已追蹤但修改中的核心角色/治理檔案（`agents\roles\claude.md`／`codex.md`／`hermes.md` 等） | **2026-08-10 Claude 決策（Josh 授權）：排定 2026-08-11 開始**，不再無限期「另開一輪」 | 比照今天「先看 diff、查工單、無工單先問」的流程，不要因為改動小就跳過 |
| Hermes gateway watchdog | 已確認是刻意架構決定（`enabled:false`），非 bug，不需修 | 無動作，僅供記錄 |
| `agents/roles/claude.md` 舊版「Read-Only Inspector」矛盾描述 | `00_DIAGNOSIS.md`(07-08) 診斷過，`40_MAINTENANCE_PROTOCOL.md` §3 待辦仍未打勾 | 併入上面「~46 支核心角色檔案」那輪一起處理 |
| P-1：Verify isolation 機械化證明 | 來自 Self-Evolution Proposal v0.2 Phase -1。**2026-08-10 Claude 決策（Josh 授權）：APPROVE 轉正式派工，走 TASK.md/Codex Builder/獨立 Verify 流程**，下次交接開票，與其他工作並行 | 需證明：Verify 必須獨立 dispatch 建立、有獨立 execution identity、原始 Worker 不能自產有效 PASS、RESULT 可追溯 verify dispatch；做成系統結構限制，不是 prompt 規則 |
| P-3：歷史資料信任分類（Trusted/Excluded/Unknown） | 同上，Self-Evolution Proposal v0.2 Phase -1 前提工作。**2026-08-10 Claude 決策（Josh 授權）：同 P-1，APPROVE 轉正式派工** | 對 RESULT/Retry/Escalation 歷史資料標記三類：已知污染區間標 Excluded，無法確認標 Unknown，其餘標 Trusted。**注意：08-10 盤點發現 learning-candidate dedupe bug 的重複記錄延伸到 07-26，比 50_LESSONS.md 記錄的 07-19~07-21 污染區間更長，正式派工時需重新核實污染區間範圍，不能沿用舊的 07-21 截止點** |

### Escalation 佇列 35 筆分類明細（2026-08-10）

| 分類 | 數量 | 說明 |
|---|---|---|
| 可自動關閉：`ci-queue-01-always-fail-*` 測試雜訊 | 14 | commit `6836cc0` 修復前產生的舊噪音 |
| 可自動關閉：`learning-candidate-LC-*` dedupe bug | 9 | 同 3 個候選 ID 於 07-19/07-20/07-26 重複出現——07-26 超出已知污染區間，需回頭確認修復是否完整生效 |
| 已知、非新問題 | 5 | `scc-*-ai-tool-core-*`，已處理 |
| 需要 Josh 決策的個案 | 7 | `telegram-1424`（Risky 卡著未核准）、`telegram-1427`（分類器誤判，見上）、`telegram-1409`（Verify 唯讀規則 vs 需寫檔的結構性矛盾，需裁定）、`telegram-1273`/`telegram-1313`（舊案卡 verify_needs_human，無新資訊）、`2026-07-26-docs-governance-status-autolink-codex-verify`（可關閉，已被後續 remediation 工單取代）、`2026-07-29-f02-b3-dashboard-hermes-http-client`（舊案，兩輪 Verify 皆 FAIL） |

**注意**：以上「可自動關閉」23 筆與「已知非新問題」5 筆，code 執行端刻意沒有自己動手關閉——即使標記「雜訊已知可關閉」也是一種決策動作，跟 escalation 系統「拒絕聊天指令當授權」的設計精神一致。實際關閉動作待 Josh 核准或走正式流程。

**2026-08-10 後續**：Josh 決定與其繼續累積治理雜訊，優先把資源轉去做 Hermes Lite 功能建設，於 dashboard 逐筆將 34 筆待核准/待處理項目手動核准或停止清空。過程中發現並修復一個真實前端顯示 bug：`dashboard\backend\main.py` `_list_escalations()` 用字串直接比對兩個 ISO 時間戳記（`ESCALATION_INDEX.jsonl` 的 `created_at` 無小數秒 vs `DECISION-*.json` 的 `escalation_created_at` 帶 7 位小數秒），格式不同導致比對永遠失敗，已核准/已停止的 escalation 永遠顯示還在等待，Josh 因此對同一筆重複點擊多次（產生大量重複 `DECISION-*.json`/`RESOLUTION-*.json`，資料本身無害，只是冗餘）。已修復：新增 `_same_instant()`/`_normalize_iso_fraction()` 輔助函式改為解析成時間物件比較，`-Dev` 模式下 `--reload` 應已自動套用，未走 commit（待下次交接一併處理）。

**佇列已清空**（獨立核對：`ESCALATION_INDEX.jsonl` 中非 fixture、無 `RESOLUTION.json` 的項目為 0 筆），不再是 Hermes Lite Phase 0 啟動的阻塞項。

## 4. 提案追蹤（架構方向，非例行工單）

| 提案 | 狀態 | 對應文件 |
|---|---|---|
| Hermes Lite × AgentOS Knowledge Intelligence Layer | **2026-08-10：Phase 0 六項前置工作完成初版 + Phase 1 MVP 已開正式派工**。Josh 指示「繼續自主推進」，Claude 開票 `2026-08-10-hermes-lite-phase1-rag-evidence-mvp`（Complex/CODEX_PLAN，`ready_to_route`），範圍：AgentOS 側查詢引擎本體（索引+證據優先序+escalation查詢+成本分流），明確排除 Hermes Lite 的 Telegram 連線修復與對外介面串接。ADR-0012 仍是 `proposed`，Josh 尚未逐項過目內容 | `docs\plans\2026-08-09-hermes-lite-knowledge-layer-執行計畫.md`、`docs\decisions\ADR-0012-hermes-lite-knowledge-layer.md`、`data\codex_tasks\2026-08-10-hermes-lite-phase1-rag-evidence-mvp\TASK.md` |
| AgentOS Self-Evolution | v0.2 修正為 HOLD，僅授權 Phase -1 前提工作（併入既有治理/baseline，P-1/P-3 已拆入上方 §3）；四項 Exit Criteria 全部達成才能進 `READY_FOR_PHASE_0_AUDIT` | `docs\plans\2026-08-09-self-evolution-proposal-review.md` |
| AgentOS × OmniRoute 多模型基礎設施 | **暫緩，不列入近期排程**：查證後發現有真實但已修補的憑證外洩 CVE 記錄，且免費層效益靠偽裝流量手法達成，對 AgentOS 正式在用的 Claude/Codex 帳號有 ToS 風險；AgentOS 目前實際串接的 provider 數量少（2-3 個），既有 fallback 機制已部分覆蓋，宣稱效益大於實際效益 | 無執行計畫，Josh 未正式裁決是否徹底放棄或僅暫緩，需要時再議 |

## 5. 長期/觀察中，暫不需要動作

| 項目 | 現況 |
|---|---|
| Antigravity 4 帳號 worker `windows_user` 綁死、無法跨帳號自動觸發 | 確認仍然成立，`fallback_policy.automatic_account_rotation: false`；解法涉及憑證儲存機制，需 Josh 明確核准才能動 |
| Claude/Codex 額度受限（owner-provided，非本機驗證） | 沒有新證據確認是否解除，維持 unknown |
| Metrics 基線數據量薄 | `METRICS_LOG.jsonl` 目前 71 筆，多數 token/duration 仍 `unknown`，量化路線（儀表板八指標）要看到有統計意義還需要更多筆數 |

---

## 6. 下一步

**2026-08-10 收工狀態**（自主推進 Hermes Lite/P-1/P-3 過程中，意外挖出一連串驗證鏈系統性問題，記錄如下，供下次交接直接接手）：

### 今天真正做完、有獨立核對過的
- Escalation 分類器 1424/1427 誤判 bug：根因查明並修復（否定詞正則不跨行），已核准、已跑 Builder，但**分類器修復本身的最終 Verify 狀態是 UNKNOWN**（見下方「未解決」）。
- Codex Verify readiness 卡矛盾（`assert_governance_ready.ps1` 缺 `-ReadOnly`）：**真正修好，唯一今天乾淨拿到 PASS 的一張**（`2026-08-10-codex-verify-readonly-governance-check`）。連帶解開 `telegram-1409` 的舊根因，但未重跑該票驗證。
- README/routing 清理、CI pytest 修復：commit `b000c75`/`d3ea8d4`/`ad7dffa`，已驗證。
- 34 筆待核准/待處理 escalation：Josh 於 dashboard 清空，過程中發現並修復 `dashboard\backend\main.py` 時間戳記字串比對 bug（未 commit，待下次交接）。
- Hermes Lite Phase 0 六項前置設計文件：全部完成初版（索引管線/證據優先序/escalation規則/成本分流/ADR-0012），**Josh 尚未逐項過目內容**。

### 未解決，下次交接優先看這裡
1. **分類器修復票（`2026-08-10-escalation-classifier-negation-newline-fix`）真實狀態未知**——程式碼確實被改了（git diff 證實），但其獨立 Verify 子票回報 `FAIL`，而這個 FAIL 判定本身的證據（evidence manifest/git 快照）跟直接 `git status` 查到的實際狀態矛盾（Verify 說 `modified=0`，實際有修改）。**不能採信這個 FAIL，也不能採信最早 Worker 自稱的 PASS**，需要專門查一次 Verify 自己的 evidence 快照機制。
2. **queue-runner 依賴狀態修復票（`2026-08-10-queue-runner-dependency-status-normalization`）**：Builder 已執行，重建 Verify bundle 後**evidence mismatch 問題已消失**（`evidence_manifest_mismatch: false`，git_status 與 diff_trace 對得上）。這次是真實 FAIL，理由是 `TEST_RESULT.md` 缺少必要的測試證據（`test_status: missing`）——Builder 口頭聲稱測試過了，但沒有把指令/退出碼/輸出寫進 TEST_RESULT.md，Verify 規則明確不採信口頭聲稱。**下一步（已決定）：退回 Builder 補上真實測試證據，再送一次全新 Verify**，不需要重新設計，是補證據的問題。
3. **Hermes Lite Phase 1 的 9 張子票、P-3 的子票**：全部卡在依賴狀態 bug 上，等 queue-runner 修復票拿到真 PASS 後才能重跑確認自動解卡。
4. **Verify evidence 快照機制 mismatch 的問題已定位**：舊的矛盾結果出在 bundle 沒重建就重跑 Verify；用 `create_codex_verify_task.ps1` 開全新獨立 Verify、強制刷新 bundle 後，這次的 evidence 就跟真實 git 狀態一致了。判斷：**不是系統性 bug，是「沒開全新 Verify session 就重跑」的操作問題**，之後每次要重驗證都應該用 `create_codex_verify_task.ps1` 開新票，不要沿用舊 Verify 子票。這條之前列的「未開票的深層問題」可以結案。

### Telegram/GROQ 連線（已查證，可結案）
`.env`（實際存於 Windows User-scope 環境變數）兩把金鑰都有效：`TELEGRAM_BOT_TOKEN` 對應 bot `Joshpersonal_AIBot`，`getMe` 回傳 `ok=True`；DNS 解析、ping `api.telegram.org` 正常；`GROQ_API_KEY` 呼叫 `/v1/models` 正常回傳 15 個模型。**結論：憑證與網路都不是問題**，ADR-0012 未決事項這條可以標記已查證排除。若 Hermes Lite 之後仍連不上 Telegram，根因在別處（例如 process 本身、proxy、防火牆），需要另外查。

### 今天的操作教訓（值得記錄，不重複踩）
- **多次抓到「Worker 自稱 PASS/完成，但實際沒發生」**：分類器票的假 PASS 宣稱、`-Once` 一次只處理一張導致 Builder 在 Verify 子票還沒跑就先寫「已通過」。P-1 想解決的問題今天在真實運作中發生了至少兩次，非常值得優先推進。
- 核准 escalation 這個動作**不會**自動把對應 TASK.md 的 `route_to`/`dispatch_status`/`task_status` 轉成可執行狀態，`decide_escalation.ps1` 只記錄決定本身——這是既有流程的缺口，今天靠人工手動轉換繞過，值得考慮補一支自動化腳本。
- 給 code 執行端的指令，寫之前務必自己先查證（今天多次因為我沒查證就給錯指令：漏必填參數、`ValidateSet` 不合法值、`Join-Path` 用法錯誤、正則沒錨定、查錯欄位），code 執行端也養成了「先查再跑」的習慣，抓到好幾個原本會出包的地方——這個雙重查證的節奏值得保持，不要為了求快跳過。

---

**2026-08-10 更新**：三個提案都已收到並處理完畢（見§4）。`current_state.md` §7 已改為任務導向（讓 Josh 在本職工作之餘輕鬆多工），不再是收入優先。今日建議順序見下方「今日優先序」（早上訂的，多數已過時，保留供對照）。

### 今日優先序（2026-08-10，依 Josh「你就幫我安排一下順序吧今天適合先做什麼」）

排序邏輯：Josh-only 且會持續累積損耗的項目優先 → 小成本立即可做的清理 → 高價值但需要先鋪路的新建設。

1. **scc-ai-tool-core 5 筆 escalation 重試**（§2）——卡了超過 35 小時，Josh-only，Telegram/dashboard 走一下即可解決，不做只會繼續掛著。
2. **`E:\ai_tool_core` OAuth 憑證外露確認**（§2）——涉及帳密安全，拖越久風險越大，Josh-only，查一下是否已進版控/外流即可。
3. **Python launcher 修復**（§2）——`winget install` 一行指令，Josh-only，卡一個多月了，成本很低。
4. **README.md／`temp_routing_rules.txt` 小清理**（§3）——可委派，成本低，隨手做掉不留尾巴。
5. **CI `pytest_dependency` 修復**（§3）——`pip install pytest`，可委派，成本低。
6. **P-1／P-3（Verify isolation 證明、歷史資料信任分類）**——Josh 已裁決可並行，可委派，找空檔就推進，不用等其他項目做完。
7. **Escalation 佇列 35 筆重新盤點**（§3）——可委派，但工作量較大，排在小清理之後。
8. **Hermes Lite Phase 0 前置工作**——與新方向（多工協作）關聯度最高，但需要 Josh 先核准 Phase 0 六項前置工作與 ADR-0012 才能開工，屬於「今天可以做的決定」而非「今天可以做完的工作」。
9. **~46 支核心角色/治理檔案稽核**（§3）——風險較高、工作量最大，建議另開一輪，不塞進今天。

Josh 今天如果只做一件事，優先看 1-3（Josh-only、卡最久、成本最低），其餘可同步委派給 code 執行端處理。
