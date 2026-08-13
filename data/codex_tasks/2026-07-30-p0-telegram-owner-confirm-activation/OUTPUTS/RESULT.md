# P0 Telegram owner 手機核准啟用結果

dispatch_id: 2026-07-30-p0-telegram-owner-confirm-activation  
governance_version: 1.3.0  
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1  
governance_status: operational_review_required  

## 1. 環境變數設定方式與 scope

- 以 Windows User scope 寫入 `AGENTOS_OWNER_TELEGRAM_ID`，值在本報告固定表示為 `<REDACTED>`。
- privileged validation：`Configured=True`、`Numeric=True`、`Length=10`；完整值未寫入本檔。
- plugin 在 `__init__.py:105-109` 以 `os.getenv(...).strip()` 讀取 Process environment，並以 constant-time compare 比對 Telegram `source.chat_id`。
- User environment 更新不會回寫已存在 process 的 environment block；因此重啟時先從 User scope hydrate 到啟動 shell Process scope，再由 `scripts\start.ps1` 的 `Start-Process` 傳給 gateway。
- 首次重啟的 parent environment 沒有取得 User 值，手機指令落入一般 classifier；於 2026-08-04 09:23 修正 hydrate 後重啟，手機 `[待核准]` 成功列出項目，證明新 gateway 已取得設定。

## 2. plugin 載入證據

- source 與 deployed `__init__.py` SHA-256 均為 `A3449956B97B8B64AE611A898A9D944BF078DD3C660FBED9E5565A889CE18963`。
- source 與 deployed `plugin.yaml` SHA-256 均為 `DEE7B65DFECC07934FB0667E6ED74048C8A8E1E30B1087D6096F3E88ED26BC4C`。
- Hermes registry：`C:\Users\brian\AppData\Local\hermes\config.yaml:531` 明確 enabled `agentos-typed-dispatch`。
- runtime log：`C:\Users\brian\AppData\Local\hermes\logs\agent.log:24033`，2026-08-04 09:23:03 記錄 `AgentOS typed dispatch plugin v0.8.0 registered`。
- runtime log：同檔 `:24050`，2026-08-04 09:23:14 記錄 Telegram `Connected ... (polling mode)`。
- 以上是 registry、部署 hash 與 runtime registration 三組實證，不以 launcher 的「running」文字代替載入證據。

## 3. hermes-agent 側 Telegram 能力調查

### 收訊

- `gateway/platforms/telegram.py:1315` 的 `connect()` 支援預設 long polling 與 webhook；webhook 模式要求 secret，否則 fail-closed。
- connect 註冊 text、command、location/venue、photo、video、audio、voice、document、sticker 與 callback query handlers（約 `:1425-1448`）。
- text handler 在 `:4582` 建立 `MessageEvent`、清理 bot trigger，經短時間 buffer 後交給 gateway；command/media/location 也建成同一 event 型別。
- `MessageEvent` 的 Telegram source 包含 chat ID，plugin 用該欄位做 owner 比對，而不是 bot 名稱或 token。

### 發訊

- adapter `send()` 位於 `telegram.py:1670`，支援 MarkdownV2、plain-text fallback、長訊息分段、reply/thread metadata 與 transient network retry。
- 另有 draft/update prompt、execution approval、slash confirmation、clarify/model picker，以及 voice、multiple images、image、document、video、animation、typing 等發送能力（約 `:2253-3929`）。
- typed-dispatch `_send_reply()` 透過 gateway adapter 發送；本次手機實測確實收到待核准清單、拒絕與完成回覆。

### plugin 掛載

- `hermes_cli/plugins.py:790` 的 `discover_and_load()` 掃描 bundled、User `~/.hermes/plugins/`、條件式 project plugin 與 entry points；User plugin 必須列於 `plugins.enabled`。
- gateway `run.py:3747-3748` 呼叫 discovery；`run.py:6439-6465` 在 user-originated message 正常 dispatch 前 invoke `pre_gateway_dispatch`。
- deployed plugin 在 `__init__.py:1334` 註冊 `ctx.register_hook("pre_gateway_dispatch", _pre_gateway_dispatch)`；回傳 `skip` 時可在進入 LLM／一般 classifier 前完成 deterministic approval。

## 4. 端到端手機核准實測紀錄

