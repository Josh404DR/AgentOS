---
title: AgentOS Roadmap
created: 2026-07-08
updated: 2026-07-08
owner: Josh
status: draft-awaiting-josh-approval
source_audit: "[[2026-07-08_AGENTOS_AUDIT_AND_MONETIZATION]]"
governance_version: 1.2.0
tags: [roadmap, agentos]
---

# AgentOS Roadmap

本文件整合三個來源，是專案推進的唯一基準：

1. 2026-07-08 總體審查報告（`docs/reports/2026-07-08_AGENTOS_AUDIT_AND_MONETIZATION.md`，弱點編號 W01–W35 沿用該報告）
2. Josh 2026-07-08 修正計畫（從簡治理、token 管理、腳本優先、Dashboard 優化、個人網頁、CI/CD）
3. 同日問答決議（全自治定位、系統上限四槓桿、資料庫決策）

> Josh 的參與方式：**審 roadmap 與驗收結果，不審每個執行步驟**。否則會回到「Josh 是瓶頸」的反自治結構。

---

## 架構原則（先於所有任務）

1. **腳本優先**：能用確定性腳本解決的，一律不用 AI。AI 只出現在需要判斷的節點。腳本可優化、無幻覺；模型呼叫是最後手段。
2. **驗收可執行**：新工單逐步要求附「機器可執行的驗收腳本」；跑得過即 PASS，不靠模型互審格式。
3. **可回滾換自由**：長期以「事後可回滾」取代「事前審批」，自治額度由失敗率數據授予，不由感覺授予。
4. **北極星指標：Josh-分鐘/任務**。此數字趨近零 = 自治達成。
5. **不引入真資料庫**：單機單用戶規模，檔案 + 輪詢/WS 足夠；最多 SQLite 當索引快取。
6. **對客戶不講系統詞**：AgentOS/governance/queue 等一律翻成客戶語言（見審查報告對外包裝表）。

---

## 短期（本月，與變現並行）

| # | 項目 | 對應弱點/來源 | 驗收條件 | 依賴 |
|---|---|---|---|---|
| S1 | 治理從簡：內部/低風險任務停用完整盲審迴圈，改自查 checklist；Risky 規則收斂誤判 | W05, W12, Josh「從簡」 | 內部任務單次派工完成，不再出現 smoke test 多輪 FAIL | 無 |
| S2 | 真實遙測：每次派工記錄實際 token/duration/verdict/失敗原因 | W10, 上限槓桿#3 | METRICS_LOG 新紀錄無 unknown 欄位 | 無 |
| S3 | 修復 Python 3.13 launcher | W16 | 三個作品集專案本機可重跑出 outputs | 無 |
| S4 | repo 衛生：venv 移出 git 追蹤、清 558 dirty files、根目錄雜物（刪除需 Josh 核准） | W07, W08, W25 | git status 乾淨；repo 可公開 clone | 無 |
| S5 | 作品集發布：三專案推公開 GitHub + README Quick Demo | W03 | 公開連結存在且可跑 | S3, S4 |
| S6 | 銷售資產：2 張中文服務一頁書（營運報表自動化／資料健檢） | W04 | assets/sales/ 有成品，含價格區間 | 無 |
| S7 | 人工提案管道：10 份真實提案，記入 screening_log | W01, W02 | screening_log 出現第一批非 mock 紀錄 | S5, S6 |
| S8 | Dashboard 錄影 demo + 個人網頁更新（dashboard 當 AI 作品集主打） | Josh 計畫「個人網頁」 | 個人網頁有影片/截圖 + GitHub 連結 | S5 |
| S9 | 最薄開單頁：前端表單 → 寫入標準 TASK.md（複用現有格式，不新增狀態機） | Josh 計畫「開單頁」 | 從前端開的單能被 queue 正常撿走 | 無 |
| S10 | Antigravity 收斂：只留 pro 單帳號路由，凍結跨帳號排程 | W14, Josh「額度」 | config 中僅 pro enabled；不再投入多帳號機制 | 無 |

**明確不做（本月）**：NotebookLM/知識鏈、Ollama 評測、Upwork 爬蟲、prompt 體系擴充、真資料庫、dashboard 新分頁架構。

---

## 中期（1–3 個月，第一筆收入後啟動）

