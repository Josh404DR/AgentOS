# Hermes 生態系盤點與優化設計提案

date: 2026-07-10
author: Claude（Cowork session，指揮官模式；掃描由 3 個 fresh 搜尋 subagent 執行）
governance_version: 1.2.0
governance_hash: ad20e91afb53ef06800077f420f8f441e57eeea0e906794ff219e63f0ffe39c3
status: **Plan 產出，未經獨立覆核**——依 Workflow v1.2 Plan/Verify 分離，本報告需 fresh session（Codex Verify 或另一個 fresh Claude/Fable session）覆核盤點是否遺漏、設計是否可行後才能作為定論。
scope: 只盤點＋設計提案；本輪未執行任何替換、部署、刪除、封存動作。
revision: **r2（2026-07-10）**——依 Codex Verify 覆核結果（verdict: PARTIAL；(a) 盤點與 (b) F1–F6 證據 PASS、(c) §5/§7 實作邊界 FAIL）補強四點：§5 硬邊界條款（5.1）、§7 方案 A 的 schema/觸發點/id 對應驗證（7a/7b/7c）、escalation 統計更正（§2.3、§7）。仍為設計補強，不實作。

標示規則：**[已證實]** = 有檔案:行號或命令輸出佐證；**[推論]** = 由證據合理推導但未直接驗證；**unknown** = 拿不到。
檔名路徑選擇說明：本檔刻意放在 `docs\` 根目錄而非 `docs\claude_ops\`，因後者被 `sync_shared_governance.ps1:68-71` 動態掃描，新增檔案會立即造成 `not_in_baseline` drift 並 fail-closed 擋住所有工單派工。

---

## 1. 全貌：四條鏈

```
[A] 自啟動鏈（三條互不知情的 AtLogOn 排程，各延遲 30 秒）
    HermesGatewayAutostart ──> start.ps1 -SkipProxy ──> hermes.exe gateway run --replace（主，PLUGIN_MODE=task_only）
    HermesLiteAutostart    ──> start_hermes_lite.ps1 ──> hermes.exe gateway run --replace（lite 獨立 profile，PLUGIN_MODE=chat_only）
    AgentOS-Dashboard      ──> dashboard\start.ps1   ──> dashboard 前後端（port 8000/3000）

[B] 工單執行鏈（每則 Telegram 訊息 → plugin → 新開 PowerShell process）
    __init__.py（plugin）──> telegram_typed_dispatch_entry / local_file_task_worker / url_intake 系列
      ──> typed_dispatch / dispatch_task_packet ──> start_task_queue ──> task_queue_runner ──> workflow_supervisor

[C] 治理鏈
    assert_governance_ready.ps1（16 個呼叫者的共同閘門）──> sync_shared_governance.ps1（唯一狀態生產者）
      ──> data\governance\governance_baseline.json（唯一 baseline，僅 -ApproveBaseline 可寫）

[D] 「等 Josh」機制 ×2（並行、互不相通）
    escalations：write_escalation（status=awaiting_josh）→ Dashboard decide_escalation → RESOLUTION.json → supervisor 讀取 ✅ 迴路閉合
    raw intake：[成形] → data\tasks\draft-*\TASK.md（status=awaiting_josh_approval）→ （無任何讀取端）❌ 單向死路
