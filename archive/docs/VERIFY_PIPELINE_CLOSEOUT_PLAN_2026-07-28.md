# Verify Pipeline Closeout Plan — 2026-07-28

governance_source: E:\AgentOS\AGENTS.md
purpose: 收斂 2026-07-26 稽核衍生的 7 張工單 + 這兩天發現的 verify-bundle 產生器 bug，定義「真正做完」是什麼，並標明哪些步驟可以丟給 Codex 自動跑完、哪些不行。

## 最終結果（Definition of Done）

1. 2026-07-26 稽核衍生的 7 張工單，每一張最終狀態都是下列兩者之一：
   - 有一份「bundle 證據乾淨」的全新獨立 Codex Verify，且 verdict=PASS。
   - 或者有 Josh 明確記錄的例外/放棄決定（例如接受 RISKY_BUT_FUNCTIONAL，不強求 PASS）。
   不接受「Codex 自己在 plan session 內自稱獨立驗證 PASS」這種格式，也不接受工具產生假 bundle 撐出來的 PASS/FAIL。
2. `ci-smoke-stage-split` 的 7 個 child 走完整條 DAG，child-07 的 Verify 是真正獨立盲審 PASS。
3. `scripts\create_codex_verify_task.ps1` 和 `scripts\dispatch_task_packet.ps1` 目前已知的 bug 全部修完並經獨立 fresh Verify 驗收（見下方「已修復，待驗證」清單）。Production 路徑目前只會執行一套 bundle 產生邏輯，但 `dispatch_task_packet.ps1` 內仍物理保留 deprecated 的舊函式（未刪除，只是不再被呼叫）——這不等於「只有一份實作」，只是「只有一份會被執行」，清除 dead code 是後續可做但非必要的收尾項目。
4. 未來新票不會重演這一串問題：Builder 完成時會被提示交出 `changed_file:`/`change_required:` 清單（已經生效，只影響之後新派工的票，救不了已完成的舊票）。

## 已修復，但依 AGENTS.md 仍需獨立 fresh Verify 驗收（不能自稱「不需要再驗證」）

- `create_codex_verify_task.ps1`：untracked 新檔偵測、diff 編碼、Out-of-Scope 排除規則過粗、唯讀票 change_required 誤判、目錄候選誤診、`Get-GitStatusCode` 的 scalar/array 退化 bug、腳本尾端 `| Out-Null` 吞輸出。
- `dispatch_task_packet.ps1`：原生 `New-CodexVerifyTask`（4 個舊 bug）改為委派給已修好的 `create_codex_verify_task.ps1`（舊函式仍物理保留於檔案內，僅不再被呼叫）；重用過期 `AGENT_OUTPUT.md` 的 bug（Codex 秒退時誤用前一輪殘留內容當作本次結果）。

實際驗收方式：接下來對 4 張票（queue、dashboard-plane-naming-consistency、operational-drift-triage、escalation-fixture-classification）重新產生 bundle 並派工，本身就是這兩支腳本修復後的第一次真實試煉——如果全部順利產出乾淨 bundle 且沒有再冒出新 bug，視為初步驗收通過；正式獨立 Verify 仍以每張票各自的 Verify 結果為準，不把「腳本沒再出錯」直接等同於「已完成獨立驗證」。

## 環境備忘：CodexSandboxOffline 身分問題（Josh 2026-07-28 定位）

先前的 `Access is denied` 不是 codex CLI 安裝壞掉，是執行時的身分是受限的 `CodexSandboxOffline`，沒有權限讀取 `%APPDATA%\npm\codex.cmd`。往後任何會呼叫 `dispatch_task_packet.ps1`／`task_queue_runner.ps1` 的排程或自動化，都必須在 Josh 一般使用者 context 下執行，不能沿用這個受限 sandbox 身分，否則會重演同樣的 Access Denied。

## 可以讓 Codex 自己跑完的部分（走現有 pipeline，不需要我再開新票）

現有系統本來就設計成「Verify FAIL → 自動建立 revision 輪次交回 Builder → 最多兩輪 → 還是 FAIL 才升級給 Josh」（`task_queue_runner.ps1` 的 `New-RevisionTask`/`Update-ReviewFlowStates`）。只要 Verify 跑出真正的 FAIL（不是工具產生的假 FAIL），**不需要我手動另開修正工單**，讓 Queue 跑滿它自己的邏輯即可。