| # | 項目 | 對應 | 驗收條件 |
|---|---|---|---|
| M1 | 可執行驗收制度化：新工單必附驗收腳本，verify 改為「跑腳本」 | 上限槓桿#1, W05 | 80% 工單 verify 零模型呼叫 |
| M2 | Dashboard 整合：工單結果區塊併入工單監控；決策圖改 tail queue log 即時化；usage 頁接 S2 真實數據 | Josh 計畫, W10 | 頁面資訊不重複；usage 數字可信到「你會看它」 |
| M3 | 版面重構為 Josh 規劃的六區：Token usage／Terminal monitor／Hermes windows（主頁）+ Ticket monitor／Workflow／Tickets university（分頁） | Josh 計畫 | 六區上線，SQLite 索引快取（僅此，無真 DB） |
| M4 | GitHub CI：lint + classifier 回歸測試 + 專案健康度腳本（一支腳本產報告，不買平台） | Josh 計畫「CI/CD」, W29 | PR 觸發自動檢查並出健康度報告 |
| M5 | 每張 escalation 附「預設建議 + 一鍵批准」，批次清理 | 上限槓桿·Josh-分鐘 | escalation 平均處理時間 < 1 分鐘 |
| M6 | 客戶案交付流程定型：客戶案才走完整驗證，內部案走輕量流程 | W09 | 每客戶案有工時紀錄（銷售證據） |

---

## 長期（3 個月後，有數據後啟動）

| # | 項目 | 對應 | 驗收條件 |
|---|---|---|---|
| L1 | 第一條窄自治管線：報表產生 → 自檢（驗收腳本）→ 推送，完全無人值守 | 全自治目標 | 連續 20 次無人介入成功，失敗率門檻內 |
| L2 | Agent 自主領單：agent 觀測 dashboard/queue 自行認領工單 | Josh「看版讓 AI 自己領單」 | 從開單到交付 Josh-分鐘 = 0 的任務型別 ≥ 1 種 |
| L3 | 工單級 git worktree 沙箱 + 一鍵 revert | 上限槓桿#2 | 任何 agent 變更可零成本回滾；Risky 範圍縮小 |
| L4 | 確定性核心移植 Python + 單元測試 + 完整 CI/CD | 上限槓桿#4, W13 | queue/dispatcher 測試覆蓋、可跑於任意環境 |
| L5 | 自治額度制度：按任務型別的失敗率數據逐級開放自治 | 問答決議 | 有數據儀表可查各型別自治等級 |

---

## 問答決議紀錄（2026-07-08）

### Q1：全自治（agent 自主協商產出結果）還是首要目標嗎？
決議：目標保留，但重新定序。證據顯示現行系統實為「反自治」（審批集中於 Josh、escalation 全數 awaiting_josh）；且 1214 smoke test 證明無明確驗收標準時，多 agent 互審收斂於格式官僚而非好結果。路徑改為：變現提供真實任務流量與額度 → 窄自治管線（L1）→ 憑失敗率數據逐級擴大（L5）。**自治是額度，不是開關。**

### Q2：怎麼優化才能拉高系統上限？
決議：上限由四個工程槓桿決定，依影響力排序——
1. 驗收從格式檢查改為可執行測試（M1）
2. 以可回滾取代事前審批（L3）
3. 遙測真實化，建立自己的 eval set（S2）
4. 確定性核心可測試、可移植，bridge 改標準協定 MCP（L4）
北極星指標：Josh-分鐘/任務。

### Q3：Josh 修正計畫逐項裁決
- 腳本優先 → **採納為架構原則第 1 條**
- Dashboard 當作品集 → **採納，短期 S8**（沉沒成本轉銷售資產）
- 前端開單頁 → **採納最薄版 S9**（開單=不忘事，亦為 L2 自治領單的介面雛形）
- Antigravity 解額度 → **修正**：爆額度真因是盲審迴圈與誤分類（W05/W12），非產能不足；收斂為 pro 單帳號（S10）
- 決策圖/usage/區塊整合 → 採納，列中期 M2/M3（usage 依賴 S2 先修數據）
- 需要真資料庫嗎 → **不需要**。檔案 + 輪詢/WS 足夠，最多 SQLite 索引；真 DB 是多用戶併發的解，現在上只是多養一個服務
- CI/CD + 健康度 → 採納，列 M4；健康度用腳本產報告即可

---

## 推進規則

- 每項完成後在本檔打勾並記日期；狀態只有 done / in-progress / blocked / dropped。
- 新想法一律先寫進「候選區」（下方），不直接插隊；每週檢視一次是否升級。
- 與本 roadmap 衝突的臨時工作，預設拒絕。

### 候選區（未排程）
- mobile bridge / Telegram 以外的行動介面
- RAG second brain
- 多機複寫（replicate_to_machine2）
- 正式 Hermes gateway 遷移
