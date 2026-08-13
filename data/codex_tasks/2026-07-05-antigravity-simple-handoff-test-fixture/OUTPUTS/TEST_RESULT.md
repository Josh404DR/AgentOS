# TEST RESULT

以下為實際執行且通過的測試項目：

## 1. 語法檢查 (PowerShell Parser Check)
- **測試命令**：
  ```powershell
  $tokens = $null; $parseErrors = $null; $null = [System.Management.Automation.Language.Parser]::ParseInput((Get-Content -Raw -LiteralPath 'E:\AgentOS\scripts\send_task_to_antigravity.ps1' -Encoding UTF8), [ref]$tokens, [ref]$parseErrors); $parseErrors.Count
  ```
- **測試結果**：`PASS` (0 errors)

## 2. 派工腳本 CopyOnly 模式測試 (Manual Handoff Mode)
- **測試命令**：
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\scripts\send_task_to_antigravity.ps1 -TaskPath E:\AgentOS\data\codex_tasks\2026-07-05-antigravity-simple-handoff-test-fixture\TASK.md -CopyOnly
  ```
- **測試結果**：`PASS` (exit code 0)。
- **收據驗證**：產生的 `ANTIGRAVITY_HANDOFF.json` 內容包含正確的 `pasted=false` 與 `submitted=false`。

## 3. 安全性阻攔測試 (Fail-Closed)
- **Role 角色檔缺失阻攔**：
  - **測試步驟**：暫時將 `E:\AgentOS\integrations\antigravity\AGENTOS_ROLE.md` 命名為 `AGENTOS_ROLE.md.bak` 後執行腳本。
  - **測試結果**：`PASS`。腳本正確拋出 `Required role file not found: E:\AgentOS\integrations\antigravity\AGENTOS_ROLE.md` 並阻斷。
- **工作區外部路徑阻攔**：
  - **測試步驟**：傳入非 `data\codex_tasks\` 目錄內路徑 `E:\AgentOS\AGENTS.md` 執行腳本。
  - **測試結果**：`PASS`。腳本正確拋出 `TaskPath must be located inside E:\AgentOS\data\codex_tasks\` 並阻斷。
- **萬用字元阻攔**：
  - **測試步驟**：傳入路徑中包含 `*` 萬用字元 `'E:\AgentOS\data\codex_tasks\*\TASK.md'` 執行腳本。
  - **測試結果**：`PASS`。腳本正確拋出 `Wildcards are not allowed in TaskPath.` 並阻斷。
- **非 TASK.md 檔名阻攔**：
  - **測試步驟**：傳入其它檔名 `'E:\AgentOS\data\codex_tasks\2026-07-05-antigravity-simple-handoff-test-fixture\OUTPUTS\RESULT.md'` 執行腳本。
  - **測試結果**：`PASS`。腳本正確拋出 `Filename must be exactly TASK.md` 並阻斷。

## 4. 自動化 GUI 貼上路徑狀態說明 (Live GUI Execution)
- 由於當前測試環境為非互動式背景進程，無法匹配到任何標題符合 `Antigravity` 的單一可見視窗。
- 腳本在匹配視窗數為 0 時符合 Fail-Closed 原則，正確安全阻斷，未執行 any paste or submit action。
- 自動化 GUI 貼上路徑屬於 **unverified**（未驗證）狀態。