**重要**：要讓這個自動 revision 機制生效，`task_queue_runner.ps1` 的 `-RootDispatchId` 要指向**原始父票**（例如 `2026-07-26-queue-active-index-optimization`），不能只指向 verify 子票本身，否則 `Update-ReviewFlowStates` 掃不到父票，不會建立 revision。

適用票：
- `queue-active-index-optimization`：`cleanup_executed:false` 矛盾一旦被真正的 Verify 抓出來，理論上會自動產生 revision round 給 Codex 修正，不需要人工另開票。

## 純機械操作（不需要 Codex，我可以直接給指令）

1. 補跑 3 張遺漏 Verify 的 bundle + 派工（用已修好的腳本）：
   - `dashboard-plane-naming-consistency`
   - `operational-drift-triage`
   - `escalation-fixture-classification`
2. 用修好的腳本重新產生 `queue-active-index-optimization` 的 verify bundle 並派工（走上面的父票 scope，讓自動 revision 機制有機會生效）。
3. `docs-governance-status-autolink` 的 verify：一旦 `codex` CLI 的 Access Denied 排除，直接重派即可（bundle 本身已確認乾淨）。

## 只有 Josh 能決定的部分（2026-07-28 Josh 已授權 Claude 自行決定，見下方「已決定」）

1. **`ci-smoke-stage-split` child-06 的 fan-in 依賴**：現有 Queue 不支援逗號分隔的多重 `depends_on`。三個選項：
   - A：修改 Queue 核心程式碼原生支援 fan-in（Risky，需要正式核准精確範圍）。
   - B：人工閘門——等 child-02~05 全部完成後，手動把 child-06 的 `dispatch_status` 改成 `ready_to_route`。
   - C：改成純線性鏈（犧牲平行度，不建議）。

   **決定：B（人工閘門）**。理由：A 觸碰 Queue 核心且需另開 Risky 範圍核准，C 犧牲平行度且沒有實質好處；B 風險最低、不動核心程式碼。現況：child-02~05 都還卡在 `pending_dependency`（上游 child-01 尚未完成），此決定目前尚無法執行，等 child-02~05 全部 `task_status: completed` 後再手動把 child-06 的 `dispatch_status` 改為 `ready_to_route`。

2. **第三種 Codex 自產 Verify Bundle 格式去留**（`global-jsonl-append-lock`、`dashboard-plane-naming-consistency`、`operational-drift-triage` 三張票都有這種自稱「第 N 個獨立 Verify session」但證據指回自己 OUTPUTS 的格式）：

   **決定：不承認，一律discard，改走標準 pipeline**。理由：這些「獨立驗證」都發生在同一次 plan-mode session 脈絡內，不符合 AGENTS.md「驗證不自驗」要求的 fresh session 盲審。已對 `dashboard-plane-naming-consistency` 重新產生標準 bundle；`global-jsonl-append-lock` 尚未處理，待補。詳見 `docs\claude_ops\50_LESSONS.md` 2026-07-28 條目。

3. **Git commit 邊界政策**：`scripts\task_queue_runner.ps1` 這類共用檔案已經疊了好幾張票的未進版控變更，`git diff` 天生分不出哪段屬於哪張票。

   **決定：採納**——往後每張票 Verify PASS 後就 commit 該票 changed_file 清單。目前僅為政策方向，尚未寫成自動化（例如讓 `task_queue_runner.ps1` 在記錄 PASS 後自動 commit），具體自動化範圍與 commit message 格式留待下一張工單並讓 Josh 過目一次再落地，避免自動 commit 動到不該動的範圍。

## 建議執行順序

1. 你確認 `codex` CLI 是否恢復（Access Denied 排查）。
2. 我給指令，補跑 3 張遺漏 Verify + queue 那張，全部用父票 scope 派工。
3. 觀察哪些票真的自動產生 revision round，哪些卡住需要人工介入。
4. 你對上面 3 個「只有你能決定」的項目給方向，我照做。
5. 全部確認 PASS 或有你的例外紀錄後，這條收尾工作才算真正結束。
