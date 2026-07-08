# Hermes Proxy 8080 狀態說明

status: blocked_known_reason
last_investigated: 2026-07-08
source: SETUP_STATUS.md + ARCHITECTURE.md

---

## 問題摘要

Hermes proxy 目標是在 `localhost:8080` 提供 OpenAI 相容 API，讓 Codex CLI 透過 `OPENAI_BASE_URL=http://localhost:8080/v1` 使用本地或免費模型。

**目前狀態：無法啟動（blocked）**

---

## 根本原因

1. **Hermes proxy 只支援 `nous` 和 `xai` 兩個 upstream adapter**，不支援 `claude`/`anthropic` 原生 adapter。
2. `nous` 和 `xai` 帳號均未登入，proxy 無法取得 upstream token，啟動後立即失敗。
3. `hermes gateway run` 與 `python cli.py --gateway` 是兩個不同進程：
   - `python cli.py --gateway`：legacy 手動進程，可在背景跑，但 Hermes cron/status 不認識它
   - `hermes gateway run --accept-hooks`：Hermes 官方排程閘道，需安裝為服務才能持續運行
4. `hermes.exe gateway status` 回報 `Gateway is not running`，即使 legacy 進程在背景執行

---

## 影響

- Codex CLI 無法透過本地 proxy 使用免費模型
- Hermes cron 任務不會自動觸發（除非手動跑 `scripts\start.ps1`）
- 目前 Telegram 工單走 typed_dispatch → 直接呼叫 Codex CLI，不依賴 proxy，**不受此 blocker 影響**

---

## 解法選項（未實作，等第一筆收入後再議）

| 選項 | 說明 | 成本 |
|---|---|---|
| 登入 nous/xai 帳號 | 最快但需要帳號 | 免費（若有帳號） |
| 改用 Ollama 作為 proxy upstream | Ollama 提供 OpenAI 相容 API on port 11434 | 0，已有 Ollama |
| 安裝 Hermes gateway 為 Windows 服務 | 解決 cron 問題 | 中等複雜度 |

**短期建議**：暫時不動，typed_dispatch 走直接呼叫路徑仍可用。需要 cron 時手動跑 `scripts\start.ps1`。

---

## 參考文件

- `docs/SETUP_STATUS.md` 第 79–115 行：proxy 設定嘗試記錄
- `docs/ARCHITECTURE.md` 第 313–341 行：已知 blocker 清單