```

核心結構性事實 **[已證實]**：治理閘門（鏈 C）只掛在鏈 B（工單執行）上；鏈 A（gateway 啟動/重啟）完全不經過治理閘門，也沒有任何自動機制把治理/prompt/plugin 變更送進正在跑的 gateway。

---

## 2. 逐腳本盤點

### 2.1 啟動/自啟動/監督鏈

| 腳本 | 用途一句話 | 現狀與證據 | 關係 | 優化建議與理由 |
|---|---|---|---|---|
| `start.ps1` | 啟動主 gateway（+可選 proxy、watchdog） | 正常。`logs\hermes-gateway.stdout.log` mtime 2026-07-10 12:20 有啟動 banner [已證實] | 被 HermesGatewayAutostart 排程呼叫；可啟動 watchdog.ps1 | 保留。缺點：無單實例檢查（僅靠 `--replace`，start.ps1:66-73）、不呼叫治理閘門、不部署 plugin——納入統一部署動作（§5）處理 |
| `start_hermes_lite.ps1` | 啟動 lite gateway（獨立 `hermes-lite` profile，Groq 聊天限流用） | 正常。log mtime 2026-07-10 12:12 [已證實]；每次啟動重新複製 typed-dispatch plugin（:90-93）並設 `AGENTOS_PLUGIN_MODE=chat_only`（:100）[已證實] | 被 HermesLiteAutostart 排程呼叫 | 保留。它的「每次啟動自動複製 plugin」是正確模式，反而該推廣到主 gateway（見發現 F4） |
| `register_hermes_autostart.ps1` | 註冊主 gateway 的 AtLogOn 排程 | 曾執行：registration log 2026-07-02 09:31 [已證實]；排程器現況 unknown | 註冊 → start.ps1 -SkipProxy | 保留。`-MultipleInstances IgnoreNew` 只防同任務重複觸發，不防跨腳本重複 |
| `register_hermes_lite_autostart.ps1` | 註冊 lite gateway 的 AtLogOn 排程 | 曾執行：registration log 2026-07-09 19:57，`task_name=HermesLiteAutostart, task_state=Ready` [已證實]；排程器現況 unknown | 註冊 → start_hermes_lite.ps1 | 保留。與主排程幾乎同時（AtLogOn+30s）觸發，見 §6 |
| `watchdog.ps1` | 迴圈監控 gateway 存活、故障重啟 | **失聯**：`logs\watchdog_state.json` updated=2026-06-20T12:30:17，停滯 20 天，而 gateway 7/10 仍有新啟動 [已證實] → 目前沒有 watchdog 在跑 [推論]。快照顯示 `mode=legacy-cli-py-gateway`、同時抓到 2 個 PID 歸為一個 gateway [已證實] | 由 start.ps1 -StartWatchdog 帶起（無排程直接觸發） | **修復或明確停用**。三個缺陷：偵測 regex（watchdog.ps1:35-41）無法區分主/lite/legacy 進程；重啟時不帶 `--replace`（:50）；重啟時不設 `AGENTOS_PLUGIN_MODE` → 新進程模式回退預設 `task_dispatch`（`__init__.py:18`），與 Josh 設定的模式不同且無日誌標示 [已證實] |
| `workflow_supervisor.ps1` | 工單樹巡檢：解 escalation 阻塞、判定 workflow 完成 | 呼叫鏈存在 [已證實]；近期是否常駐 unknown（依禁讀規則未展開 `data\queue_runs\`） | 被 plugin 的 `_run_workflow_supervisor`（`__init__.py:281-291`）反覆呼叫；每個 pass 先過治理閘門（:16, :182-187） | 保留。它是啟動生態中唯一確實掛治理閘門的環節 |
| `setup_hermes.ps1` | 一次性人工設定指引（純 Write-Host） | 無 log 可證 [已證實：無自動呼叫者] | 無 | 保留（文件性質） |
| `test_hermes.ps1` | 診斷：hermes --version + doctor | 純人工診斷 | 無 | 保留 |
| `sync_hermes_system_prompt.ps1` | 把 canonical system prompt（.txt）鏡射到 .md | **孤兒腳本** [已證實]：全 repo 無任何腳本呼叫它；且無任何程式碼路徑把該 prompt 餵進運行中的 Hermes（見發現 F2） | 無呼叫者 | 納入統一部署動作；同時把「prompt 是否真的被 hermes.exe 消費」列為下輪查證項（hermes-agent 在 repo 外，unknown） |
| `deploy_hermes_typed_dispatch_plugin.ps1` | 手動部署主 gateway 的 typed-dispatch plugin | 純人工、無呼叫者 [已證實]；自己印出 `gateway_restart_required=true`（:45）但不重啟 | 無呼叫者 | 納入統一部署動作（§5 的核心成員） |
| `memory_guard.ps1` | 機器維運工具（防誤殺 Hermes 進程），非啟動鏈成員 | 檔頭已標 OUT-OF-SCOPE/凍結（:1-4）[已證實] | 無 | 不動（依邊界不刪不封存；檔頭標記已足夠） |
| `dashboard\start.ps1` + `dashboard\register_autostart.ps1` | 第三條 AtLogOn 自啟鏈（dashboard 前後端） | dashboard log 7/10 14:02 仍在寫 [已證實] | 與 Hermes 兩條鏈平行、互不知情 | 保留；統一部署動作應把「三條鏈的存在」顯性化（列出目前排程清單） |

### 2.2 治理鏈

| 腳本 | 用途一句話 | 現狀與證據 | 關係 | 優化建議與理由 |
|---|---|---|---|---|
| `sync_shared_governance.ps1` | 掃 81 個受治理檔案、算 SHA256、比對 baseline、寫 governance_status；`-ApproveBaseline` 時覆寫 baseline | 正常且 fail-closed [已證實：:118-135]。baseline `approved_at=2026-07-10T12:06:59+08:00` [已證實]。與 `.bak-2026-07-10` 唯一差異＝新增 `docs\claude_ops\` 動態掃描（:68-71）[已證實] | 被 assert_governance_ready 呼叫；被 dashboard `/api/governance` 唯讀呼叫 | 保留。兩個結構問題見 F6：`-ApproveBaseline` 無程式碼層防護；動態掃描目錄新增檔會全域擋單 |
| `assert_governance_ready.ps1` | 所有派工的共同閘門，非 aligned 即 exit 22 | 正常 [已證實]。16 個呼叫者（typed_dispatch:16、dispatch_task_packet:265、task_queue_runner:16,423、workflow_supervisor:16,182、local_file_task_worker:11、url_intake×2、free_model_window:18、antigravity 系列、3 支 deprecated bridge 等） | 每次呼叫都是 fresh process、重新掃描重新算 hash → **閘門判定即時生效，不需重啟** [已證實] | 保留，這部分設計是對的 |

**「政策變更後系統何時真正套用」的程式碼實際行為**（本次盤點核心問題的答案）：

1. **閘門判定（擋/放）：即時**。每次派工新開 process 重算 hash，改 AGENTS.md 後下一個工單立刻感知（通常表現為 drift → 被擋，直到 `-ApproveBaseline`）[已證實]。
2. **治理文字內容進入 worker：即時**。`local_file_task_worker.ps1:209` 組 prompt 時明確要求 worker「Read E:\AgentOS\AGENTS.md first」，逐任務重讀 [已證實]。
3. **Hermes plugin 的訊息分類邏輯（regex 常數）：重啟才生效**。`__init__.py:28-53` 在 import 時載入為模組常數，常駐 gateway 不會重讀 [已證實]。主 gateway 還要先手動跑 deploy 腳本把新 plugin 碼複製過去，lite 則每次啟動自動複製 [已證實]。
4. **system prompt：無套用路徑**。改 `hermes_system_prompt_v2.txt` 唯一的下游效果是 hash 變動觸發 drift；repo 內沒有任何程式碼把它送進運行中的 Hermes [已證實，限 E:\AgentOS 範圍；hermes.exe 本體行為 unknown]。
5. **附帶事實**：lite gateway 以 `chat_only` 模式跑（start_hermes_lite.ps1:100），此模式下所有訊息直接走免費模型聊天，分類 regex 根本不執行（`__init__.py:713-717`）[已證實]——「改了分類規則要記得重啟」這件事，在目前 lite 的運作模式下其實是死碼路徑；真正吃 `task_only` 模式的是主 gateway。

### 2.3 dispatch/worker 鏈

| 腳本 | 用途一句話 | 現狀與證據 | 關係 | 優化建議與理由 |
|---|---|---|---|---|
| `typed_dispatch.ps1` | 純規則路由器：`[TYPE:...]` → 路由決策，不呼叫模型 | 正常 [已證實：輸出 ROUTING_DECISION.md, :203-221] | 上游 telegram_typed_dispatch_entry；過治理閘門 | 保留 |
| `telegram_typed_dispatch_entry.ps1` | Telegram 包裝器，轉呼叫 typed_dispatch | 正常；是 plugin `ENTRYPOINT`（`__init__.py:20`）[已證實] | 薄殼 | 保留（隔離層有存在理由） |
| `dispatch_task_packet.ps1` | canonical 單一工單執行入口（驗 governance→ 呼叫 Codex/Claude/…→ 寫 RESULT.md） | 正常 [已證實]。是唯一讀 `requires_josh_approval`/`approval` 欄位的執行閘門（:316-326），但讀的是 TASK.md 欄位，與 `awaiting_josh_approval` 狀態字串無關 | 被 queue_runner、local_file_task_worker 呼叫 | 保留 |
| `local_file_task_worker.ps1` | 自然語言工作 → classify → 建 TASK.md → 派工或落 escalation | 正常 [已證實] | 呼叫 classify/dispatch/start_task_queue/write_escalation | 保留 |
| `task_queue_runner.ps1` | 單一 root 的工單執行迴圈 | 正常；每個迴圈迭代重過治理閘門（:423-428）[已證實]；`logs\task-queue.log` 7/10 01:29 | 由 start_task_queue 背景啟動 | 保留。缺反向轉移：`escalation_required` 寫入後無腳本把它改回 `ready_to_route` [推論，未找到反例] |
| `start_task_queue.ps1` | queue runner 的 process 啟動器＋去重 | 正常；**全生態唯一有真正單實例保護的啟動器**（`data\queue_runs\<id>.json` + Get-Process + StartTime 容差，:36-56）[已證實] | 薄殼 | 保留；其單實例模式可作為 gateway 啟動鏈的參考實作 |
| `classify_task.ps1` | 純規則分類（Risky/Complex/Simple/unclear） | 正常 [已證實] | 被 local_file_task_worker 呼叫 | 保留 |
| `write_escalation.ps1` / `decide_escalation.ps1` | 寫「待決」（status=awaiting_josh）／寫 Josh 的 Dashboard 決策（RESOLUTION.json） | 活躍使用中：`data\escalations\` 磁碟現狀（2026-07-10 實測）：14 個 escalation directory、14 個 RESOLUTION.json；其中 Josh 決策 approve×10、stop×2，另 2 筆為 supervisor 以 `resolved_by_later_verify_pass` 自動補記（workflow_supervisor.ps1:123）[已證實]（r1 誤植「16 筆中 14 筆」，r2 更正） | 讀取端：dashboard main.py:869-905、workflow_supervisor:109-144 | 保留；這是 repo 內唯一閉合的核准迴路，approval 缺口方案應複用它（§7） |
| `write_task_metric.ps1` | 去重後 append METRICS_LOG.jsonl | 正常 | 被 queue_runner/supervisor 呼叫 | 保留 |
| `set_workflow_control.ps1` | Dashboard 的 pause/resume/retry 控制訊號 | 正常 [已證實] | supervisor 讀取 | 保留（是控制流，不是核准機制） |
| `hermes_claude_bridge.ps1` / `hermes_codex_bridge.ps1` / `hermes_tripartite_bridge.ps1` | 三方橋接測試（前兩支已標 DEPRECATED 2026-07-08 W20） | 非活躍 [已證實：檔頭標記] | 與 dispatch_task_packet 功能重疊 | 不刪不封存（邊界）；建議下輪由 Josh 決定是否移入 archive |
| `url_intake_worker.ps1` / `url_intake_task_packet.ps1` / `threads_url_intake.ps1` | URL/Threads 情報擷取管線 | 呼叫鏈完整、皆過治理閘門 [已證實] | plugin `_run_generic_url_pipeline` 依序呼叫 | 保留 |

---

## 3. 六個結構性發現（優化提案的依據）

- **F1 治理閘門只守工單、不守 gateway** [已證實]。`start.ps1`/`start_hermes_lite.ps1`/`watchdog.ps1`/兩支 register 全都不呼叫 `assert_governance_ready.ps1`。政策變更的「感知」發生在工單層（即時），「套用」發生在 gateway 層（需人工重啟）——中間沒有橋，橋就是 Josh 的記憶。這是穩定性問題的根因。
- **F2 system prompt 斷鏈** [已證實]。`sync_hermes_system_prompt.ps1` 無呼叫者，prompt 檔在 repo 內無消費者。「治理正本等級的 prompt」實際上只是一個會觸發 drift 的 hash 對象。
- **F3 watchdog 是殭屍設計** [已證實 stale + 推論 not running]。狀態停滯於 6/20、偵測 regex 混淆主/lite/legacy、重啟路徑會靜默改變 plugin 模式。現況它提供的是「有監控」的錯覺。
- **F4 主/lite plugin 部署不對稱** [已證實]。lite 每次啟動自動複製 plugin（永遠最新），主 gateway 靠人工跑 deploy 腳本（可能停在舊版）。`$env:LOCALAPPDATA\hermes\plugins\` 實際部署版本 vs repo 0.7.1：unknown（本機路徑不在 repo）。
- **F5 awaiting_josh_approval 是單向死路** [已證實]。寫入端存在（`__init__.py:251`，`[成形]` 觸發），讀取端經 7 組 pattern×全範圍搜尋確認不存在；`data\tasks\draft-20260710-122023-*` 今天就有一張卡在此狀態。與之相似的 escalation 機制（awaiting_josh）反而迴路閉合——兩套「等 Josh」機制名稱相近、命運迥異，是 Josh 誤以為核准機制存在的可能根源 [推論]。
- **F6 -ApproveBaseline 的兩面刃** [已證實]。(a) 無程式碼層存取控制，「只有 Josh 能核准」目前是純文件約定；(b) `prompts\`/`dashboard\`/`docs\claude_ops\` 動態掃描下，任何新增檔案造成的 drift 會擋掉**所有**後續工單而非只擋相關工單，解鎖又依賴人工記憶跑 `-ApproveBaseline`——這與 F1 合起來就是「治理變更 → 全域卡死 → 靠記憶解鎖 → 靠記憶重啟」的完整病灶。

## 4. 真冗餘 vs 各有存在理由

**看似冗餘但各有理由（不建議合併）**：`task_queue_runner` vs `workflow_supervisor`（執行迴圈 vs 跨 root 巡檢，層級不同）；`start.ps1` vs `start_hermes_lite.ps1`（不同 profile 隔離，成本/模型策略不同）；兩支 `register_*`（對應兩個獨立排程）；`telegram_typed_dispatch_entry`/`start_task_queue` 薄殼（隔離與去重職責）。

**真正冗餘或已死（但依邊界不刪不動）**：三支 bridge（兩支已標 DEPRECATED）；`memory_guard.ps1`（已標凍結/OUT-OF-SCOPE）；`watchdog.ps1` 現況（沒在跑、規則過時——是「該修或該明確停用」，不是「該刪」）。

**不是冗餘、是不一致（該統一）**：主/lite 的 plugin 部署方式（F4）；`start.ps1` 與 `watchdog.ps1` 的重啟參數差異（有無 `--replace`、有無 PLUGIN_MODE）。

## 5. 統一部署動作設計提案（本輪不實作）

**形態：單一冪等 PowerShell 腳本**（暫名 `scripts\apply_agentos_changes.ps1`），非 watcher、非 service。步驟全部複用既有組件：

1. `sync_hermes_system_prompt.ps1`（同步 prompt 鏡像）
2. `deploy_hermes_typed_dispatch_plugin.ps1`（部署主 gateway plugin，hash 驗證沿用其既有邏輯）
3. `sync_shared_governance.ps1`（無 -ApproveBaseline）→ 若有 drift：**停下**，列出 drift 清單，要求 Josh 互動式輸入確認字串後才代跑 `-ApproveBaseline`；預設絕不自動核准
4. 重啟兩個 gateway（`start.ps1 -SkipProxy`、`start_hermes_lite.ps1`），顯式設定各自 PLUGIN_MODE
5. 驗證段：檢查兩個 gateway log 出現新 banner 時間戳、plugin 來源/目標 hash 一致、`assert_governance_ready.ps1` exit 0；任一失敗 → 非零 exit + 明確錯誤
6. 附 `-DryRun` 參數（只報告將做什麼與目前 drift，不動任何東西）

### 5.1 硬邊界條款（r2 新增，不可繞過；違反任一條即為實作 FAIL）

- **D1 禁止自動核准**：本腳本**不得**在任何情況下自動執行 `sync_shared_governance.ps1 -ApproveBaseline`。**不得**存在任何可將核准改為非互動式的機關——包括但不限於 `-Force`、`-AutoApprove`、`-Yes` 類參數、環境變數、設定檔開關、或以預設值略過確認。此類參數**不得被實作**，而非「預設關閉」。
- **D2 drift 時唯一合法行為**：偵測到 drift 時，腳本**只能**（i）完整列出 drift 清單（路徑＋原因 missing/not_in_baseline/hash_changed）、（ii）以非零 exit code 停止後續一切部署與重啟步驟。**除非** Josh 於互動式 session 中逐字輸入包含當次 drift 檔案數的確認字串（格式建議 `APPROVE-BASELINE-<drift_count>`，數字不符即拒絕），**否則不得**代跑 `-ApproveBaseline`。確認字串必須每次依現況產生，**不得**可預先填入、參數傳入或從檔案讀取。
- **D3 非互動環境一律 fail-closed**：當偵測到執行環境為非互動（stdin 重導向、由排程工作/CI/其他腳本以 subprocess 呼叫、`[Environment]::UserInteractive -eq $false`），凡涉及 `-ApproveBaseline` 的分支**不得**進入確認流程，一律直接以非零 exit 停止並輸出 `apply_status=approval_requires_interactive_josh`。
- **D4 留痕**：每次實際代跑 `-ApproveBaseline` 前，必須先將 drift 清單與確認字串輸入事件寫入 append-only 稽核檔（建議 `data\governance\APPLY_AUDIT.jsonl`），**不得**先核准後補記。

（原 r1 流程描述之「要求 Josh 互動式輸入確認」精神不變，r2 將其升級為上述不可繞過條款；AGENTS.md §4「-ApproveBaseline 只可在 Josh 核准後執行」的文件約定由 D1–D3 首次獲得程式碼層級的對應強制。）

**為什麼是單一腳本而不是自動 watcher/常駐 service**：(a) 自動套用未經核准的治理變更會繞過 Josh 的核准邊界，與 AGENTS.md §4 精神相反——「需要人按一下」在這個系統裡是 feature 不是 bug；(b) 所有組件已存在且確定性，不新增需要被監控的常駐進程（系統已有三條自啟鏈＋一個殭屍 watchdog，不缺第五個）；(c) 單一入口讓「部署了什麼、何時部署」天然留痕。**取捨**：Josh 仍要記得跑一個命令，但從「記住 N 步驟＋順序」降為「記住一個名字」；且 Dashboard 可加唯讀提示（治理檔 mtime > 上次 apply 時間 → 顯示「有未套用變更」），把記憶負擔轉為可見訊號——此提示為下輪選配。

配套（同輪或下輪）：watchdog 修復三缺陷（regex 區分 profile、補 `--replace`、保存/還原 PLUGIN_MODE）或明確停用並在文件標記，二選一由 Josh 決定。

## 6. Hermes Lite 自啟與多實例風險（實測）

- **已證實**：排程註冊腳本行為（`Register-ScheduledTask "HermesLiteAutostart"`，AtLogOn+30s，register_hermes_lite_autostart.ps1:3,26-27,48-55）；註冊成功紀錄 `registered_at=2026-07-09T19:57:13+08:00, task_state=Ready, user=LAPTOP-IMPR60B8\brian, run_level=Limited`（logs\hermes-lite-autostart-registration.log）；7/10 12:12 lite gateway 實際啟動（stdout.log banner）。
- **推論**：7/10 12:12 的啟動與 AtLogOn 觸發相符，但 log 無法區分排程觸發或手動執行。
- **unknown**：Task Scheduler 目前即時狀態（工作是否仍 Enabled、LastRunTime/LastTaskResult）。本 session 的 shell 是隔離 Linux 沙箱，無法執行 `schtasks`。**補證命令（請 Josh 在 Windows PowerShell 跑一行）**：`Get-ScheduledTask HermesGatewayAutostart,HermesLiteAutostart,AgentOS-Dashboard | Get-ScheduledTaskInfo`
- **多實例撞車評估**：主/lite 並存是設計（不同 `HERMES_HOME`），7/10 兩者相隔 8 分鐘內都有啟動紀錄 [已證實]。同 profile 內重複啟動靠 `--replace` 頂替 [腳本碼已證實；hermes.exe 實際頂替行為屬外部專案，未驗，uncertain]。**真實風險點**是 watchdog：其偵測 regex 把主/lite/legacy 一律視為同一個 gateway（6/20 快照即抓到 2 個 PID 歸為一個，mode=legacy-cli-py-gateway）[已證實]——若 watchdog 被重新啟用而不先修 regex，就會出現「以為 gateway 活著（其實活的是另一個）」或重啟錯對象的撞車。兩 gateway 是否有 port 衝突：unknown（config 未見明確 port 欄位比對，未驗）。

## 7. Telegram 端 awaiting_josh_approval 缺口與方案（不實作，待 Josh 過目）

**缺口** [已證實，證據見 F5]：`[成形]` 產生的草稿工單沒有任何核准讀取端；Telegram plugin 無 approve 指令 handler（斜線指令一律 `return allow` 交還 Hermes 核心，`__init__.py:847,887`）；`workflow_supervisor`/`task_queue_runner` 只掃 `data\codex_tasks\`，不掃 `data\tasks\`。「核准後併入正式工單」（36_RAW_INTAKE.md:37）目前只能靠人工。

**方案 A（建議）：複用 escalation 迴路。** `[成形]` 建草稿時同步呼叫 `write_escalation.ps1` → Josh 在 Dashboard 按 approve（既有 UI，14 個 directory 的使用實績）→ `promote_draft.ps1` 把草稿轉寫為正式工單。優點：讀取端與 UI 已存在且經實戰驗證；核准動作留在 Dashboard（本機，`main.py:1210` 已有 `_require_local_request` 防護），不擴大 Telegram 外部輸入面。缺點：Josh 要開 Dashboard。r2 依 Codex Verify 指出的三個實作邊界補齊如下：

**7a. schema 變更（write_escalation.ps1 目前擋住 raw intake）** [已證實：`write_escalation.ps1:5` 的 `-Source` ValidateSet 只有 simple_fail/complex_fail/risky_task/classification_unclear/verify_needs_human；`:9` 的 `-DecisionType` ValidateSet 只有 approve_risky_action/clarify_requirement/accept_partial_delivery/stop_task/retry_with_changes——`raw_intake_approval` 兩個參數都不合法]

- **選項 a1（建議）：擴充 ValidateSet**。`:5` 新增 `"raw_intake"`、`:9` 新增 `"raw_intake_approval"`，各一行、向後相容。附帶的正確性紅利：`workflow_supervisor.ps1:110` 的自動 resolve 白名單 `@("verify_needs_human","simple_fail","complex_fail")` 不含 `raw_intake`，因此 raw intake 的 escalation **永遠不會**被「後續 Verify PASS」自動補記 resolved（`:120` 直接 continue）——核准權留在 Josh 手上，這正是想要的性質，不需額外防護碼。
- **選項 a2（不改 schema）：借用既有值**。`-Source classification_unclear` + `-DecisionType clarify_requirement`，以 `-Reason "raw_intake:<draft-id>"` 前綴＋`-Evidence` 放草稿 TASK.md 路徑來標記來源。缺點：語意污染（Dashboard 顯示的 decision_type 誤導）、下游全靠字串約定過濾、與 a1 的自動 resolve 隔離性質仍成立但屬巧合而非設計。
- **明確建議：a1**。兩行 ValidateSet 變更屬治理受管檔案修改，走正常工單＋`-ApproveBaseline` 流程即可。

**7b. promote_draft.ps1 的觸發點**

- **選項 b1（建議）：Dashboard backend 的既有 post-decision hook**。`main.py:1224-1228` 現況是：decision ∈ {approve, modify} 時立即代跑 `workflow_supervisor.ps1 -RootDispatchId <task_id>` [已證實]——post-decision 動作的掛載位**已存在**。設計：在同一處新增分支——當 escalation artifact 的 `decision_type == "raw_intake_approval"` 且 decision==approve 時，改為呼叫 `promote_draft.ps1 -DraftId <task_id>`（同樣走 `_run_control_script`，受 `_require_local_request` 保護）。一致性：核准事件與 promote 在同一因果鏈、同步執行，無輪詢空窗；延遲：即時（Josh 按下按鈕的同一個 request）；實作成本：約 10 行 Python＋一支新腳本。
- **選項 b2：workflow_supervisor 新增分支**。在 `Resolve-EligibleEscalations` 之外新增一個 pass：掃描 `decision_type=raw_intake_approval` 且 RESOLUTION.json decision=approve 且草稿目錄無 `PROMOTED.json` 標記者，呼叫 promote。一致性：supervisor 本來就是跨 root 巡檢者，語意上合理；**但延遲不可控**——supervisor 不是常駐 daemon，只在 Telegram 觸發工單或 Dashboard hook 時被跑到 [已證實：無排程直接觸發，見 §2.1]，若系統安靜，已核准的草稿會無限期等待；實作成本：新函式＋冪等標記＋要小心與 `:110` 白名單的互動。
- **明確建議：b1 為主**，promote_draft.ps1 設計為冪等（見 7c 的 PROMOTED.json 標記），未來若需要可把 b2 作為補漏掃描疊加，兩者不衝突。

**7c. promote_draft.ps1 的 id 對應驗證（防「核准 A 卻 promote B」）**

執行順序，任一步失敗即以非零 exit 停止、輸出 `promote_status=<原因>`、不寫任何檔：

1. **輸入正規化**：`-DraftId` 必須通過與 `write_escalation.ps1:18` 相同的 safe-id regex（`[^A-Za-z0-9_.-]+` 不得出現）且符合 `^draft-\d{8}-\d{6}` 前綴格式；來源路徑固定推導為 `data\tasks\<DraftId>\TASK.md`，必須存在。
2. **三方一致性核對**（核心防線）：(i) `data\escalations\<DraftId>\RESOLUTION.json` 存在且 `decision == "approve"`；(ii) 同目錄最新 escalation event JSON 的 `task_id` 欄位與 `-DraftId` **完整字串相等**（非前綴比對——`Test-UnresolvedEscalation:138` 的 `StartsWith` 式比對在此禁用，正是誤植風險所在）；(iii) 草稿 `TASK.md` 內文的自我宣告 id 行與 `-DraftId` 相等（配套：`__init__.py:251` 寫草稿時需同時寫入 `draft_id: <id>` 行——這是對 `_run_raw_intake` 的一行式變更，列入同一工單）。三者互相印證，缺一不可。
3. **目標防撞**：目標路徑 `data\codex_tasks\<DraftId>-promoted\TASK.md`；若已存在，拒絕執行（不覆寫、不加序號自動閃避——重複 promote 是異常，該報錯不該自癒）。
4. **governance 綁定**：呼叫 `assert_governance_ready.ps1`，通過後把 `governance_version`/`governance_hash` 寫入新 TASK.md（與 `dispatch_task_packet.ps1` 的預期欄位一致）。
5. **留痕與冪等**：成功後在草稿目錄寫 `PROMOTED.json`（記錄目標路徑、RESOLUTION.json 路徑、來源/目標 TASK.md 的 SHA256、時間戳）；草稿本體**不刪除不搬移**（安全邊界）。`PROMOTED.json` 同時是 b2 補漏掃描的冪等標記。

**方案 B（備選）：Telegram `/approve <draft-id>`。** 在 plugin 內攔截並比對 chat-id 白名單＋draft-id 精確匹配，寫 APPROVAL.json 留稽核再觸發 promote。優點：不離開 Telegram。風險：Telegram 是外部輸入面，指令偽造/誤觸的安全邊界需要 Josh 明確定義；且 lite 的 `chat_only` 模式下 plugin 分流是否會執行到 handler 需先驗證 [uncertain]。

無論選哪個，都建議一併補：escalation approve 後原工單 `escalation_required → ready_to_route` 的自動反向轉移（目前缺，approve 的語意只是解除 root 阻塞）[推論，詳 2.3]。

## 8. 行動建議（三行）

1. 只做一件事的話：先做 §5 統一部署腳本——它直接消除根因 F1（記憶依賴）並順手修 F2/F4，是所有發現的最大公約數。
2. 其次：§7 方案 A 給 Josh 定案——今天（7/10 12:20）已有一張草稿卡死在單向死路裡，缺口是現在進行式。
3. watchdog 修復或明確停用（F3）——殭屍監控比沒有監控更危險，因為它製造安全感。

## 9. 驗證狀態

- 本報告產出方式符合 10_DISPATCH_RULES：掃描由 3 個 fresh 搜尋 subagent 執行（metrics 已 append 至 `data\metrics\METRICS_LOG.jsonl`），主對話僅整合與短命令實測；`dispatch_degraded=false`。
- read-back 驗收：見本檔提交後的 fresh subagent 驗證結果（於對話回報）。
- **最終定論待 Codex Verify / fresh session 覆核**：重點覆核（a）盤點是否遺漏腳本或呼叫關係、（b）F1–F6 的行號證據是否成立、（c）§5/§7 設計的可行性與安全邊界。
- **r2 覆核狀態**：第一輪 Codex Verify verdict=PARTIAL——(a)(b) PASS、(c) FAIL（四點缺口）。r2 已補：§5.1 硬邊界條款 D1–D4、§7 的 7a/7b/7c 實作設計、escalation 統計更正（14/14/approve×10/stop×2）。r2 複驗範圍**只驗這四點**，不重驗 (a)(b)。
