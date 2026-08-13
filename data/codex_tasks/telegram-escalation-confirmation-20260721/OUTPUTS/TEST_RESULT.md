# TEST_RESULT

dispatch_id: telegram-escalation-confirmation-20260721
test_status: PASS_WITH_ENVIRONMENTAL_NOT_RUN

## 實測結果

- `tests\test_telegram_escalation_confirmation.py`: PASS，5 tests；修正後完整 suite 連跑 5 次均 PASS。
  - 未設定/錯誤 chat_id：兩個指令均落回 ordinary chat，未洩漏 task_id 或 escalation 摘要。
  - `[待核准]`：兩個 task 產生各自不重複的 6 位數 code，寫入函式對每個 atomic temp 與 final path 均呼叫 owner ACL。
  - 非法 decision、錯誤 code、過期 code、已消費 code：均回傳精確 failure reason。
  - 端到端：temp AgentOS root 直接使用 scoped copy 的既有 `decide_escalation.ps1` 與 `escalation_receipt_validation.ps1`；產出 DECISION/RESOLUTION，`josh_action_required=false`。
  - 直接呼叫既有 `Test-AgentOSEscalationReceipt`: `ReceiptValid=true`, `ReceiptReason=verified`。
  - 直接呼叫既有 `Test-AgentOSEscalationDecisionRecord`: `RecordValid=true`, `RecordReason=verified`。
  - 同一 confirmation 重放：`reason=confirmation_already_consumed`。
  - 兩個並行合法 confirmation：每輪恰好一個成功，另一個為 `reason=confirmation_busy` 或 `reason=confirmation_already_consumed`；無 2/2 接受。
- `tests\test_escalation_decision_hardening.ps1`: PASS。
  - `no_receipt_rejected=true`
  - `forged_method_rejected=true`
  - `verified_owner_receipt_accepted=true`
  - `receipt_reuse_rejected=true`
  - `queue_invalid_decision_awaiting_josh=true`
  - `stored_decision_survives_receipt_expiry=true`
  - `historical_escalation_hashes_unchanged=true`
- `git diff --check`（本單兩個 source/test path）：PASS。

## 未執行

- `tests\test_dashboard_security.py`: NOT_RUN(environment)。Bundled Python 原始錯誤：`ModuleNotFoundError: No module named 'fastapi'`；既有 Hermes venv 原始錯誤：`No Python at '"C:\Users\brian\AppData\Local\Microsoft\WindowsApps\PythonSoftwareFoundation.Python.3.11_qbz5n2kfra8p0\python.exe'`。未安裝套件，未將此結果冒充 PASS。
