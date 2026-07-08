# AgentOS 總體審查與變現修正報告

audit_date: 2026-07-08
auditor: Claude（專案稽核員 + 技術架構審查 + 變現顧問）
governance_version: 1.2.0
governance_hash: ad20e91afb53ef06800077f420f8f441e57eeea0e906794ff219e63f0ffe39c3
evidence_policy: 全部結論基於本次實際讀檔與命令輸出，非文件自述

---

## 【專案地圖】

| 模組 | 是什麼 | 完成度 | 可執行 | 測試 | 文件 | 可對外展示 | 變現價值 |
|---|---|---|---|---|---|---|---|
| 治理層（AGENTS.md、assert_governance_ready、sync_shared_governance、governance_status.json） | 跨 agent 規範+雜湊 drift 檢查 | 高（真的在運作，log 有 fail-closed 證據） | 是 | 無 | 多 | 否（客戶不在乎） | 間接（內部紀律） |
| Queue Runner（task_queue_runner.ps1 469 行） | 確定性排程、依賴、verdict 解析、retry、escalation | 高，有 27 個 queue_runs 與 task-queue.log 實跑證據 | 是 | **無** | 有 | 否 | 內部工具 |
| Dispatcher（dispatch_task_packet.ps1 564 行） | 路由到 Claude/Codex/Antigravity | 高 | 是 | **無** | 部分 | 否 | 內部工具 |
| Classifier（classify_task.ps1） | 純 regex 規則分類 Simple/Complex/Risky | 中；有回歸測試 | 是 | 有（tests/classify_task_regression.ps1） | 有 | 否 | 低 |
| Blind Verify 流程（codex_verify + revision 迴圈） | 全新 session 盲審 | 已運作，但**實跑證據顯示連 read-only smoke test 都兩輪 FAIL 後 escalation**（1214-child-01） | 是 | 無 | 有 | 否 | 低（成本大於效益，見弱點） |
| Metrics / Escalation（METRICS_LOG.jsonl、ESCALATION_INDEX.jsonl） | append-only 指標與人工決策索引 | 形式存在：metrics 只有 **5 筆**、token/duration 全 unknown；escalation 12 筆**全部 awaiting_josh**、混入 fixtures | 是 | 部分 fixture | 有 | 否 | 無 |
| Hermes（Telegram 收件/派工/回報） | 入口網關 | 中；gateway 為 legacy 模式、proxy 8080 未解 | 部分 | test_hermes.ps1 存在（未驗證） | 多 | 否 | 間接 |
| Lead patrol（daily-upwork-lead-patrol） | 每日 Upwork 掃案 | **失效**：6/22–6/24 三天 lead 檔全為 0 qualified，全被 Cloudflare/CAPTCHA 擋；6/24 之後 14 天無任何 lead 檔 | 否（被平台封鎖） | 無 | 有 | 否 | **這是收入入口，目前=0** |
| Screening / Proposals | 篩選與提案 | 只有 MOCK：screening_log 僅 mock dry-run；proposals 僅 1 mock + 1 template | n/a | 無 | 有 | 否 | 流程可保留，內容為零 |
| Portfolio projects（projects/：data-quality-audit-toolkit、ecommerce-operations-automation-pipeline、ecommerce-market-intelligence-dashboard、josh-resume 系列） | 三個真實 Python/SQL 作品集+履歷 | **高**：有 src、sql、requirements、README（商業語言、英文）、outputs 有真實產出（data_quality_report.md、daily_operations_report.md、alert_log.csv、charts） | 是（有產出物） | 少 | 好 | **是（全 repo 最能見人的東西）** | **最高** |
| Dashboard（Next.js + FastAPI，21 API + WebSocket） | 本機監控台 | 中高，可跑（uvicorn log 正常） | 是 | 無 | 有 | 否 | 內部工具；**DASHBOARD_SCOPE 說 read-only，但 main.py 有 POST control/approvals 寫入端點 → 文件與實作矛盾** |
| Antigravity 4 帳號 subagent pool | 跨 4 個 Windows 帳號的免費額度 worker | 已接通但 **processed=0，從未派過任何真實任務**；每 5 分鐘輪詢空轉 | 是 | 無 | 有 | 否 | 目前為 0，且有多帳號 ToS 風險 |
| 知識鏈（url_intake 122 節點、knowledge_pool、NotebookLM conveyor、obsidian/notebooklm exports） | 知識搬運與檢索 | 各自部分完成，四套出口 | 部分 | 無 | 多 | 否 | 無（30 天內） |
| Ollama 評測（data/ollama_eval 191 檔） | 本地模型速度/實用評測 | 完成 | n/a | n/a | 有 | 否 | 無 |
| Prompts 三層（role_headers/task_templates/context_packs，19 檔；hermes prompt 405 行） | 提示詞組裝系統 | 高 | n/a | 無 | 自文件 | 否 | 低 |
| Tools（upwork scraper、threads、network） | 爬蟲與網路工具 | upwork scraper **已被平台封死** | 否 | 無 | 少 | 否 | 無，且有帳號風險 |
| 裝置維護（fan_control、memory_guard、watchdog、replicate_to_machine2） | 本機維護 | 部分 | 部分 | 無 | 有 | 否 | 無 |
| 根目錄雜項（人生計畫/、新增 文字文件.txt、空 OUTPUTS/、scratch/、archive/） | 個人文件與殘渣 | — | — | — | — | 否 | 無 |

