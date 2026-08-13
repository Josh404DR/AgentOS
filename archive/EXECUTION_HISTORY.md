# AgentOS 執行歷程記錄

彙整所有正式的計畫執行、驗證、問題發現的歷史記錄。  
本檔案作為持久化的審核日誌，供日後追蹤系統演進。

---

## 2026-08-11：架構債務驗證與優先序確認

**事件編號**: EXEC-2026-08-11-001  
**類別**: Architecture Debt Fix Verification  
**狀態**: ✓ 已完成  
**總耗時**: 20 分鐘（預計 1 小時）

### 概要

針對 AgentOS 發現的三塊架構債務進行快速驗證，確認理論解法的可行性：

| 項目 | 理論解法 | 驗證結果 | 優先度 |
|------|--------|--------|-------|
| **Exp 1: 派工層依賴狀態正規化** | Stolos 風格的狀態枚舉 | ✓ PASS (已在系統內實現) | **P0** |
| **Exp 3: 能力路由與自動降級** | Pilotfish 風格的能力矩陣 | ✓ PASS (邏輯驗證通過) | **P1** |
| **Exp 2: 治理層快照刷新** | CDK Snapshot 風格 | ⏳ 未驗證 | **P2** |

### 驗證方法

1. **Exp 1 驗證** (`test_exp1_queue_normalization.ps1/py`)
   - 測試 6 種依賴狀態字串變體（pending_dependency, waiting_dependencies 等）
   - 結果：6/6 PASS
   - 結論：系統已在 `scripts/lib/dependency_status.ps1` 完整實現正規化

2. **Exp 3 驗證** (`test_exp3_capability_routing.py`)
   - 測試 5 種不同能力需求組合
   - 結果：5/5 PASS
   - 結論：能力路由邏輯可行，支援主路由/降級路由

### 新發現

- **P001**: Exp 1 的正規化邏輯已存在但系統仍卡住，根本原因需進一步追查
- **P002**: 執行環境 (Linux bash) 無 PowerShell，需 Windows 環境或轉譯方案

### 相關文件

- 詳細計畫: [`docs/execution/IMPLEMENTATION_2026-08-11-ARCHITECTURE-DEBT-FIX.md`](../execution/IMPLEMENTATION_2026-08-11-ARCHITECTURE-DEBT-FIX.md)
- Exp 1 測試: [`scripts/test_exp1_queue_normalization.ps1`](../../scripts/test_exp1_queue_normalization.ps1)
- Exp 3 測試: [`scripts/test_exp3_capability_routing.py`](../../scripts/test_exp3_capability_routing.py)

### 後續行動

1. **立即** (今天)：查清 Exp 1 為什麼系統仍卡住
2. **本週** (下週一)：在 Exp 3 的基礎上開新票實裝能力路由
3. **一個月內**: 評估 Exp 2 的快照刷新方案

### 簽核

- **計畫者**: Claude
- **執行者**: Claude  
- **驗收者**: Josh (待)
- **記錄時間**: 2026-08-11 16:57 UTC

---

**歷程說明**: 這份記錄後續作為系統決策的參考依據。如有相同問題重現或類似架構債務需要解決，可直接引用本次的驗證結果和測試腳本。

---

## 2026-08-12：派工死結三連環修復（Governance Gate → 依賴死結 → Verify Sandbox）

**事件編號**: EXEC-2026-08-12-001  
**類別**: Live Production Bug Fix（非模擬驗證，真實派工執行）  
**狀態**: ✓ 已完成，用真實 PASS 驗證閉環  
**背景**: 承接 EXEC-2026-08-11-001 的理論驗證，本次在真實系統上追查「Hermes Lite Phase 1 的 19 張工單為何全部卡住」，過程中發現三層獨立的根因，逐一修復並用真實派工結果驗證。

### 問題發現鏈（由淺入深，三層根因）

**第一層：Governance Gate 卡死全系統**
- **現象**：任何 `task_queue_runner.ps1` 啟動都在第一步被 `exit 22` 擋下，全系統零個 runner 進程存活
- **根因**：2026-08-11 執行了合規的 policy 文件搬家（`docs/DOCUMENT_POLICY.md` 規定 policy 類文件須放 `docs/governance/`），但 `scripts/sync_shared_governance.ps1` 第 22-23 行的硬編碼路徑清單沒同步更新，掃描器認定舊路徑上的文件「missing」，`drift_count=2` 把狀態壓到 `review_required`
- **修復**：更新 `sync_shared_governance.ps1` 路徑清單指向新位置，用 `-ApprovePaths` 核准 3 筆合理 drift（2 份搬家文件 + 腳本自身雜湊）進 baseline
- **驗證**：`governance_gate=passed`, `task_execution_allowed=true`, `drift_count=0`