- 新建 `f07-telegram-owner-confirm-e2e-fixture-20260804`，artifact 明確標記 `is_fixture=true`；因目前有 39 筆歷史 pending、長回覆排序／顯示限制使該筆未顯示於手機可見區，未用它做最後決策，也未刪除 append-only 證據。
- 最終改用既有且摘要明示 `Fixture only` 的 `2026-07-03-workflow-v1-2-dedupe-fixture`，避免對正式工作做 business decision。
- Josh 由 owner 手機帳號發 `[待核准]`，再以一次性六位碼發完整 `[確認 ... approve ...]`；bot 回覆決策完成。
- DECISION：`E:\AgentOS\data\escalations\2026-07-03-workflow-v1-2-dedupe-fixture\DECISION-20260804-092927-636.json`，SHA-256 `F4220BFE0CA105A27AE10768E65FF53568542E9D0D0A032878BCE2CE22B01D04`；`decision=approve`、`authentication_method=telegram_one_time_confirmation`，actor 以 `<REDACTED>` 表示。
- RESOLUTION：同目錄 `RESOLUTION-20260804-092927-636.json`，SHA-256 `5EDFC34D68BD2567417C9F533160F28F643FD9E31854A0EDD042AADFB8B69C07`；`decision=approve`、`josh_action_required=false`。
- AUDIT：`E:\AgentOS\data\escalation_audit\2026-07-03-workflow-v1-2-dedupe-fixture\AUDIT.jsonl:1`，2026-08-04 09:29:27 +08，`status=recorded`、`reason=verified_owner_receipt`、`authentication_method=telegram_one_time_confirmation`；檔案 SHA-256 `39EBF208993251C036DC40A02B7F62A53DB0E35EF8CED55EBE9AE1CB51BD86E3`。
- 未修改 plugin 或 `decide_escalation.ps1` 邏輯，未 commit／push。

## 5. 負面測試結果

- 精確 isolated rerun：
  `...\.venv\Scripts\python.exe -m unittest tests.test_telegram_escalation_confirmation.TelegramConfirmationTests.test_bad_expired_and_consumed_codes_are_rejected -v`
  結果 `Ran 1 test ... OK`；其中未消耗 confirmation 搭配錯誤六位碼精確拒絕為 `reason=confirmation_code_invalid`，並涵蓋 expired／consumed。
- 手機防重放：已成功消耗的 fixture 再以六位碼確認，bot 回覆 `reason=confirmation_already_consumed`。截圖證據：`OUTPUTS\MALFORMED_AND_REPLAY_TELEGRAM_EVIDENCE.png`，SHA-256 `A54991FD50E9B2AE91348CAFB03EC67DEA66B486BDE1AA454FC1B7750061CBAF`。
- non-owner：既有測試 `test_wrong_or_missing_owner_falls_through_without_escalation_reply` 在本次完整重跑中 PASS，證明錯誤／缺少 owner 不洩漏 escalation 內容而落回 ordinary chat。
- 完整 `test_telegram_escalation_confirmation.py` 本次結果為 5 tests、4 PASS、1 FAIL；FAIL 是 test temp fixture 未複製後來新增的 `scripts\lib\global_jsonl_lock.ps1`，造成 e2e decider fixture 啟動失敗。live 手機決策與 DECISION／RESOLUTION／AUDIT 不依賴該 temp-copy harness，故此 drift 不推翻 live success，但必須另票修測試。

## 6. 尚存限制

- UX bug：`[確認 ...]` 的 code 少於六碼時不匹配嚴格 regex，會落入一般工單入口並顯示 `task_intake_status=not_recognized`，而不是清楚提示「code 必須六位數」。本工單明文禁止修改已 Verify PASS 的 plugin，故未越界修正；應另開 plugin UX 修正工單。
- 使用已消耗 confirmation 測錯碼，只能證明防重放優先回 `confirmation_already_consumed`；錯誤未消耗六位碼由 isolated test 提供證據，不宣稱為本次手機 live invalid-code 證據。
- 待核准共有 39 筆歷史項目，清單可讀性與新項目顯示／排序不佳；本次不刪除歷史證據。建議另票加入 pagination、fixture filter 或 newest-first，而不在啟用工單修改行為。
- `start.ps1` 本身未主動從 User registry refresh 長壽 parent 的 environment；更新 User env 後，舊 shell 啟動仍可能缺值。本次以明確 hydrate 後 restart 解決。
- gateway runtime receipt reconciliation 對 profile lock PID 的判定仍警告不一致；plugin registration、Telegram polling 與手機 E2E 已由其他直接證據確認，但 receipt 問題應另查。
- 第一個 fresh independent read-only Codex Verify 判定 FAIL：builder 從截斷表格抄錯 DECISION／RESOLUTION 雜湊尾碼。artifact 內容與核心 AC 均通過；修正後第二個 fresh read-only verifier 重算一致並判定 PASS。完整失敗與重驗證據分別保留於 `OUTPUTS\VERIFY_RESULT_ATTEMPT1.md`、`OUTPUTS\VERIFY_RESULT.md`。

