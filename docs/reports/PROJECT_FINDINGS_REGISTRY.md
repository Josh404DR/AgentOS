# AgentOS 專案問題登記表（持續更新）

governance_parent: E:\AgentOS\AGENTS.md
用途：這是**唯一**持續累積的「已發現問題」清單，不論來源是哪一輪稽核
（`prompts\system_architecture_auditor_v2.md` 的 scoped-diff 驗收、
`prompts\system_architecture_auditor_v3_blind.md` 的獨立盲測、或工單執行中
臨時發現），都應該回填到這份文件，不要散落在各次對話或各張稽核報告裡自己
單獨存在。

與 `docs\governance\RISK_RULES.md` 的關係：`RISK_RULES.md` 是「什麼算
Risky」的規則定義（判準本身），**不是**問題清單；這份文件才是「目前已知有
哪些具體問題、狀態如何」的登記表。兩者不互相取代。

## 狀態欄位定義

- `open` — 已發現，尚未開工單。
- `ticketed` — 已開工單，尚未完成。
- `fixed_verified` — 已修正且經獨立 Verify PASS。
- `deferred_owner_decision` — 需要 Josh 本人決定是否要做，AI 不自行排入。
- `stale_needs_recheck` — 舊稽核的描述可能已經不準確（例如系統已經改了），
  下次稽核應該重新確認而不是照抄。

## 登記表

