# RESULT

dispatch_id: telegram-escalation-confirmation-20260721
builder_status: completed_pending_independent_verify
verify_level: full_blind_verify
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1

## 實際變更

- 在 `integrations\hermes_plugins\agentos-typed-dispatch\__init__.py` 新增 `[待核准]` 與 `[確認 <task_id> <decision> <code>]` pull-mode 指令。
- 兩個指令均先以 constant-time 比對實際 `source.chat_id` 與 `AGENTOS_OWNER_TELEGRAM_ID`；未設定或不符時落回既有一般 chat 流程，不讀取或回覆 escalation 資料。
- 每個待核准 task 產生獨立 6 位數 code，10 分鐘到期，以 atomic replace 寫入 `data\dashboard_auth\telegram_confirmations\<task_id>.json`，並套用與 owner token 相同的 owner-only ACL 方式。
- code 對 task 綁定；錯誤、過期、已消費及非法 decision 均拒絕。正確 code 在 receipt/decision 嘗試前即原子標記 consumed，後續失敗也不可重放。
- 第 1 次 blind Verify 發現並行重放競態後，已完成第 1 輪 Builder 修正：以 owner-only、`O_CREAT|O_EXCL` lock file 將 read/check/consume 包成跨執行緒與跨程序的原子 claim；競爭者 fail-closed 為 `confirmation_busy`。
- receipt 使用既有 `decision-receipt.key`、既有 canonical 欄位順序及 HMAC-SHA256，receipt type 與 auth method 均為 `telegram_one_time_confirmation`。
- 使用既有 `scripts\decide_escalation.ps1` 完成決策，未修改驗證端。
- 新增 `tests\test_telegram_escalation_confirmation.py`，fixture 與 derived output 全在 OS temp。

## Josh 啟用步驟

此功能預設 fail-closed；Josh 必須設定自己的 Telegram `chat_id`，Codex 無法代為得知或猜測。

1. 從 Josh 的 Telegram 帳號傳一則訊息給目前連接 Hermes 的 AgentOS bot。
2. 在 Hermes 的 inbound event/log 中找到該訊息的 `source.chat_id`（plugin 正是讀這個欄位）。若使用自己的 Bot API token 查詢，可在 bot 未使用 webhook/polling 衝突時執行 `Invoke-RestMethod "https://api.telegram.org/bot$env:TELEGRAM_BOT_TOKEN/getUpdates"`，從 Josh 所傳訊息的 `message.chat.id` 取得數字；不要把 bot token 或輸出貼到聊天或交付文件。
3. 設定目前程序：`$env:AGENTOS_OWNER_TELEGRAM_ID='<Josh 的 chat_id>'`。
4. 若要保存為 Josh 使用者環境變數：`[Environment]::SetEnvironmentVariable('AGENTOS_OWNER_TELEGRAM_ID','<Josh 的 chat_id>','User')`。
5. 重啟 Hermes/plugin host，讓新程序讀到環境變數；先傳 `[待核准]`，再依回覆傳 `[確認 <task_id> approve|modify|stop <code>]`。

## 未解風險

- Dashboard security Python suite 因本機 bundled Python 缺少 `fastapi`、既有 Hermes venv interpreter 失效而未執行；本單未修改 Dashboard，紅線 hash 前後一致。
- 第 1 次 blind Verify verdict 為 FAIL（並行 code 2/2 被接受），已修正並等待第 2 個全新 read-only Codex Verify；目前不宣稱 verified 或 production-ready。