---

## 【真實狀態】

直說：**AgentOS 是一台造得很精緻、但從未載過客的計程車派遣系統。**

- 系統側：治理、queue、盲審、escalation、metrics、dashboard 都「真的存在、真的跑過」——這不是假的。173 個工單目錄、queue log、verify verdict 都有實證。
- 收入側：**全為零。** 唯一的 lead 來源自 6/22 起被 Cloudflare/CAPTCHA 全面封鎖，6/24 後連 lead 檔都沒有；沒有一份真實 screening、沒有一份真實提案、沒有一個真實客戶工單、作品集寫好了但沒發布。
- 更糟的是：系統的模型額度（你自己回報 Claude/Codex 受限）正在被「系統驗證系統自己」消耗——一個 read-only smoke test 燒了 worker+verify+revision1+verify+revision2+verify 共 6 次派工後以 escalation 收場，敗因是 TEST_RESULT.md 格式與 models_invoked 欄位矛盾，不是任何真實錯誤。
- 過去 ~3 週的產出重心：Antigravity 多帳號池、NotebookLM conveyor、Ollama 評測、dashboard、治理 drift 修復。這些沒有一項會讓任何人付你錢。

結論：它現在是「接案輔助系統的底盤 + 三個可賣的作品集」，不是產品，也還不是能展示的平台。

---

## 【完整弱點清單】