| ID | 來源 | 首次發現 | 描述 | 風險等級 | 狀態 | 關聯工單/證據 | 最後更新 |
|---|---|---|---|---|---|---|---|
| A01 | 2026-07-26 結構稽核 | 2026-07-26 | Dashboard/Hermes bridges/啟動腳本寫死 Hermes 路徑，跨 workspace/identity 耦合 | 中 | fixed_verified（原始9檔部分） | `2026-07-29-hermes-runtime-config-decoupling-build`（獨立Verify PASS） | 2026-07-29 |
| A01-follow-up | 2026-07-26 結構稽核 Plan 階段新發現 | 2026-07-29 | 另外6個檔案（check_db.py/watchdog.ps1/model_fallback.ps1/replicate_to_machine2.ps1/daily_token_cost_summary_noagent.py/hermes_usage_audit.py）與 scratch 副本同樣寫死 Hermes 路徑，本輪刻意排除 | 中 | fixed_verified | `2026-07-29-hermes-runtime-config-followup-6files-revision-1`（獨立Verify PASS：3個`.pyc`已刪除、母票6檔SHA-256前後一致、Evidence Block 16/16） | 2026-07-29 |
| A02 | 2026-07-26 結構稽核 | 2026-07-26 | docs-governance-status-autolink：README/ARCHITECTURE 治理版本手動複製 | 低 | fixed_verified | `2026-07-29-docs-governance-status-autolink-remediation`（獨立Verify PASS；原自稱PASS經查證為假，已用CORRECTION_NOTE.md誠實更正） | 2026-07-29 |
| A03 | 2026-07-26 結構稽核 | 2026-07-26 | operational-drift-triage：22筆 workspace drift 待分類 | 中 | fixed_verified | `2026-07-26-operational-drift-triage-revision-3`（獨立Verify PASS） | 2026-07-29 |
| A04 | 2026-07-26 結構稽核 | 2026-07-26 | escalation-fixture-classification：250筆escalation待分類(fixture vs真實決策) | 中 | fixed_verified | 已完成並送獨立Verify PASS（見本輪對話前段） | 2026-07-29 |
| A05/A10 | 2026-07-26 結構稽核 | 2026-07-26 | ci-smoke-stage-split：CI smoke 180秒逾時、pytest缺失，需拆分children | 高 | fixed_verified | `2026-07-26-ci-smoke-stage-split`：child-01~07全部獨立Verify PASS；child-07全域盲審最終確認：5個suite獨立可執行、fault isolation（單一TIMEOUT不影響後續suite）、Python launcher與缺pytest正確不誤報、ci-smoke-*預設隱藏/include_ci_fixtures可顯示；未宣稱production-ready | 2026-07-29 |
| A06 | 2026-07-26 結構稽核 | 2026-07-26 | queue-active-index-optimization：Queue全量重掃效能瓶頸(RR-OPS-001) | 高 | fixed_verified | 已完成兩輪修正(reparenting正確性+效能節流)，Dashboard escalation已於2026-07-29 15:22正式核准 | 2026-07-29 |
| A07 | 2026-07-26 結構稽核 | 2026-07-26 | global-jsonl-append-lock：JSONL寫入無鎖(RR-DATA-002) | 高 | fixed_verified | 已涵蓋Queue log/attempt log；`task_queue_runner.ps1`本身的加鎖屬本輪對話中Claude自行擴大範圍所做，已用addendum工單誠實揭露待Josh追認 | 2026-07-29 |
| F01 | v3盲測稽核 | 2026-07-29 | `runtime.local.json`/`main.py` 強制絕對路徑，缺乏跨機器遷移彈性 | 中 | fixed_verified | `2026-07-29-runtime-config-env-override`（獨立Verify PASS：四個環境變數PowerShell/Python行為一致，覆寫後仍執行fail-closed絕對路徑/存在性驗證，未設定時行為不變；Evidence Block欄位不全但Verify明定不影響本次驗收） | 2026-07-29 |
| F02-B1 | v3盲測稽核 | 2026-07-29 | Dashboard 直接 `sqlite3.connect` 讀 Hermes state.db，資料層耦合（A01已修路徑層，未修資料層）—— B1（Hermes SessionDB新增2個唯讀方法）子項 | 中 | fixed_verified | `2026-07-29-f02-b1-hermes-sessiondb-metrics-methods`：第3輪獨立Verify PASS（6/6達成）；環境修復票`2026-07-29-f02-b1-hermes-test-env-fix`誠實回報`partially_completed` | 2026-07-29 |
| F02-B2 | v3盲測稽核 | 2026-07-29 | 同上——B2（Hermes Gateway新增2個metrics GET route，Bearer驗證） | 中 | fixed_verified | `2026-07-29-f02-b2-hermes-metrics-api-routes`：獨立Verify PASS（9/9達成，284 tests含既有API server回歸皆通過，diff僅含核准的2檔案，Bearer fail-closed、503/500不洩漏內部資訊）；Verify另指出Claude工單AC裡「空DB回503」寫錯（應為200零值DTO），實作與驗證皆正確依PLAN.md，屬工單文字瑕疵非程式問題 | 2026-07-29 |
| F02-B3 | v3盲測稽核 | 2026-07-29 | 同上——B3（Dashboard main.py改呼B2 API，移除直連sqlite3/HERMES_DB） | 中 | fixed_verified | `2026-07-29-f02-b3-dashboard-hermes-http-client-round3`：第3輪獨立Verify PASS（8/8達成）——wildcard host(0.0.0.0/::/[::])改為明確fail-closed；SCOPED_DIFF.patch改用`generate_scoped_diff.py`重新產生；28 passed+UX/orphan guard PASS；Round1/2失敗證據皆保留未覆寫。**B3是直接cutover，已刪除main.py的sqlite3 import/HERMES_DB常數，沒有保留migration flag雙軌並存** | 2026-07-29 |
| F02-B4 | v3盲測稽核 | 2026-07-29 | 同上——B4（Live整合冒煙測試，範圍已依B3實際交付調整） | 中 | fixed_verified | `2026-07-29-f02-b4-live-integration-smoke`：獨立Verify PASS（8/8達成）——真實143 sessions資料、Gateway斷線時兩路由優雅降級(200+`usage database unavailable`，非500)且不阻擋`/api/tasks`、恢復後不需重啟Dashboard；**發現殘留缺口**：Hermes `API_SERVER_ENABLED/HOST/PORT/KEY` 目前只是本次測試的程序環境變數，非持久化設定，機器/Gateway重啟後API server不會自動啟用，需另開工單做持久化部署設定才算真正production-ready | 2026-07-29 |
| F14 | F02-B4驗證時發現 | 2026-07-29 | Hermes Gateway的`API_SERVER_ENABLED/HOST/PORT/KEY`只在程序環境變數存在，非持久化設定；F02整條鏈路(B1-B4)雖然功能上都PASS，但服務重啟後API server不會自動啟用，導致Dashboard又會退回不可用狀態 | 中 | fixed_verified | `2026-07-29-f14-hermes-api-server-persistent-config`：第2輪fresh Verify PASS(9/9)——設定改存Windows User-scope環境變數(256-bit key)，watchdog.ps1新增`Set-HermesApiServerEnvironment`啟動前hydrate+fail-closed驗證，Dashboard client支援HKCU fallback；洩漏掃描0筆、regression 28 passed；第1輪Verify因隔離帳號看不到`brian` HKCU/排程任務誠實回報`部分成功`，未隱瞞；**未commit，未測真正reboot，`production_ready=false`** | 2026-07-29 |
| F03 | v3盲測稽核 | 2026-07-29 | 原描述「task_queue_runner.ps1 每輪全量掃描O(N)瓶頸」 | — | stale_needs_recheck | 已於本輪對話修正為節流版全量掃描(`FullSweepIntervalSeconds`)，v3報告未讀到這個既有修正，描述已過時，下次稽核應重新確認 | 2026-07-29 |
| F04 | v3盲測稽核 | 2026-07-29 | `main.py` 背景 thread 執行 `KNOWLEDGE_INDEX.reconcile` 可能佔用GIL/CPU | 中 | fixed_verified | `2026-07-29-knowledge-reconcile-overlap-guard-revision-1`（獨立Verify PASS：真實耗時wall 2.357s/CPU 2.281s、重疊防護與例外釋鎖皆有實測、2個核准的`.pyc`已刪除、main.py SHA-256一致） | 2026-07-29 |
| F05 | v3盲測稽核 | 2026-07-29 | `decide_escalation.ps1` 的 `Write-DecisionAudit` 寫入 AUDIT.jsonl 未加全域鎖 | 高 | fixed_verified | `2026-07-29-escalation-audit-jsonl-lock`（獨立Verify PASS；20-process並發21/21合法、鎖逾時pending fallback正確、既有125行regression PASS） | 2026-07-29 |
| F06 | v3盲測稽核 | 2026-07-29 | `collect-runtime-status.ps1` 有空的 `catch {}` 靜默吞例外 | 中 | fixed_verified | `2026-07-29-observability-silent-catch-fix-revision-3`（第4輪獨立Verify PASS：scoped diff與git diff完全吻合、三情境真實stdout、Evidence Block 16/16且邏輯一致；前3輪皆因證據包裝問題FAIL，程式碼本身自第1輪起就是對的） | 2026-07-29 |
| F07 | v3盲測稽核 | 2026-07-29 | Escalation 驗證僅憑本機 receipt SHA256，缺乏非對稱金鑰簽章 | 高 | fixed_verified（既有機制） | 發現 AgentOS 已有 `telegram-escalation-confirmation-20260721` 工單（2026-07-21獨立Verify PASS），提供 Telegram 一次性確認碼作為第二層驗證，效果類似非對稱簽章訴求；只需 Josh 設定 `AGENTOS_OWNER_TELEGRAM_ID` 並重啟 Hermes 即可啟用，不需新開發；**已於2026-08-04啟用並實證**：`2026-07-30-p0-telegram-owner-confirm-activation`第2輪fresh Verify PASS（6/6）——Josh手機真實完成一次approve，DECISION/RESOLUTION/AUDIT齊備且`authentication_method=telegram_one_time_confirmation`；第1輪Verify因報告hash抄錯誠實FAIL保留。衍生3個待開小票：五位code誤導UX、test fixture缺global_jsonl_lock.ps1、39筆pending清單可讀性 | 2026-08-04 |
| F08 | v3盲測稽核 | 2026-07-29 | `assert_governance_ready.ps1` 顯示 `operational_review_required`，drift_count=33 | 低 | open（資訊性） | 對應既有 operational_review_required 狀態，非新問題 | 2026-07-29 |
| F09 | v3盲測稽核(交叉核對) | 2026-07-26（v3只是重新確認） | CI smoke 逾180秒 timeout | 高 | fixed_verified（同A05） | 同 A05/A10 | 2026-07-29 |
| F10 | v3盲測稽核(交叉核對) | 2026-07-26（v3只是重新確認） | Python環境缺pytest，單元測試無法自動化 | 中 | fixed_verified（同A05） | 同 A05/A10 | 2026-07-29 |
| F11 | evidence-contract-baseline-drift-check | 2026-07-29 | `docs\EVIDENCE_AND_REPORTING_CONTRACT.md` 第7節（Codex/Claude角色定位、獨立驗證義務）與Evidence Block分級規則等，工作目錄現況與git已提交版本有4處實質語意差異，尚未commit | 中 | fixed_verified | `2026-07-29-evidence-contract-baseline-drift-check`；Josh核准commit；commit `0e0dd87`「docs: commit EVIDENCE_AND_REPORTING_CONTRACT.md role realignment (F11, Josh-approved 2026-07-29)」；過程中發現`progress_log.md`相對HEAD是整份重寫(161ins/2510del，違反append-only)，經HEAD備份比對後改為機械式重建（HEAD原文+現有7/05~7/29紀錄，0刪除、105 insertions），才納入本次commit | 2026-07-29 |
| F13 | F02-B3 Verify過程中發現 | 2026-07-29 | `dashboard\backend\` 目前不在 git 追蹤範圍內，導致 SCOPED_DIFF.patch 產生工具連2輪都損壞（token截斷、`[object Object]`序列化污染），Verifier只能逐檔比對live內容，無法用標準git diff稽核 | 低 | fixed_verified | `2026-08-04-f13-dashboard-backend-git-tracking`：fresh Verify PASS——commit `e9c8864`僅含.gitignore+6個backend檔，secret/.venv/pyc/sqlite/auth均未納入 | 2026-08-05 |
| F12 | F11 commit過程中發現 | 2026-07-29 | `progress_log.md` 開頭「歷史記錄（2026-06）已歸檔至`data\progress_archive\progress_log_2026-06.md`」這個歸檔動作本身從未commit過；git HEAD仍是完整2512行6月歷史，archive檔內容已比對確認與HEAD吻合，只是這個「trim+archive」重構本身還沒有正式進版本歷史 | 低 | deferred_owner_decision | 已用`progress_log_HEAD_2026-07-29.md`（存於`data\progress_archive\`）備份確認archive檔內容完整無誤；是否要把這個trim正式commit（單獨、有說明的commit，不與其他改動混在一起）留給Josh之後決定，不影響目前功能 | 2026-07-29 |

## 使用方式

- 每次稽核（v2或v3）完成後，把新發現的項目加進這張表，已有的項目更新狀態欄。
- 開工單時把 `dispatch_id` 填進「關聯工單/證據」欄；工單完成並經獨立
  Verify PASS 後，狀態改成 `fixed_verified`。
- 稽核報告裡如果有跟這張表衝突的描述（像 F03 這種案例），不要直接改稽核
  報告本身，而是在這張表標記 `stale_needs_recheck` 並寫清楚為什麼，讓下次
  稽核知道要重新確認。
