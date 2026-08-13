# 參考知識：ADR 自動化與治理的業界模式

date: 2026-07-13
type: reference（非 ADR 節點，不進戰略地圖）
purpose: ADR 落地自動化／提醒機制的外部案例整合，供 Phase 6 設計依據

## 六個可移植的模式 → AgentOS 對應

### 1. Agent 憲法約束（AGENTS.md as Architectural Constraint）
業界做法：在 AGENTS.md 寫入「做任何架構選擇前先查 docs/adrs/，
不得牴觸 accepted ADR；做出新決策必須先建 proposed ADR 再實作」。
Codex 官方支援 AGENTS.md 逐層合併。
→ **AgentOS 對應**：我們本來就有 AGENTS.md 治理正本＋hash 握手
（ADR-0003），只要加一段 ADR policy，所有 worker 自動繼承。
成本最低、效果最大的一步。

### 2. 適應度函數（Fitness Functions）＝ ADR 的執法機制
核心觀念：「ADR 不是執法機制，是執法機制的原料」。把每張 ADR 的
Decision 轉成自動化檢查，跑在每次變更上，抓 architecture drift
（例：定案用 OpenSearch 六個月後，某 PR 偷引入 Datadog，CI 全綠
照樣過——這就是 drift）。某團隊上線第一季就攔下數十件違規。
→ **AgentOS 對應**：verify 階段（ADR-0004 盲驗）加一條規則：
「對照 accepted ADR 檢查交付物是否牴觸；引入新架構元件而無
對應 ADR 者回報 needs_adr」。等於把 drift 檢查搭在既有驗證便車上。

### 3. 工單模板檢查清單（最低成本版執法）
業界做法：PR 模板加兩個勾選：「此變更是否符合既有 ADR？」
「此變更是否需要新 ADR？」
→ **AgentOS 對應**：Worker Output Contract 加兩行必填：
`adr_conformance: <ok|violation:ADR-xxxx|not_applicable>`、
`new_adr_needed: <true|false>`。

### 4. Agent 決策署名（Agent Attribution）
當 agent 做出或影響架構決策，ADR 須記錄：模型、prompt 摘要、
信心依據、人審狀態。研究背景：「vibe architecting」——同一任務
僅因 prompt 措辭差異可產生 5.9 倍代碼量差；agent 幾分鐘 scaffold
的系統，人要花數小時審。決策出處（provenance）是稽核關鍵。
→ **AgentOS 對應**：ADR 模板 decided_by 欄擴充：人／agent／
模型版本＋人審日期。與「不捏造」鐵律同源。

### 5. 回顧節奏（Scheduled Review Cadence）
業界做法：按 ADR 類型定回顧週期（碰外部 API 的季審、內部架構年審），
排進既有行事曆。
→ **AgentOS 對應**：排程任務跑「決策回顧」：掃各 ADR 的回頭條件
對照證據檔現況（FAIL 率、escalation 頻率），疑似觸發 → Telegram
摘要＋地圖節點標記待審。我們的「回頭條件」欄位正是為此而生，
業界模板反而沒有這個欄——這是 AgentOS 的原創優勢，保留。

### 6. 回溯挖掘（Retroactive Scanning）
業界做法：讓 agent 掃 codebase 找「已嵌在程式碼裡但沒文件」的
架構決策，自動起草 ADR（警告：agent 能還原 what，容易捏造 why，
Context 段必須人審）。
→ **AgentOS 對應**：2026-07-12 已人工做過一輪（ADR-0003~0008
追認版圖）。可做成低頻排程：每月掃一次 scripts/ 與 config/
找無主決策，產 proposed（綠）節點進地圖待 Josh 審。

## 格式對齊備註

業界標準 MADR 4.0 的必備段：Status / Context / Decision /
Consequences（至少三條，含負面）＋建議段 Alternatives Considered。
我們的模板已有 Status（status:）、Context（處境）、Decision（決定）、
回頭條件（原創）；缺 **Consequences** 與 **Alternatives**——
重大決策建議補這兩段，小決策不強制。

## 工具生態（僅記錄，暫不採用）

log4brains（ADR 管理＋自動發佈靜態站）、adr-tools（bash）、
dotnet-adr。不採用理由：我們的 dashboard 戰略地圖已扮演發佈層，
且檔案即資料庫原則（ADR-0007）不需要第二套工具鏈。回頭條件：
若需要對外發佈決策紀錄給協作者，再評估 log4brains。

## 來源

- Operationalizing ADRs with Fitness Functions:
  https://dev.to/alexandreamadocastro/stop-architecture-drift-operationalizing-adrs-with-automated-fitness-functions-22oi
- ADR + Codex CLI 自動治理（Agent-Architecture Gap, 2026-04）:
  https://codex.danielvaughan.com/2026/04/28/codex-cli-architecture-decision-records-adr-automated-governance/
- Architecture Without Architects（vibe architecting 研究）:
  https://arxiv.org/abs/2604.04990
- ADR 完全指南（回顧節奏、PR 清單）: https://techdebt.now/architectural-decisions/
- MADR 格式: https://adr.github.io/madr/
- log4brains: https://github.com/thomvaill/log4brains
- ADR 工具總覽: https://adr.github.io/adr-tooling/