| 編號 | 問題 | 模組 | 嚴重度 | 證據 | 影響 | 修正建議 | 是否影響變現 |
|---|---|---|---|---|---|---|---|
| W01 | 唯一收入入口失效：Upwork/搜尋引擎全被 CAPTCHA 封鎖 | Lead patrol | **P0** | data/leads/2026-06-24.md：Qualified leads: 0，Cloudflare Turnstile 全擋；6/24 後無 lead 檔 | 收入漏斗輸入=0，整個下游流程無料可跑 | 停止爬蟲；改人工/半自動管道（見變現修正路線） | 是（致命） |
| W02 | 零真實提案、零真實客戶 artifact | Screening/Proposals | **P0** | proposals/ 只有 mock+template；screening_log 只有 MOCK-DRY-RUN | 30 天變現無起點 | 72 小時內人工發出第一批提案 | 是（致命） |
| W03 | 作品集完成但未發布 | projects/ | **P0** | current_state Immediate Priority #2 仍為待辦；outputs 有真實產出 | 唯一可賣資產沒人看得到 | 立即發布 GitHub + 一頁式介紹 | 是 |
| W04 | 對外零客戶語言資產：無服務說明、報價、案例頁 | 全域 | **P0** | docs 34 份全為工程師向；README 是系統說明 | 客戶看不懂、無法報價、無法成交 | 寫 2–3 張服務一頁書（中文、含價格） | 是 |
| W05 | 盲審官僚成本 > 任務價值：smoke test 兩輪 FAIL 皆因 artifact 格式 | Blind Verify | **P0** | 1214-child-01 revision-2-codex-verify RESULT.md：FAIL 原因為 TEST_RESULT.md missing 與 models_invoked 欄位矛盾 | 額度被自我審查燒掉；交付變慢；demo 時會當眾卡死 | 內部/低風險任務改「自查 checklist」，盲審只留給客戶交付物 | 是 |
| W06 | Dashboard 文件與實作矛盾：宣稱 read-only，實有寫入端點 | Dashboard | P1 | DASHBOARD_SCOPE.md「does NOT trigger/write」vs main.py POST /api/workflows/{id}/control、POST /api/approvals/{id}/decision（執行 PS 腳本） | 文件不可信示範；agent 安全邊界與宣稱不符 | 更新 SCOPE 文件承認控制面，或移除端點 | 間接 |
| W07 | Git repo 83% 是誤 commit 的 venv | repo 衛生 | P1 | git ls-files 2747 筆中 2288 筆在 data/codex_tasks/2026-06-23-poc-perplexity-api/.venv_perplexity_poc | repo 不可 clone 示人、diff 汙染、git 慢 | 提刪除提案（需 Josh 核准）：git rm -r --cached + .gitignore | 是（作品集可信度） |
| W08 | git status 558 個未處理變更 + index.lock 殘留 | repo 衛生 | P1 | git status --porcelain = 558 行；unlink index.lock 失敗 | 無法乾淨 commit、變更不可稽核 | 一次治理性 commit 清理 | 間接 |
| W09 | 額度受限 × 每任務 2–6 次模型呼叫的流程設計 | Workflow v1.2 | P1 | current_state Blockers：Claude/Codex 額度受限；1214 任務鏈 6 個派工目錄 | 真實接案時額度不夠交付 | 分級：客戶案才用完整流程 | 是 |
| W10 | Metrics 是形式：5 筆、token/duration 全 unknown | Metrics | P1 | METRICS_LOG.jsonl 共 5 行，token_actual:"unknown" | 無法用數據證明系統省時（也就無法拿來銷售） | 先擱置，或只記錄客戶案工時 | 間接 |
| W11 | Escalation index 12 筆全 awaiting_josh、混入測試 fixture | Escalation | P1 | ESCALATION_INDEX.jsonl 全數 awaiting_josh；current_state 自己警告 fixture 誤判風險 | 儀表板/交接會誤報待辦；治理債累積 | 補 RESOLUTION 或標記 fixture | 間接 |
| W12 | Classifier 誤判面大：碰到 architecture/queue/governance 即 Complex、風險詞任意位置即 Risky | Classifier | P1 | classify_task.ps1 regex；內部任務幾乎必然 Complex → 進入昂貴流程 | 小事被放大成多輪工單，燒額度 | 收斂規則或人工指定 task_type | 間接 |
| W13 | 核心 queue/dispatcher（共 1033 行 PS1）零測試 | Queue/Dispatcher | P1 | tests/ 只有 classifier 與 learning_collector | 改一行可能全流程壞；demo 風險 | 凍結改動即可（30 天內不重構） | 間接 |
| W14 | Antigravity 4 帳號池：高複雜度、跨帳號 session 依賴、從未處理過任務 | Antigravity | P1 | poll log 全部 processed=0；invoke 腳本要求 Windows user 相符、無自動輪替 | 維護成本高、產出 0；多免費帳號有平台 ToS/封號風險 | 凍結（保留 config），第一筆收入後再議 | 是（負向：耗時間） |
| W15 | Hermes proxy 8080 未解、gateway 為 legacy 模式 | Hermes | P1 | README caveat + ARCHITECTURE Known blockers | 入口不穩，Telegram 流程 demo 有風險 | 只修到「能收發」為止，不追求正式 gateway | 間接 |
| W16 | Python 3.13 launcher broken | 環境 | P1 | current_state Blockers | 作品集 demo（Python 專案）可能當場跑不起來 | 修復或固定用可用直譯器路徑 | 是（demo） |
| W17 | progress_log.md 單檔 136KB/2691 行持續膨脹 | 文件 | P2 | wc -l 輸出 | token 成本、檢索困難 | 按月切檔即可 | 否 |
| W18 | 文件量 34 份 vs 實作落差：多份 PLAN/POLICY 未實作（24H monitor、evidence hygiene、free cloud window、memory architecture） | docs | P1 | docs/ 清單；無對應執行證據 | 「文件完成=假完成」的溫床；接手者誤信 | 標記 planned/not-implemented | 間接 |
| W19 | dispatch_id 命名不可讀：80+ 字元、一個任務 7 個目錄 | Queue 資料 | P2 | data/codex_tasks/telegram-telegram-1449022024-1214-...-revision-2-codex-verify | 人工除錯困難、demo 不能看 | 縮短 ID 規則（之後再做） | 否 |
| W20 | 三個 bridge 腳本功能重疊 | scripts | P2 | hermes_claude_bridge / hermes_codex_bridge / hermes_tripartite_bridge | 重複造輪 | 封存兩個 | 否 |
| W21 | Prompt 三層抽象 19 檔 + 405 行 Hermes prompt | prompts | P2 | prompts/ 清單 | 維護成本、prompt drift | 凍結，不再擴充 | 否 |
| W22 | 知識鏈四套出口（url_intake/knowledge_pool/NotebookLM/obsidian） | 知識層 | **P3** | data/url_intake 122 檔、exports/ 162 檔 | 與收入無關的持續投入 | 全部封存 | 是（負向：耗時間） |
| W23 | Ollama 評測 191 檔 | 評測 | P3 | data/ollama_eval | 已完成就好，不要再擴 | 封存 | 否 |
| W24 | Upwork 爬蟲工具鏈違反平台反爬且已失效 | tools/upwork | P1 | 6/24 lead 檔 Rejection Details 全表；tools/upwork/*.py | 帳號封鎖風險；沉沒成本誘惑 | 停用，不再投入 | 是 |
| W25 | 根目錄雜物：新增 文字文件.txt（irm\|iex）、人生計畫/、空 OUTPUTS/ | repo 衛生 | P2 | ls 輸出 | 專業度、`irm\|iex` 管道執行遠端腳本是壞習慣 | 移出 repo / 刪除（需核准） | 間接 |
| W26 | .env 明文 session token（NOTEBOOKLM_SID） | 安全 | P2 | .env 內容（已 gitignore） | token 外洩/過期風險低但存在 | 保持 gitignore，過期即棄 | 否 |
| W27 | 裝置維護（fan_control/memory_guard）混入接案 repo | scripts | P2 | ARCHITECTURE Internal Device Maintenance 節 | 範圍蔓延 | 之後移出 | 否 |
| W28 | 中英混雜（治理繁中、架構英文、工單混雜） | 文件 | P2 | 各檔案 | 交接/展示成本 | 客戶面統一中文、作品集統一英文 | 間接 |
| W29 | 測試全 PowerShell、綁 Windows，無法 CI | tests | P2 | tests/*.ps1 | 不可重現驗證 | 之後再說 | 否 |
| W30 | current_state 快照曾與 governance_status.json 矛盾（drift 3 vs aligned 0） | 治理 | P2 | current_state §2 vs governance_status.json | 讀者不知信哪份 | 已緩解；快照加 checked_at 對照 | 否 |
| W31 | 系統沒有「發作品集/發提案/成交」這類任務型別——它只認識自己 | 流程設計 | **P0** | 173 個工單目錄幾乎全為內部系統工作 | 目標漂移的結構性原因 | 把變現動作本身開成工單 | 是 |
| W32 | staging_site 空目錄、archive 殘留 | repo | P3 | find 輸出 0 files | 混亂 | 封存清單處理 | 否 |
| W33 | RESOURCE_INVENTORY/路由計畫依賴會過期的訂閱（pro 將不續約） | 路由 | P2 | current_state 臨時狀態記載 | 路由計畫脆弱 | 降依賴，單模型為主 | 間接 |
| W34 | Dashboard 前端 65k node_modules、tsbuildinfo 等重件在工作目錄 | Dashboard | P2 | find dashboard 65127 files | 備份/搬遷痛苦 | .gitignore 已擋即可 | 否 |
| W35 | 「30 天現金流」目標與所有 Immediate Priority 排序不符：優先序 #1 仍是 Antigravity 治理審核 | 專案管理 | **P0** | current_state §7 | 資源持續流向不產錢的事 | 重排優先序（見 72 小時清單） | 是 |

---

## 【最嚴重的 10 個問題】（依處理順序）

1. **W01+W02 收入漏斗輸入為零且已斷 14 天**——先恢復「有案子看、有提案發」這件事，手動也行。
2. **W03 作品集沒發布**——已完成 90% 的資產放著發霉，這是最便宜的修復。
3. **W04 沒有客戶語言的服務包裝**——沒有一頁紙能讓案主 30 秒懂你賣什麼、多少錢。
4. **W35 優先序倒置**——current_state 的第一優先仍是內部治理審核，不是收入。
5. **W05 盲審官僚燒額度**——內部任務停用完整 verify 迴圈，把額度留給客戶案。
6. **W16 Python launcher 壞掉**——demo 作品集前必須修，否則當場翻車。
7. **W07+W08 repo 衛生（venv 誤 commit、558 dirty files）**——公開 GitHub 前必修。
8. **W14 Antigravity 池空轉**——凍結，別再調它。
9. **W06 Dashboard 宣稱與實作矛盾**——內部信任問題，改文件五分鐘。
10. **W11 escalation 全 awaiting_josh**——清一次，讓「待你決策」清單回到真實。

---

## 【可以保留的資產】

**A. 保留並強化**
- 三個 portfolio 專案（data-quality-audit-toolkit、ecommerce-operations-automation-pipeline、ecommerce-market-intelligence-dashboard）：有 src/sql/README/真實 outputs，唯一直接可賣的東西。
- josh-resume 系列。
- workflows/ai_freelancer_os.md 的 leads→screening→proposal 檔案紀律（流程對，缺的是真料）。
- proposals/template-apps-script-automation.md（提案模板）。

**B. 可以包裝成 demo**
- ecommerce-operations-automation-pipeline 的「原始亂資料 → 每日營運報告 + 警示」一鍵流程（有前後對比，非技術老闆看得懂）。
- data-quality-audit-toolkit 的資料健檢報告（data_quality_report.md + scorecard）。

**C. 可以變成接案服務**
- Sheets/Apps Script 自動化（模板已有）、每日營運報表、資料健檢——見服務區。

**D. 內部工具（不賣、不擴建）**
- Queue runner + dispatcher（凍結版）、governance 雜湊檢查、dashboard（監控用）、Telegram/Hermes 收發、RISK_RULES 當人工 checklist。

**E. 應該封存**
- Antigravity 4 帳號池、NotebookLM conveyor、obsidian/notebooklm exports、url_intake/knowledge_pool、ollama_eval、threads 工具、upwork 爬蟲、tripartite/claude/codex 三座 bridge 中的兩座、fan_control 擴充、24H monitor 等未實作 PLAN 文件、multi-model routing 擴充。

---

## 【應該停止或封存的項目】（直說）

1. **停止** Antigravity 多帳號池的一切後續（排程、輪替、憑證機制）。這件事現在不該做，先完成變現，再優化系統。
2. **停止** NotebookLM / obsidian / url_intake 知識鏈投入。
3. **停止** Ollama 本地模型研究。
4. **停止** dashboard 新功能（含 Telegram 整合 Future Phase）。
5. **停止** 治理與 prompt 體系的任何再精緻化（新 role header、新 context pack、新 PLAN 文件）。
6. **停止** Upwork 爬蟲修復嘗試——平台已用 Cloudflare 明確拒絕，這條路是死的。
7. **停止** 對內部任務跑完整 Blind Verify 迴圈。
8. **等第一筆收入後再說**：mobile bridge、RAG second brain、多機複寫（replicate_to_machine2）、正式 gateway 遷移。

---

## 【變現阻礙】（第八節問題的回答）

1. **最大阻礙**：不是技術——是「漏斗沒有輸入 + 資產沒有出口」。lead 來源死了 14 天，作品集沒發布，服務沒有名字和價格。
2. **修掉最能提高成交率**：W04（服務一頁書）、W03（作品集上線）。
3. **修掉最能提高交付速度**：W05（內部任務免盲審）、W09（額度分級）、W16（Python 修復）。
4. **修掉最能讓 demo 好看**：W16、W07（repo 乾淨）、用 ecommerce pipeline 錄一段 2 分鐘前後對比。
5. **其實不急**：W17、W19、W20、W21、W28、W29、W30、W34——全部不影響收入。
6. **該改名改包裝**：見對外包裝表。
7. **該從系統改成服務**：ecommerce pipeline → 「每日營運報表服務」；data-quality toolkit → 「資料健檢服務」；Apps Script 模板 → 「表單/報表自動化小案」。
8. **不要產品化、直接接案**：全部三項。不做 SaaS、不做平台。

---

## 【變現修正路線】

順序：修 demo 環境（W16）→ repo 清理（W07/W08，刪除需你核准）→ 發布作品集（W03）→ 寫服務一頁書與報價（W04）→ 人工管道發提案（W01/W02 的替代路徑：104 外包網、PRO360、Tasker 出任務、FB 社團、LINE 群、熟人轉介、既有雇主人脈；Upwork 改人工瀏覽+人工投，不爬蟲）→ 接到案後才動用 AgentOS 內部工具做交付管理。

---

## 【最適合先賣的 1～3 個服務】

### 服務 1：Google Sheets / Apps Script 自動化小案
- 一句話：「你每天手動複製貼上的表單、報表、對帳，我幫你變成自動的。」
- 目標客戶：小公司行政/會計/電商小編
- 痛點：重複貼資料、月底對帳爆炸、寄通知靠手
- 交付：自動化腳本 + 使用說明 + 一次修改
- 需先修：W04（一頁書）、W03（作品集連結）
- 3 天 demo：發票/對帳 mock 自動化（proposals 模板已有腳本雛形）
- 7 天可展示：錄 2 分鐘前後對比影片
- 30 天可收費：直接可收
- 報價：NT$3,000–10,000／件
- 話術：「先免費看你的表，我告訴你哪些步驟可以消失。」
- 不承諾：不碰客戶正式資料庫、不承諾即時系統、不承諾無限修改

### 服務 2：電商每日營運報表自動化（主打）
- 一句話：「每天早上 8 點，LINE 自動收到昨天的營收、異常訂單和庫存警示。」
- 目標客戶：蝦皮/官網電商、有多份匯出檔的營運團隊
- 痛點：訂單/庫存/出貨分散多檔，人工彙整慢又錯
- 交付：清理+驗證+KPI+警示+每日報告（ecommerce-operations-automation-pipeline 就是現成引擎）+ LINE/Telegram 推送
- 需先修：W16、W03；推送用現有 Telegram 經驗改 LINE Notify
- 3 天 demo：用現有 mock outputs 直接展示 daily_operations_report.md + alert_log.csv
- 7 天可展示：加一條「客戶格式 CSV 進 → 報告出」的通用入口
- 30 天可收費：首月建置 + 維運
- 報價：建置 NT$15,000–50,000 + 維運 NT$2,000–5,000/月
- 話術：「你給我三天份的匯出檔，我隔天給你看你自己的報表長什麼樣。」
- 不承諾：不接 ERP 深度整合、不承諾即時、不碰金流

### 服務 3：資料健檢一次性服務（敲門磚）
- 一句話：「我幫你檢查報表背後的資料有多少坑：重複、漏值、算錯，給你一份老闆看得懂的報告。」
- 目標客戶：靠 Excel/Sheets 做決策的中小企業
- 痛點：「數字怪怪的」但不知道哪裡錯
- 交付：data_quality_report + 問題清單 + 修復建議（toolkit 現成）
- 報價：NT$5,000–20,000／次；天然導流到服務 1、2
- 不承諾：不代表資料一定能修好、不含修復實作（另報價）

---

## 【72 小時行動清單】（只有 3 件）

1. **發布作品集**：修 Python launcher → 三個專案跑一次確認 outputs 可重現 → 推上 GitHub（乾淨 repo，不含 venv）→ 履歷/一頁式加連結。
2. **做出 2 張服務一頁書（中文、含價格區間、含前後對比截圖）**：服務 1 與服務 2。素材直接用 pipeline 的 mock 報告。
3. **發出 10 份真實提案**：104 外包網/PRO360/Tasker/FB 社團/熟人各發一輪，用 template-apps-script-automation.md 改寫，全部記入 screening_log.md（終於有真料）。

---

## 【30 天收入計畫】

- 第 1 週：72 小時清單 ×1；每日人工看案 30 分鐘（取代死掉的爬蟲）；目標：10+ 提案、2 個回覆。
- 第 2 週：資料健檢服務上架（服務 3 當敲門磚，低價快成交）；持續每日提案 3–5 件；目標：第一筆 NT$3,000–10,000 成交。
- 第 3 週：交付第一案（用 Claude worker 交付，人工驗收，不跑盲審）；把交付過程截圖變成第一個真實案例頁；目標：第二筆成交或首個月費客戶。
- 第 4 週：主打服務 2（報表自動化建置案）報價 1–2 家；整理「前後對比＋省時數字」進作品集；目標：累計 NT$15,000–30,000 或簽下 1 個建置案。

---

## 【對外包裝】

| 技術名稱 | 客戶語言名稱 | 客戶痛點 | 怎麼展示 | 怎麼報價 |
|---|---|---|---|---|
| ecommerce-operations-automation-pipeline | 每日營運報表自動化 | 每天人工彙整訂單/庫存 | 2 分鐘影片：亂 CSV 進 → 報告+警示出 | 建置費+月費 |
| data-quality-audit-toolkit | 資料健檢服務 | 報表數字不敢信 | 一份範例健檢報告 PDF | 單次固定價 |
| ecommerce-market-intelligence-dashboard | 老闆看得懂的數據儀表板 | 看不到全貌 | 截圖+互動 demo | 專案價 |
| Apps Script 模板/proposals 模板 | Google 表單/報表自動化 | 複製貼上地獄 | 前後步驟數對比 | 按件 3k–10k |
| Hermes/Telegram 流程 | LINE/Telegram 自動通知助手 | 訊息靠人轉 | 手機即時收到報告 | 加購項 |
| AgentOS/governance/queue/Blind Verify/escalation/orchestration | （對客戶**一律不提**，統稱「我的內部品管流程」） | — | — | — |

---

## 【最後決策】（第十二節十問）

1. 真實狀態：底盤完成、貨艙是空的。內部流程真、對外產出零。
2. 定位：**接案輔助系統（內部工具）+ 作品集倉庫**。不是產品，不是平台。
3. 最有價值：projects/ 三個作品集 + 你已建立的「證據紀律」工作習慣。
4. 最危險：目標漂移——系統只生產關於系統自己的工作（173 個工單幾乎全內部）。
5. 最該先修 3 個：W03 發布作品集、W04 服務包裝、W16 Python 環境。
6. 最不該繼續 3 件：Antigravity 多帳號池、知識鏈（NotebookLM/obsidian/url_intake）、dashboard 擴建。
7. 30 天最該賣：**服務 2 每日營運報表自動化**（客單價最好、資產最現成），用服務 3 資料健檢當敲門磚。
8. 72 小時 3 件事：見上。
9. 只留 20%：projects/ 全部、proposals 模板、workflows/ai_freelancer_os.md、classify 的 RISK_RULES 當人工 checklist、Telegram 收發。其餘凍結。
10. 只做一個 demo：**「亂資料進 → 每日營運報告出」**（ecommerce pipeline），因為非技術老闆 30 秒就懂。

---

## 【對外銷售文案】（可直接貼）

> 我幫小公司把「每天重複做的表格工作」變成自動的。
> 例如：每天早上自動彙整訂單和庫存、算好營收、標出異常，直接傳到你的 LINE；或是把你月底要對三天的帳，變成按一個鍵。
> 我用 Python 和 Google Apps Script，交付的東西你自己公司就能繼續用，不綁我。
> 最近的案例（示範資料）：把 5 份雜亂的電商匯出檔，變成每天一份自動營運日報＋異常警示，原本每天約 1 小時的人工彙整歸零。
> 小案 NT$3,000 起，先免費幫你看流程哪裡可以自動化。作品集：<GitHub 連結>

---

## 【給 Codex / Jamie 的執行提示詞】

```text
role: workspace implementation worker（Workflow v1.2，本工單經 Josh 核准）
goal: 讓 AgentOS 進入「可展示、可接案」狀態。只做以下四件事，禁止任何其他系統優化。

TASK 1 — repo 衛生（含刪除提案，刪除動作必須先回報 Josh 核准，不得自行執行）:
- 提案將 data/codex_tasks/2026-06-23-poc-perplexity-api/.venv_perplexity_poc 從 git 追蹤移除（git rm -r --cached）並加入 .gitignore；列出精確路徑、影響、回復方案。
- 提案處理根目錄「新增 文字文件.txt」與空 OUTPUTS/；「人生計畫/」提案移出 repo。
- 整理 git status 至可乾淨 commit；不使用 git add .，逐路徑加入。

TASK 2 — 作品集發布準備:
- 在本機重跑 projects/data-quality-audit-toolkit 與 projects/ecommerce-operations-automation-pipeline，確認 outputs 可重現；若 Python launcher 失效，記錄實際錯誤並用可用直譯器路徑執行。
- 為兩專案各補一節 README「Quick Demo（3 commands）」。
- 產出獨立乾淨副本（不含任何 AgentOS 治理檔）供推送公開 GitHub。

TASK 3 — 銷售資產:
- 用 projects/ecommerce-operations-automation-pipeline/outputs 的 daily_operations_report.md 與 alert_log.csv 製作一頁中文服務說明（Markdown）：痛點 → 前後對比 → 交付內容 → 價格區間 NT$15,000–50,000 建置 + 月費。
- 用 data-quality-audit-toolkit 產出物做第二張一頁書（資料健檢，NT$5,000–20,000）。
- 存放於 assets/sales/（新目錄）。

TASK 4 — 文件對齊（只改事實，不加新規範）:
- DASHBOARD_SCOPE.md 補記既有 POST control/approvals 端點的事實。
- current_state.md Immediate Priority 重排：1) 作品集發布 2) 提案發送 3) 其餘凍結。
- 在 docs/INDEX.md 為未實作的 PLAN 文件加註 status: planned-not-implemented。

constraints:
- 禁止：新增治理機制、動 Antigravity、動 NotebookLM/知識鏈、改 queue/dispatcher 邏輯、跑內部盲審迴圈。
- 所有刪除/移動先提案後執行；完成報告附 artifact 路徑與實際 diff。
```
