# 許秉桂 (Josh Hsu) | Senior AI Product Engineer / AI System Architect

資深 AI 產品工程師 | 專精於 LLM 產品化、自動化管線與工業級穩定性架構

- **Email**: pkg0530hsu@gmail.com
- **Phone**: 0920-128-055
- **LinkedIn**: [您的 LinkedIn 連結]
- **GitHub**: [您的 GitHub 連結]
- **Location**: 台灣

---

## 專業總覽

具備深厚的 AI 應用開發經驗，擅長將尖端技術（如 LLM、RAG、生成式影像）轉化為可商業化的穩定產品。目前專注於打造工業級 AI 電商自動化工具，成功將繁瑣的商務攝影與行銷文案流程自動化。

### 核心優勢
- **產品化思維**：不只停留在 PoC，更強調系統的斷點續傳、錯誤彈性與跨平台部署。
- **Prompt Engineering 專家**：開發 V6 級別的多場景、結構化 Prompt 框架，精確控制 AI 生成品質。
- **全端技術整合**：具備從後端邏輯核心（Python/YAML）到前端互動介面（CustomTkinter）的端到端開發能力。

---

## 核心技術棧

### AI & Data Science
- **LLM/GenAI**: Google Gemini (google-genai), OpenAI API, Prompt Engineering (結構化 Prompt 框架開發).
- **Computer Vision**: OpenCV, Pillow, Rembg (背景去除), ONNX Runtime.
- **Data Tech**: Trino (分散式查詢), Pandas, NumPy, Openpyxl.
- **RAG**: Sandbox-RAG 實驗與檢索增強生成架構設計.

### Software Engineering
- **Languages**: Python (主要), YAML (工作流配置), SQL, Batch / Shell Scripting.
- **Architecture**: Modular Design (模組化設計), YAML-driven Workflow Engine, Checkpointing (斷點續傳機制).
- **Tools**: PyInstaller (跨平台封裝), Git, python-dotenv, Aiohttp (非同步請求).
- **Infrastructure**: Cloud Sync Integration (OneDrive / SharePoint), 類 CI/CD Build Pipelines.

---

## 專業經歷

### AI 產品開發負責人｜核心 AI 工具開發與維護 (202X – 現在)
主導開發一套工業級 AI 電商行銷自動化平台，解決大規模商品圖像生成與文案創作的實務痛點。

#### 工業級穩定性架構
- **斷點續傳機制**：設計並實作 Checkpointing 系統，在大規模批次處理（如 SKU 圖像生成）中可於中斷後精確復原，節省 30% 以上運算成本。
- **錯誤隔離與彈性**：整合 Retry 與 Backoff 機制（HTTP Client），並於 Plugin 層級實作錯誤隔離，確保單一任務失敗不影響整體批次流程。
- **執行效能觀測**：實作 Thread-safe UI 更新機制，提供即時進度條與動態 ETA 計算，顯著提升使用體驗。

#### YAML 驅動的工作流引擎
- **解耦開發**：將硬編碼業務邏輯重構為由 YAML 驅動的參數化工作流，實現邏輯與配置分離，提升功能擴展彈性。
- **Admin Panel 開發**：建構內建工作流編輯器，使非技術人員亦可調整流程與參數。

#### 高階 Prompt Engineering 架構 (V6 Enhanced)
- 建立結構化 Prompt 體系，涵蓋情境模式（Situation）、模特兒模式（Model）、行銷模式（Marketing）等多維度。
- 導入法規合規性過濾（如台灣廣告法規禁語），確保 AI 生成內容可直接商用。

#### 自動化影像處理管線與基礎設施
- **Main / Detail Pipelines**：建構自動化影像處理流程並整合 CDN 上傳，縮短商品上架週期。
- **重複偵測系統**：利用電腦視覺技術開發圖片去重腳本，優化雲端儲存成本。
- **雲端同步化配置**：推動 Cloud-First 架構，建立 Single Source of Truth，解決多環境配置衝突。

---

## 精選專案

- **AI_Tool_Wizard (EXE 版)**：將複雜 Python AI 環境封裝為一鍵執行的 EXE，支援自動更新與 Smoke Test 機制。
- **Sandbox-RAG**：基於檢索增強生成的企業內部知識問答實驗平台。

---

## 軟實力與評價
- **問題解決導向**：能快速定位複雜系統瓶頸並提出穩定性修復方案。
- **技術領導力**：可規劃技術路線圖並建立完整文件 (PROJECT_PROGRESS.md, README.md)。
- **跨團隊協作**：理解電商商業邏輯，能順利轉化為可執行的技術規格。

---

## 語言能力
- **中文**：母語
- **英文**：專業工作水平 (Professional Working Proficiency)