**第二層：`Test-Approved` 自我循環死結（核心邏輯 bug）**
- **現象**：Gate 解除後，runner 能跑了，但依賴鏈仍然一張都不動（`tasks_executed=0`）
- **根因**：`task_queue_runner.ps1` 的 `Test-Approved` 函式在檢查「一個 build 工單是否可被依賴」時，會找到該 build 工單自己的 verify 工單，並要求該 verify 已經 PASS——但如果發起查詢的正是這個 verify 工單本身（標準的 `create_codex_verify_task.ps1` 產出模式：`depends_on` 指向自己要驗證的 parent），就變成「要等自己先通過才能開始」的死結，永遠無法解開
- **影響範圍掃描**：全庫符合此 pattern 的工單共 6 張，5 張正卡在 `waiting_dependencies`（全部集中在 hermes-lite-phase1，符合現象時間點）
- **修復**：`Test-Approved` 新增 `$RequestingTaskId` 參數（預設值為自己），當 `Find-Verify` 找到的 review 就是最初發起查詢的工單本身時，跳過「必須先 PASS」的要求，直接視為滿足
- **修復過程中的次生問題**：檔案無 UTF-8 BOM，Windows PowerShell 5.1 用系統 Big5 碼頁解析，中文註解的多位元組字元把原始碼的換行吃掉，導致大括號配對錯位（`eq=True` 卻沒有真的 `return`）——改用純 ASCII 註解、UTF-8 with BOM 寫回解決
- **驗證**：`child-01-index-pipeline-codex-verify` 真實從 `waiting_dependencies` 被 `Promote-Dependencies` 放行、實際派工執行完成（非模擬）

**第三層：Verify Sandbox 無可寫 Temp 目錄**
- **現象**：死結解開後，verify 真的被派工執行，但結果是 `NEEDS_HUMAN_DECISION` 而非 PASS
- **根因**：`codex_mode: verify` 固定用 `--sandbox read-only`，pytest 的 `TemporaryFile()`、`assert_governance_ready.ps1` 的寫入操作全部被擋，連測試蒐集階段都進不去
- **修復**：`dispatch_task_packet.ps1` 在 verify 分支新增臨時目錄建立邏輯，用 Codex CLI 原生的 `--add-dir` 旗標只開放這一個目錄可寫，同時把子行程的 `TEMP`/`TMP` 環境變數導向該目錄，執行完畢後清理
- **修復過程中的兩個次生 bug（均為本次修復自己引入，已定位並修正）**：
  1. **清理時機錯誤**：原指令把 `Remove-Item` 放在 `process.Start()` 的 `finally` 裡，但 `Start()` 是非阻塞的，會導致 Codex 才剛啟動、目錄就被刪掉。改到 `Invoke-BoundedProcess` 真正等到進程結束之後才清理
  2. **API Key 環境變數提早快照**：`$psi.EnvironmentVariables["TEMP"] = ...` 寫在「清空 `OPENAI_API_KEY`/`CODEX_API_KEY`」之前，導致 .NET 提早把 `ProcessStartInfo.EnvironmentVariables` 字典定型，後續清空 API key 的邏輯完全失效，Codex 子行程用了錯誤的 key 導致 `401 Unauthorized`。修正：把 TEMP/TMP 賦值搬到 API key 清空之後、`process.Start()` 之前
  3. **DryRun 洩漏**：temp 目錄建立邏輯原本在 `if (-not $DryRun)` 判斷之前，會在乾跑模式下建立永遠不清理的空目錄，已修正為只在非 DryRun 時建立
- **驗證**：重跑後 `status=completed`，無 401 錯誤，執行時間恢復正常（~1.5 分鐘），`verify_verdict: PASS`

### 端到端真實驗證結果

跑完整條 Hermes Lite Phase 1 依賴鏈（`workspace-write` 真實建置，非模擬）：

| 工單 | 狀態 |
|------|------|
| child-01-index-pipeline | completed |
| child-01-index-pipeline-codex-verify | completed（**PASS**） |
| child-02-evidence-precedence | blocked |
| child-02-evidence-precedence-codex-verify | completed（**NEEDS_HUMAN_DECISION**，新的獨立問題） |
| child-03-escalation-query | completed |
| child-03-escalation-query-codex-verify | completed（**PASS**） |
| child-04-cost-routing | waiting_dependencies（合理阻塞，非死結） |
| child-05-integration | waiting_dependencies（合理阻塞，非死結） |

