# josh-resume 作品集更新 — 合併說明

這個資料夾不是完整的 repo，只包含**新增/修改**的檔案，因為 `josh-resume`
不在你的 `E:\AgentOS` 工作資料夾裡（它是獨立的 GitHub repo:
github.com/Josh404DR/josh-resume）。請把以下檔案複製進你本機的
josh-resume repo 對應位置，再 commit/push。

## 這次一次補齊的項目

1. 修正死連結（見下方「重要修正」）。
2. 全站 6 個頁面的 lucide icon 套件從 `@latest` 改成鎖定版本 `1.23.0`，並加上 `defer`——避免上游套件改版時網站圖示無預警壞掉，也不會擋住頁面渲染。
3. 加上 `unpkg.com`（圖示）與 `assets.mixkit.co`（首頁/DA 頁的背景影片）的 `preconnect`，縮短外部資源的連線建立時間。
4. 把 `index.html`、`da.html` 專案卡片裡寫死的 `style="color:#ff6b6b"` 這類 inline 顏色，改成 `.label-problem` / `.label-solution` / `.label-outcome` 三個 CSS class（定義在 `index.css` 尾端），視覺上完全沒變，但以後要換色只要改一處。
5. 沒有做的：SRI（Subresource Integrity）雜湊沒有加——因為這個環境沒辦法保證抓到的檔案位元組跟瀏覽器實際拿到的完全一致，隨便填一個雜湊反而會讓全站圖示直接壞掉，風險大於好處，先跳過。

## 重要修正（帳號改名導致的死連結）

實際查證後確認：`johnlearningsomesxit` 這個 GitHub 帳號**已經不存在**（可能是改名前
的舊帳號），你現在唯一有效、正在使用的帳號是 `Josh404DR`（7 個 repo 都在這裡，
包括 `josh-resume`、`ecommerce-market-intelligence-dashboard` 等）。

`index.html` 與 `da.html` 裡原本的 GitHub 聯絡連結都還寫死指向
`github.com/johnlearningsomesxit`——這是死連結，已經一併修正為
`github.com/Josh404DR`。

## 檔案清單與動作

| 檔案 | 動作 | 說明 |
|---|---|---|
| `index.html` | **覆蓋** repo 根目錄的 `index.html` | 唯一改動：把聯絡區塊死掉的 GitHub 連結從 `johnlearningsomesxit` 修正為 `Josh404DR`，其餘內容完全不變 |
| `da.html` | **覆蓋** repo 根目錄的 `da.html` | 在 Selected Projects 區塊最前面加入 3 張真實作品集卡片、導覽列加入「Portfolio」連結，並修正同樣的死掉 GitHub 連結 |
| `index.css` | **覆蓋** repo 根目錄的 `index.css` | 只在檔案「尾端新增」了作品集頁面用的 CSS class，原本的樣式一行都沒改 |
| `portfolio/index.html` | **新增**到 repo 根目錄下的 `portfolio/` 資料夾 | 作品集列表頁 |
| `portfolio/data-quality-audit-toolkit.html` | **新增** | 案例研究頁 1 |
| `portfolio/ecommerce-market-intelligence-dashboard.html` | **新增** | 案例研究頁 2 |
| `portfolio/ecommerce-operations-automation-pipeline.html` | **新增** | 案例研究頁 3 |

## 合併步驟

1. 找到你本機 josh-resume repo 的路徑。
2. 把上面 7 個檔案複製過去（`portfolio/` 是新資料夾，直接整個複製進去）。
3. `git status` 確認變更（`modified: index.html`、`modified: da.html`、
   `modified: index.css`、`new file: portfolio/*.html` 四項）。
4. `git add index.html da.html index.css portfolio/`
5. `git commit -m "Fix dead GitHub contact link (username change); add data analyst portfolio section"`
6. `git push origin main`

## 內容來源與注意事項

- 三個案例頁的數據都是直接從已經重新跑過一次的 pipeline 輸出讀出來的
  （GMV、AOV、Data Quality Score 等），不是編造的。
- GitHub 連結現在統一對應到你目前唯一在用的帳號：
  - `data-quality-audit-toolkit` → github.com/Josh404DR
  - `ecommerce-market-intelligence-dashboard` → github.com/Josh404DR
  - `ecommerce-operations-automation-pipeline` → github.com/Josh404DR
- `ecommerce-market-intelligence-dashboard` 案例頁附了一個 **Live Dashboard**
  連結（`https://josh404dr.github.io/ecommerce-market-intelligence-dashboard/`），
  這個連結要等你在該 repo 的 GitHub Pages 設定（Settings → Pages → Deploy
  from branch → `/dashboard` 資料夾）啟用後才會生效，目前還是「Reserved link」。
- `docs/WEBSITE_ROLE_SWITCH_REPORT.md`（你 repo 裡既有的內部文件）也記錄了舊的
  `johnlearningsomesxit.github.io` 網址，建議之後也更新成 `josh404dr.github.io`，
  這份文件我沒有放進這次的 staging 資料夾裡，需要你自己手動改。
- 三個案例頁與列表頁都沒有截圖／視覺化圖片（沙盒環境無法產生截圖），純文字
  + 既有的深色玻璃質感樣式呈現，之後可以自行補圖。
