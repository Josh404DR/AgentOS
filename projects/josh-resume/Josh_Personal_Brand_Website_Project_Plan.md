# Josh Personal Brand + HTML 履歷網站整合計畫

> **版本**: v1.0.0
> **範本來源**: 參考 `E:\AI_Projects_Hub\Projects\AI_Tool\code_base\docs\PROJECT_PROGRESS.md`
> **最後更新**: 2026-05-18

---

## 🎯 專案目標

整合 `E:\AI_Projects_Hub\Projects\Josh_Personal_Brand` 與 `E:\AI_Projects_Hub\Projects\html` 兩個網站專案資源，打造一個更完整、專業且具品牌形象的個人履歷網站。此網站應該同時滿足以下需求：

- 展示 `Josh Personal Brand` 的簡潔現代履歷風格
- 導入 `html` 目錄中已有的 CV、展示頁與動畫素材
- 提供可下載的履歷、聯絡方式、技術專長與專案展示
- 支援響應式設計與清晰導航，適合求職或外部介紹使用

---

## ✅ 目前資源與優勢

### `Josh_Personal_Brand`
- 現成的 `index.html` 與 `index.css`
- 清楚的 Hero 區塊、專業摘要、技術棧、經歷等頁面結構
- 現代且商務感強的配色與版式
- 已涵蓋 AI 產品工程師 / 系統架構師定位

### `html`
- 多種履歷展示／AppScript 範例頁面
- CV 資料、簡歷內容、動畫展示等資產
- 專案內容可補強專業敘述與實作案例
- 可用於擴充「作品集」、「專案案例」與「主題展示」

---

## 🔧 合併策略

### 取長補短
- 以 `Josh_Personal_Brand/index.html` 作為網站主框架與視覺基底
- 從 `html/` 中取用：
  - CV 與作品展示內容
  - 互動 / 動畫效果範例
  - 業務導向敘事與使用場景描述
- 將 `Professional_Resume_AI_Engineer.md` 的核心資訊轉換成網站內文，作為 About / Resume / Expertise 區塊

### 主要優化方向
- 頁面結構統一：Hero → 總覽 → 技術 → 經驗 → 專案 → 聯絡
- 新增「下載履歷」與「作品集展示」按鈕
- 強化 mobile-friendly 響應式設計
- 加入簡單動畫與圖示，提高專業感與互動性
- 將 `html` 資料中的專案案例內容提煉成「實作亮點」

---

## 📌 需求與範圍

### 核心內容
- 個人簡介、職稱、聯絡方式
- 專業總覽與職能亮點
- 技術堆疊與工具
- 工作經歷與職務描述
- 代表專案與成就
- 聯絡表單或聯絡資訊區
- 可下載履歷／PDF

### 擴充內容
- AI 產品工程師專案案例
- RAG / LLM / Prompt Engineering 經驗說明
- AppScript 或自動化專案展示
- 視覺化專案列表與可點擊連結

### 非功能需求
- 支援手機與平板瀏覽
- CSS 視覺統一、字體與間距一致
- 載入速度輕量、圖片與動畫精簡
- 易於後續維護與更新

---

## 🧭 工作項目

### 1. 資產檢視與內容整理
- 檢查 `Josh_Personal_Brand/index.html`、`index.css`
- 檢查 `html/` 目錄中的 CV、展示頁、動畫與內容資料
- 將 `Professional_Resume_AI_Engineer.md` 轉為網站文案基底

### 2. 頁面結構規劃
- 定義最終欄位：
  - Hero
  - Professional Summary
  - Tech Stack
  - Experience
  - Projects / Portfolio
  - Contact
  - Resume Download
- 規劃導航與錨點

### 3. 視覺設計/版面整合
- 以 `Josh_Personal_Brand` 的主題配色與字體為基準
- 引入 `html` 目錄中的動畫或互動元素作為輔助
- 重新整理 CSS，保持類別語義清晰

### 4. 內容整合與寫作
- 將現有履歷內容轉換成網站文案
- 以條列式與卡片式呈現技術、職能、專案
- 新增「專案亮點」與「成果數字」

### 5. 建置與測試
- 開發 `index.html`、`index.css` 與必要的 JavaScript
- 測試桌機、平板、手機瀏覽效果
- 修正跨瀏覽器顯示問題

### 6. 發佈與後續維護
- 決定主站根目錄與部署方式（例如 GitHub Pages / 本地備份）
- 撰寫簡短 README 或部署說明
- 建立可持續更新的內容維護流程

---

## 🗂️ 建議成果檔案

- `Josh_Personal_Brand/index.html` -> 主頁面
- `Josh_Personal_Brand/index.css` -> 主題樣式
- `Josh_Personal_Brand/assets/` -> 可能新增的圖片與圖示
- `html/CV/` -> 履歷內容與下載檔案來源
- `html/idea.demo/`、`html/入場動畫/` -> 選取可用動畫效果
- `AI_Tool/code_base/docs/Josh_Personal_Brand_Website_Project_Plan.md` -> 專案計畫文件

---

## 🚀 交付項目

- 完整、合併後的個人履歷網站
- 簡潔專業的自我介紹與技術展示頁
- 一份可讀性高的專案計畫文件
- 可持續更新的專案資產清單

---

## ⚠️ 風險與待解問題

| 編號 | 風險 | 處理方式 |
|---|---|---|
| #1 | 現有 `html` 資料結構不一致，內容分散 | 將內容先集中至一份內容大綱，再決定最終頁面欄位 |
| #2 | 兩套風格可能衝突 | 以 `Josh_Personal_Brand` 主題為核心，`html` 資源做內容補強 |
| #3 | 可能缺少可下載 PDF 履歷或 CV 檔案 | 直接從 `Professional_Resume_AI_Engineer.md` 生成一份簡潔 PDF / 可下載 HTML |

---

## 📌 建議優先級

1. `Hero` + `Professional Summary` 整合完成
2. `Tech Stack` + `Experience` 內容補齊
3. `Projects / Portfolio` 以現有 `html` 專案內容充實
4. 響應式測試與手機優化
5. `Resume Download` 與聯絡區域完成

---

## 💡 後續擴充

- 新增「AI 工具實作」專案專區，展示 `AI_Tool` 與 `AppScript` 應用
- 增加多語系支援（中/英雙語履歷）
- 加入小型互動動畫與切換效果，提高訪客體驗
- 將履歷網站演進為多頁 Portfolio Site