**結論**：今天修復的三層 bug（governance gate 路徑、依賴自我循環死結、verify temp 目錄）全部經真實 PASS 驗證有效，`child-01`/`child-03` 是鐵證。鏈子在該停的地方正確停下——`child-04`/`child-05` 等待 `child-02` 是合理阻塞，不是新的死結復發。

### 新發現，留給下一批處理

1. **child-02 卡住的新問題**（獨立於今天修復的三個 bug）：verify sandbox 裡 Python 3.11 shim 不存在、Python 3.13 執行遭 `Access denied`、跳出 sandbox 執行 pytest 的審核機制會逾時。三個環境問題疊加，導致 verify 連跑都跑不起來（不是程式碼內容有問題，靜態證據支持 PASS）。
2. **P-1/P-3 dispatch tree**：尚未重新驗證是否受惠於今天的三個修復自動解鎖，需要另外重跑確認。
3. **queue-runner 自己的 verify 子票**：今天的核心邏輯改動（`task_queue_runner.ps1`）本身也需要走一次獨立 Verify 才算完整閉環，目前只驗證了它「產生的效果」（child-01/03 PASS），沒有驗證這支腳本改動本身有沒有通過正式 Verify。

### 修改檔案清單

| 檔案 | 修改內容 | 備份 |
|------|---------|------|
| `scripts/sync_shared_governance.ps1` | policy 文件路徑清單更新（`docs\` → `docs\governance\`） | 無（單行路徑修正） |
| `scripts/task_queue_runner.ps1` | `Test-Approved` 新增 `RequestingTaskId` 參數 + 自我循環防護；連帶包含先前未 commit 的依賴狀態正規化改動 | `task_queue_runner.ps1.backup-before-testapproved-fix` |
| `scripts/dispatch_task_packet.ps1` | verify 分支新增 `--add-dir` 臨時可寫目錄 + TEMP/TMP 環境變數導向 + 執行後清理 | `dispatch_task_packet.ps1.backup-before-verify-tempdir-fix` |

**Git 狀態**：以上兩個核心腳本的改動尚未 commit（repo 本身有大量既有未 commit 狀態與本次工作無關）。兩個備份檔仍保留在 `scripts/` 目錄，commit 前可決定是否清理。

### 治理紀錄

- `sync_shared_governance.ps1` 的 3 筆合理 drift（2 份搬家文件 + 自身雜湊）已用 `-ApprovePaths` 核准進 baseline
- `task_queue_runner.ps1` 這次改動（依賴正規化 + 自我循環防護）已用 `-ApprovePaths` 核准進 baseline
- `dispatch_task_packet.ps1` 這次改動尚未核准進 baseline（下一批處理時需一併核准，否則下次 gate 檢查會再次出現 operational drift）
- 目前 `governance_status=operational_review_required`（gate 允許範圍內），剩餘 6 筆既有 operational drift 不在本次範圍

### 簽核

- **執行**: Claude（主對話）+ code 執行端（Windows PowerShell 5.1，真實環境）
- **驗證方式**: 真實派工執行 + 獨立 Verify 結果（非自我宣稱）
- **記錄時間**: 2026-08-12

---

## 2026-08-13：child-02 Python Sandbox 環境修復（任務 #17 後續）

**事件編號**: EXEC-2026-08-13-001  
**類別**: Live Production Bug Fix（真實派工驗證）  
**狀態**: 🟡 部分完成——原始診斷範圍已解決，verify 本身仍 FAIL（新發現的獨立問題）

### 背景

承接 EXEC-2026-08-12-001 任務 #17：`child-02-evidence-precedence-codex-verify` 卡在 `NEEDS_HUMAN_DECISION`，根因是 verify sandbox（`--sandbox read-only`）從未開放任何含 Python 直譯器的目錄，pytest 連啟動都失敗。

### 修復方案與執行

**方向決策**：不採用「開放 hermes-agent 專案的 Python 環境」（會製造跨專案耦合），改為在 `E:\AgentOS` 底下自建一份**完全自包含**的 Python 環境：

1. 用 `uv python install` 抓取 python-build-standalone 的預編譯 CPython 3.13（relocatable，不依賴任何母安裝）到 `E:\AgentOS\.verify-python\`
2. 在其上建 venv（`E:\AgentOS\.verify-python-venv\`），確認 `pyvenv.cfg` 的 home 完全指向 AgentOS 內部路徑，不外流
3. 裝 pytest 進這個 venv
4. 確認因為這份 Python 完全落在 verify sandbox 原本就有的 `-C E:\AgentOS`（read-only 主工作目錄）授權範圍內，**不需要額外的 `--add-dir`**（`--add-dir` 只負責開放「可寫」目錄，不是「可讀」，這次要解決的是可讀/可執行問題，性質跟 8/12 那次的 temp 目錄修復不同）
5. 仍需解決「agent 怎麼知道有這個路徑」——在 `dispatch_task_packet.ps1` 組 verify prompt 處（~626-688 行）注入一句提示，告知未來所有 verify agent 這個現成直譯器的路徑，用既有的 `.Contains()` 防重複寫法
6. `.gitignore` 新增 `/.verify-python/`、`/.verify-python-venv/`（根目錄錨定，避免誤吃其他同名目錄）

### 驗證結果（真實派工，非模擬）

**原始問題確認解決**：verify agent 自己找到並使用了 `E:\AgentOS\.verify-python-venv\Scripts\python.exe`（不是自己亂猜 `py -3.13`），且成功執行、通過了 1 個不需要 `tmp_path` fixture 的測試。證明 standalone Python + venv 方案 + prompt 注入全部生效。

**但 verify 整體結果仍是 FAIL**：`verify_verdict: FAIL`，回歸測試 1 passed / 22 errors，22 個 error 全部是 `FileNotFoundError: No usable temporary directory found`（不是 assertion failure，不是程式碼邏輯錯誤）。

### 新發現：8/12 的 temp 目錄修復可能沒有真正傳遞進 codex 內部子行程

EXEC-2026-08-12-001 那次修的 `--add-dir <verifyTempDir>` + `$psi.EnvironmentVariables["TEMP"/"TMP"]`，是設在「`dispatch_task_packet.ps1` 啟動 `codex.exe` 這個外層行程」的環境變數上。查證 `DISPATCH_PROMPT.md` 完全沒有提到這個暫存目錄的存在——原本的假設是 codex.exe 的 sandbox 機制會把外層行程的 TEMP/TMP 原封不動傳給內部真正執行 pytest 的 sandboxed 子行程，這次證據顯示這個假設可能不成立。

**為什麼 child-01/child-03 沒有踩到**：它們的測試案例可能沒有用到 `tmp_path` fixture，所以沒有觸發這個問題；child-02 的 22 個測試全部需要暫存檔案，因此全部現形。

**影響範圍**：只影響 verify 模式底下需要寫暫存檔的測試案例，不影響本次已解決的「Python 完全找不到」問題。

**裁決（Josh，2026-08-13）**：今天不深挖這個新問題，記錄為追蹤項，留給下一批處理。理由：#17 的核心診斷目標（sandbox 連不到 Python）已用真實證據解決，這是主線任務；tmp_path 傳遞問題範圍更窄、屬於新的獨立層次，不該在同一天繼續往下追第四層坑。

### 已修改檔案

| 檔案 | 修改內容 | 狀態 |
|------|---------|------|
| `scripts/dispatch_task_packet.ps1` | 新增 verify prompt 注入，告知 agent 現成 Python 路徑；不涉及 sandbox 權限機制（`--sandbox`/`--add-dir`）任何一行 | ✓ 已核准進 baseline |
| `.gitignore` | 新增 `/.verify-python/`、`/.verify-python-venv/` | 不需核准——`.gitignore` 本來就不在治理追蹤清單內，不會產生 drift |
| `data/codex_tasks/.../child-02-evidence-precedence-codex-verify/TASK.md` | 重置狀態以重新派工 | 未 commit |
| `E:\AgentOS\.verify-python\`、`E:\AgentOS\.verify-python-venv\` | 新建的自包含 Python 環境 | 未 commit（已被 `.gitignore` 排除） |

### 任務 #17 最終狀態

**不算完成。** 原始診斷範圍（sandbox 完全連不到任何 Python）已解決並有真實證據；但 verify 工單本身因新發現的獨立問題（tmp_path 傳遞）仍為 FAIL。任務 #18（依賴鏈剩餘部分）繼續阻塞於此。

### 留給下一批

1. **tmp_path/TEMP 傳遞問題**（本次新發現）：需要比對 codex 內部子行程實際拿到的環境變數，確認是傳遞失敗還是被 codex 自己蓋掉
2. 沿用 EXEC-2026-08-12-001 遺留項：Verify 自己的 evidence 快照機制問題、P-1/P-3 未實際派工驗證

### 簽核

- **執行**: Claude（主對話）+ code 執行端
- **驗證方式**: 真實派工執行（非模擬），verify 結果非自我宣稱
- **記錄時間**: 2026-08-13

