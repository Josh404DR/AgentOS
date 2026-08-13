# Upwork API 爬蟲使用說明

> ⚠️ **QUARANTINED — 2026-07-08**
>
> 此工具鏈已被平台封鎖（Cloudflare Turnstile 全面攔截，6/24 後零 qualified leads）。
> 繼續嘗試繞過有帳號封鎖風險。依據稽核報告 W24/W01，本目錄已隔離：
> - `scrape_upwork.py`：禁止執行，ToS 風險，已停用
> - `upwork_capture_auth.py` / `upwork_api_search.py`：保留為參考，但 daily patrol 已暫停
>
> **替代方案**：人工瀏覽 Upwork + 手動投遞。見 `data/josh_action_items.md`。

---

這套方案用 Playwright 攔截 Upwork 前端的 API 請求，繞過 Cloudflare Turnstile，
直接以 API 取得職缺資料，不依賴 HTML 解析。

---

## 檔案說明

| 檔案 | 說明 |
|------|------|
| `upwork_capture_auth.py` | Phase 1：用有頭 Chrome 登入，攔截並保存 auth |
| `upwork_api_search.py` | Phase 2：restore session，直接搜尋並輸出 Markdown |
| `scrape_upwork.py` | 舊版 HTML 爬蟲（保留備份，通常被 Turnstile 擋） |
| `data/upwork/private/upwork_state.json` | Playwright storage state（Phase 1 產出，勿手動修改） |
| `data/upwork/private/upwork_auth.json` | 攔截到的 headers 和 GraphQL response 範例 |

---

## 安裝依賴

```powershell
pip install playwright
playwright install chrome
```

---

## 使用流程

### Step 1：首次執行，取得 Auth（需人工操作，約 2 分鐘）

```powershell
cd E:\AgentOS
python tools\upwork\upwork_capture_auth.py
```

**你需要做的：**
1. Chrome 視窗打開後，**手動輸入帳號密碼**
2. **完成 Turnstile 驗證**（點選或等待）
3. 登入成功後，程式自動觸發搜尋、攔截 API，然後關閉

**產出：**
- `data/upwork/private/upwork_state.json`：下次可直接 restore，不用重新登入
- `data/upwork/private/upwork_auth.json`：攔截到的 headers 和 GraphQL response

---

### Step 2：日常執行（全自動，不需人工操作）

```powershell
python tools\upwork\upwork_api_search.py
```

**自動做：**
1. 載入 `upwork_state.json` 還原上次登入 session
2. 搜尋 Josh 的接案專長關鍵字（Google Apps Script 等）
3. 攔截 API response，整理為 Markdown leads 檔

**產出：**
- `data/leads/YYYY-MM-DD.md`：當天 leads，格式符合 Hermes 工作流
- `data/leads/YYYY-MM-DD.json`：JSON 備份

---

### 自訂搜尋關鍵字

**方法 A：命令列參數**

```powershell
python tools\upwork\upwork_api_search.py --query "Google Apps Script" "Sheets automation" --limit 30
```

**方法 B：設定檔**（建立 `config/upwork_search.json`）

```json
{
  "queries": [
    "Google Apps Script",
    "Google Sheets automation",
    "AppSheet",
    "Workspace automation"
  ]
}
```

若設定檔存在，`tools/upwork/upwork_api_search.py` 會自動讀取。

---

## Token 過期處理

Session 通常可撐 **數天到一週**。過期時程式會自動偵測並提示：

```
❌ Session 已過期，請重新執行 Phase 1：
   python tools\upwork\upwork_capture_auth.py
```

重跑 Phase 1 即可，約需 2 分鐘。

---

## 整合 Hermes（自動化每日 leads）

在 Hermes 的 cron 設定中，加入：

```
每天 08:00 執行 python E:\AgentOS\tools\upwork\upwork_api_search.py
```

Leads 會自動存到 `data/leads/YYYY-MM-DD.md`，符合 `workflows/ai_freelancer_os.md` 定義的格式，Hermes 可直接讀取。

---

## 技術原理

```
有頭 Chrome（非 headless）
    ↓ 正常 fingerprint，通過 Turnstile
    ↓ 登入成功
    ↓ 攔截 page.on("response")
    ↓ 保存 cookies + localStorage → upwork_state.json
         ↓
    下次用 storage_state= 參數 restore（headless 也行）
         ↓
    Playwright 在瀏覽器內發出 API 請求（headers 完整）
         ↓
    攔截 response → 解析 JSON → 輸出 Markdown
```

---

## 常見問題

**Q：Phase 2 也會被 Turnstile 擋嗎？**
A：通常不會。Turnstile 主要在登入和首次瀏覽時觸發。Restore session 後的 API 請求帶有完整 cookies，Cloudflare 視為已驗證的 session。

**Q：`upwork_state.json` 要怎麼保護？**
A：這個檔案等同你的登入憑證，不要傳到 git 或分享給他人。已加入 `.gitignore`（如果有的話）。

**Q：Phase 1 攔截到 0 筆怎麼辦？**
A：登入後在瀏覽器手動搜尋一次，確認職缺頁面有正常顯示，然後再重試。

---

## 版本紀錄

| 日期 | 說明 |
|------|------|
| 2026-06-25 | 初版，Phase 1 + Phase 2，response 攔截方式 |
