# TEST_RESULT — Hermes runtime config follow-up 6 files

dispatch_id: 2026-07-29-hermes-runtime-config-followup-6files
builder_test_status: passed_with_environment_entrypoint_caveat
tested_at: 2026-07-29 Asia/Taipei

## 實測結果

| 案例 | 實際結果 |
|---|---|
| Governance readiness | PASS；`governance_gate=passed`、`governance_status=operational_review_required`、`task_execution_allowed=true` |
| PowerShell parser（3 檔） | PASS；每檔 `errors=0` |
| Python compile（3 檔） | PASS；config 指定的 `hermes.python` 執行 `py_compile`，exit 0 |
| 舊 Hermes 硬編碼搜尋 | PASS；六檔匹配數 0 |
| Python loader 合約等價 | PASS；3 個新增 `_load_runtime_config` 與 `main.py` 的 AST 完全相同 |
| `check_db.py` 正常 config | PASS；實際 DB 路徑為 config 值，唯讀 schema/data 診斷 exit 0 |
| daily/audit 預設 DB | PASS；兩者載入後 `DEFAULT_DB` 均等於 config 的 state DB |
| Python fail-closed | PASS；三檔注入不存在的 `AGENTOS_HERMES_STATE_DB` 均以 `Hermes state_db not found`、exit 1 結束 |
| watchdog/model fallback fail-closed | PASS；兩檔於 loader 階段以 `Hermes state_db not found`、exit 1 結束，未進入業務動作 |
| replication 未傳 source | PASS；以不存在的 `SourceAgentOSRoot` 實測，錯誤明確指向該 root 的 `config\runtime.local.json` |
| replication source 覆寫 | PASS；明確傳入 `E:\ExplicitHermes` 時略過 config，輸出顯示該 source，之後因不存在的 Source AgentOS 安全停止 |
| replication target 獨立 | PASS；同次測試輸出 `E:\DifferentTargetHub\External_AI_Agents\hermes-agent`，未受 config Hermes root 影響 |
| audit `--db` 覆寫 | PASS；暫存 DB 實跑 exit 0，報告 Source DB 精確等於命令列覆寫值 |
| PowerShell UTF-8 BOM regression | PASS；`repository_scan_passed=true` |

## 未成立的第一次嘗試

系統 `python` 指向失效的 Hermes venv／WindowsApps shim，首次 compile exit 103，沒有形成語法判定。改用 `runtime.local.json` 中存在的 `hermes.python` 後 compile exit 0。

第一次 audit 覆寫測試因 sandbox 拒絕建立 `E:\tmp` 且 PowerShell 看不到 AppData DB，未形成覆寫判定。經核准在 sandbox 外只把 DB 複製到系統暫存目錄後，覆寫實測通過；未寫入 workspace。

## 限制

未直接執行 watchdog 正常路徑或 model fallback 正常路徑，因兩者可能啟動程序或呼叫模型；改以 parser、共用 loader 正常載入、caller fail-closed 與靜態 scoped diff 驗證。未執行 replication 完整複製，以兩個在任何寫入前安全停止的參數案例驗證 source/default/target 語意。

`py_compile` 產生三個 workspace `.pyc`。它們不是測試通過所需的唯一證據且可重建，但依治理規範未經 Josh 明確核准不得刪除；獨立 Verify 因 scope footprint 判定 `NEEDS_HUMAN_DECISION`。