Acceptance checklist：

- pass：User-scope owner ID 持久化設定且報告遮罩。
- pass：plugin registry、hash、runtime registration 與 Telegram polling 實證。
- pass：Josh owner 手機完成一次真實 fixture confirm。
- pass：DECISION、RESOLUTION、AUDIT 對應且 authentication method 正確。
- pass：錯誤未消耗六位 code isolated negative test PASS；手機 consumed replay 拒絕。
- pass：Telegram 收發能力與 plugin hook mounting 調查完成。
- pass：更正報告後的第二個 fresh independent Codex Verify PASS。

## 7. Evidence Block（full 16 欄）

task_status: verified_by_codex  
claimed_by: Codex Builder  
artifact_status: artifact_created  
locally_verified: true  
verified_by_codex: true  
reviewed_by_claude: unknown  
approved_by_josh: true_for_task_activation_and_fixture_phone_confirmation  
cleanup_executed: fixture_clearly_marked_no_evidence_deleted  
live_external_action_executed: true  
files_modified: Windows User environment `AGENTOS_OWNER_TELEGRAM_ID=<REDACTED>`; append-only escalation fixture/index/confirmation/decision/resolution/audit runtime state  
files_created: `E:\AgentOS\data\codex_tasks\2026-07-30-p0-telegram-owner-confirm-activation\OUTPUTS\RESULT.md`; `E:\AgentOS\data\codex_tasks\2026-07-30-p0-telegram-owner-confirm-activation\OUTPUTS\MALFORMED_AND_REPLAY_TELEGRAM_EVIDENCE.png`; `E:\AgentOS\data\escalations\f07-telegram-owner-confirm-e2e-fixture-20260804\20260804-091848-000.json`; runtime DECISION/RESOLUTION/AUDIT artifacts listed above  
commit_hash: not_created  
evidence_paths: `E:\AgentOS\data\codex_tasks\2026-07-30-p0-telegram-owner-confirm-activation\TASK.md`; `C:\Users\brian\AppData\Local\hermes\logs\agent.log`; `C:\Users\brian\AppData\Local\hermes\config.yaml`; DECISION/RESOLUTION/AUDIT paths in §4; screenshot in §5; `OUTPUTS\VERIFY_RESULT_ATTEMPT1.md`; `OUTPUTS\VERIFY_RESULT.md`  
verification_commands: `scripts\assert_governance_ready.ps1`; privileged User environment validation; source/deployed SHA-256 comparison; Hermes runtime log/registry inspection; health check; targeted unittest negative rerun; DECISION/RESOLUTION/AUDIT JSON and SHA-256 inspection  
remaining_caveats: malformed five-digit UX falls through; full test file has temp-fixture lock-library drift; 39-item pending list usability; stale parent environment inheritance; runtime receipt reconciliation warning; first Verify failed on report hashes and remains preserved; corrected report passed second fresh Verify  
production_ready: false  

resource_contribution_summary:

- resource: Codex Builder; role: activation, diagnostics, local verification and report; contribution: environment persistence, restart, code/log/artifact inspection; artifacts: RESULT and screenshot evidence; cost_class: subscription; usage_basis: not_available
- resource: Josh; role: owner/manual external actor; contribution: supplied numeric identity and performed phone pull/confirm/replay; artifacts: Telegram messages and runtime decision artifacts; cost_class: manual; usage_basis: measured
- resource: Hermes local gateway; role: Telegram polling and deterministic plugin host; contribution: received commands, issued confirmations and invoked decider; artifacts: runtime log, DECISION/RESOLUTION/AUDIT; cost_class: local; usage_basis: measured

underused_resources: Claude review not requested by this task  
overused_resources: none identified  
api_cost_reduction_opportunities: approval path is deterministic and requires no model call  
next_allocation_recommendation: use a fresh Codex Verify session for blind read-only verification; open separate bounded tickets for malformed-command UX and stale test fixture  
