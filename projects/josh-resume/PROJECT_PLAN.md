# Josh Personal Brand 網頁改造計劃

> **專案位置**: `E:\AI_Projects_Hub\Projects\Josh_Personal_Brand`
> **最後更新**: 2026-05-18

---

## 專案目標

將現有的 `Josh_Personal_Brand` 個人履歷頁面改造成一個更完整、現代且具品牌識別的個人網站，並保留 `html` 內現有 CV 與作品素材作為後續內容補充。此網站應該：

- 展示個人品牌形象與核心專長
- 清晰呈現 AI 產品工程師 / 系統架構師的專業定位
- 支援可下載履歷、聯絡方式與專案亮點
- 具備視覺吸引力且適合桌機、平板、手機瀏覽

---

## 核心任務

1. 重新整合頁面結構
   - Hero
   - About / Summary
   - Tech Stack
   - Experience
   - Projects
   - Contact / Resume

2. 強化用戶轉換
   - 新增導覽列與 CTA 按鈕
   - 明確呈現下載履歷連結
   - 補上聯絡區與連絡資訊

3. 內容優化
   - 以 `Professional_Resume_AI_Engineer.md` 的文字為基礎
   - 補充 `html/CV` 與其他展示資料中的專案亮點
   - 將內容轉成網站友善的視覺卡片與列表

4. 設計與視覺
   - 保留現有深色玻璃質感風格
   - 加入更清晰的按鈕樣式與導航
   - 增強行動裝置響應式佈局

---

## 近期改造內容

- 新增網站導覽列
- 製作「下載履歷」與「查看專案」按鈕
- 新增聯絡區塊與可快速觸發的 email / LinkedIn 連結
- 補強 `index.css` 的按鈕、導航與 mobile-friendly 樣式
- 新增 Hero 指標資訊卡、專業能力卡片與專案展示卡
- 使用 `html` 資料夾中的 CV 與 Apps Script 展示內容補強專案陳列
- 新增 `Demo` 連結，整合 `../html/CV/CV01.html`、`../html/CV/CVAI.html` 與 `../html/appscritp展示(CV用).html`
- 已新增 `Landing Animation Demo` 與 `AI Resume Demo` 專案卡
- 移除內聯樣式，統一頁面 CSS 類別

## 後續優化紀錄

- **[2026-05-22] 網站視覺與內容精進 (EXECUTION)**
  - **內容深化**：重寫「AI 整合產品開發」與「自動化影像與文案管線」專案描述，強調「工業級穩定性」、「斷點續傳」與「LLM Ops」等核心價值。
  - **視覺增強**：
    - 為 `.project-card` 與 `.btn` 加入玻璃質感 (Glassmorphism) 懸停特效、發光邊框 (Glow) 與縮放位移效果。
    - 重新設計 `.hero-metrics` 排版，加大間距、提升字級，並加入動態懸停背景，提升數據展示的權威感。
  - **架構優化**：優化 CSS 變數定義，提升過渡動畫 (Transition) 的流暢度。

- 可以將 `html/CV` 的互動式內容進一步整合為主頁項目卡片
- 建議補上更多專案說明、技術標籤與可視化成果圖
- 後續可新增完整雙語版本與部署說明

---

## 後續擴充建議

- 將 `html/CV` 裡的互動式 CV 模板轉換成單頁專案展示
- 新增專案作品頁（可依 `html/idea.demo` 與 `html/入場動畫` 內容擴充）
- 加入雙語版本（中/英文）
- 建立部署說明與 GitHub Pages 承載方案
