# AgentOS 結構化系統檢視報告

audit_date: 2026-07-26 Asia/Taipei
project: AgentOS
auditor: Codex Builder
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
scanner_status: operational_review_required
audit_governance_status: review_required
evidence_policy: fresh_local_evidence

## 輸入基準與專案特性

- 系統現況：`E:\AgentOS` 實際檔案、命令輸出、治理狀態與本次測試結果。
- 歷史錯誤記錄：`docs\governance\RISK_RULES.md`、2026-07-08 audit、2026-07-11 inventory、2026-06-21 routing review。
- 上一版檢視報告：`docs\reports\2026-07-08_AGENTOS_AUDIT_AND_MONETIZATION.md`。
- 推導標籤：單人維運、低容錯治理、Windows 本機依賴、客戶交付型、現行低併發但要求 3–10 倍成長。
- 判讀限制：本次不是 production 演練；完整 CI smoke 在 180 秒內超時，未取得 PASS/FAIL。
- 狀態判定：本地 deterministic scanner 回報 `operational_review_required`；但 README 的 1.2.0/aligned 與正本 1.3.0／fresh scanner evidence 衝突，依 `AGENTS.md` 證據衝突規則，本次稽核標記 `governance_status=review_required`。這不覆寫 scanner artifact，而是提高人工檢視等級。

| 編號 | 維度 | 發現 | 是否為歷史重複錯誤 | 風險等級(高/中/低) | 建議行動 | 追蹤狀態(新增/沿用/已解決) |
|---|---|---|---|---|---|---|
| A01 | 結構完整性 | 根治理、角色、Queue、Dispatcher、Dashboard、Knowledge 與 delivery artifact 都有可辨識入口；但 Dashboard、Hermes bridges、啟動腳本仍直接依賴 `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent` 與使用者 profile 下的 `state.db`，使 AgentOS 宣稱獨立、實際卻有未封裝的跨 workspace／identity 耦合。 | 是；沿用 2026-07-08 W15/W18 與架構文件既知外部依賴。 | 中 | 建立一份 machine-local runtime config schema，把 Hermes root、DB、Python 路徑集中成可驗證設定；既有入口保留相容預設。為何適合：本專案是 Windows 單人維運，集中設定可降低換機與不同 identity 執行失敗，又不需要引入服務發現平台。 | 沿用 |
| A02 | 結構完整性 | 治理正本為 1.3.0，本地 scanner 為 `operational_review_required`，但根 `README.md` 仍標示 1.2.0／aligned；`docs\ARCHITECTURE.md` 的 implementation snapshot 更新日仍為 2026-07-05，且多處狀態描述已落後。這是過時事實衝突，故本次稽核依 `AGENTS.md` 標記 `governance_status=review_required`，不得只沿用較低的 scanner label。 | 是；重演 2026-07-08 W30「快照與治理狀態矛盾」。 | 中 | 在 README／ARCHITECTURE 只保留正本指標與自動產生的 checked_at/status link，避免手抄即時狀態。為何適合：低容錯治理需要讀者一眼找到正本，但單人維運不適合同步維護多份狀態副本。 | 沿用 |
| A03 | 風險重演檢查 | repository 仍有大量 modified/deleted/untracked 項目；本次 `git status` 顯示核心治理、角色、scripts、Dashboard 與 data 同時漂移。治理掃描確認政策 drift=0，但 operational drift=22，因此變更邊界仍不可直接形成可信 release。 | 是；重演 2026-07-08 W08，且本次有治理工具的 22 項 drift 精確證據。 | 高 | 先依工單／artifact 對 22 項 operational drift 分群，逐群獨立驗證後再提 exact-path staging 清單；不得使用 `git add .`。為何適合：客戶交付型專案需要可追溯 release，而單人維運更需要小批次降低混入個人／runtime artifact 的機率。 | 沿用 |
| A04 | 風險重演檢查 | escalation index 目前 250 筆且全部為 `awaiting_josh`；上一版只有 12 筆但同樣全部 awaiting。即使其中含 CI fixtures，介面仍會把測試與真實人工決策混在同一營運索引，待辦訊號已進一步失真。 | 是；重演且惡化 2026-07-08 W11。 | 高 | 新增 deterministic environment（ci 或 runtime）／`is_fixture` 欄位與預設篩選，並針對既有 250 筆提出「標記或補 resolution」清單；不得刪除歷史。為何適合：Josh 是唯一決策者，單人核准佇列必須優先呈現真實決策，且 append-only 規範要求以標記而非刪除治理雜訊。 | 沿用 |
| A05 | 風險重演檢查 | 上一版 W13 判定 Queue／Dispatcher 零測試，與本次證據衝突：`test_dispatch_resilience`、`test_queue_failure_containment`、`test_queue_reason_propagation`、`test_governance_tiers` 均實跑 PASS。故「零測試」已解決；但完整 `agentos_ci_smoke.ps1` 在 180 秒內超時，Python 預設 launcher 仍以 exit 103 失敗，不能推導整體 CI 通過。 | 否；舊結論已部分被新證據推翻；W16 Python launcher 則仍重複發生。 | 中 | 將 smoke gate 拆成有每階段 timeout／summary 的 deterministic suites，並在入口明確選擇可用 Python；不得以環境內不存在的 pytest 作必要前提。為何適合：Windows 本機與 bounded timeout 是既定限制，分段回執能讓單人維運快速定位，而非等待單一長流程。 | 沿用 |
| A06 | 可擴張性評估 | Queue 是最先崩潰的模組：每個迴圈會重新掃描全部 task 目錄、反覆解析 `TASK.md`、執行治理 gate，且一次只挑一個 ready task。現有 `data\codex_tasks` 已有 1,513 個目錄／7,801 個檔案；3–10 倍成長會使目錄掃描、正規式解析與 serial dispatch 延遲近似隨總歷史量增長，而非只隨當次 root scope 增長。 | 否；上一版指出 ID 與資料膨脹，但未明列全量重掃為首要 3–10 倍瓶頸。 | 高 | 先建立 rebuildable task metadata index，Queue 只讀 active／root-scoped index，artifact 仍保留檔案正本；並記錄每輪 scan_ms、task_count。為何適合：本專案低併發且重視證據，不需要上分散式 broker；可重建索引即可保留 file-based auditability 並消除歷史全掃描。 | 新增 |
| A07 | 可擴張性評估 | `METRICS_LOG.jsonl`、`ESCALATION_INDEX.jsonl`、Queue log 與 attempt logs 使用 `AppendAllText`／`Add-Content`，未見跨 process lock；per-root starter 只防同 root 重複，無法阻止不同 root 同時寫全域 JSONL。3–10 倍事件併發下可能出現 interleaved、sharing violation 或索引漏寫。 | 否；上一版僅指出 metrics／escalation 內容品質，未檢視跨 root append 原子性。 | 高 | 對全域 append 建立單一窄 scoped writer lock（named mutex 或 lock file＋bounded retry），並加入多 process fault-injection test。為何適合：Windows 單機事件式架構用 named mutex 足夠，能提升低容錯 evidence log 的完整性，又避免引入資料庫／message broker 維運負擔。 | 新增 |
| A08 | 專案特性適配度 | 現行「所有 Worker 完成後皆需全新 Verify」符合低容錯、客戶交付型治理，但對內部低風險文件與診斷會增加模型／排程成本；歷史上曾因 artifact 格式而多輪失敗。不能直接沿用上一版「內部任務免盲審」，因現行 1.3.0 AGENTS 明確要求任一 Worker 均由不同 session 驗證，該建議已與更高層規範衝突。 | 是；承接 2026-07-08 W05/W09，但判斷依據已由治理 1.3.0 改變。 | 中 | 不取消獨立驗證；改成按 acceptance criteria 產生最小 verify bundle，並先由 deterministic schema check 擋下格式錯誤，再呼叫 verifier。為何適合：同時維持客戶交付的獨立品管與單人維運的額度／時間可控性。 | 沿用 |
| A09 | 專案特性適配度 | Dashboard 已補載實際寫入端點、default-off mutation flag、loopback、Origin、owner session 與 CSRF，故上一版 W06「完全宣稱 read-only」已不再成立；但文件標題與 current phase 仍同時使用 read-only 與 write endpoint 敘述，概念邊界仍易被誤讀。 | 否；與上一版 W06 衝突，本次依 2026-07-20 scope 與 UX/security contract PASS 判為部分解決。 | 低 | 將 Dashboard 明確分成 public read plane、owner-authenticated control plane、isolated knowledge append plane 三區，文件與 UI 使用同一命名。為何適合：本機單人操作不必拆成三個服務，但客戶交付型治理需要權限邊界能被快速稽核。 | 沿用 |
| A10 | 新增待觀察風險 | 全套 smoke gate 180 秒無回執，且 CI 測試會建立大量 `ci-*` task/escalation artifact；若定期執行未搭配 retention／fixture namespace，測試本身會放大 A04、A06 的營運噪音與掃描成本。 | 否；本次新觀察到 timeout 與大量 CI artifact 的聯動。 | 中 | 為 CI artifact 設獨立 namespace/index view、每 suite 輸出 bounded duration，另提出保留／封存方案供 Josh 精確核准；核准前不刪除。為何適合：append-only 與禁止未核准刪除是本專案硬邊界，先隔離視圖與量測可止住營運污染而不破壞證據。 | 新增 |

## 本次新增至錯誤記錄庫的條目

以下內容可直接貼回 `RISK_RULES.md` 的「歷史錯誤／待觀察模式」區；它們是偵測規則，不改變既有 Risky Task 權限邊界：

```md
## 歷史錯誤／待觀察模式（2026-07-26）

### RR-OPS-001：Queue 全量歷史掃描
- 命中條件：Queue 每輪從 `data\codex_tasks\` 全量列舉／解析，再縮小 root scope。
- 風險：task artifact 成長 3–10 倍時，歷史量直接放大每輪 latency。
- 驗證：記錄 `scan_ms`、`directory_count`、`scoped_task_count`；以 rebuildable active index 前後比較。
- 建議：保留檔案正本，Queue 改讀可重建的 active/root-scoped metadata index。

### RR-DATA-002：跨 root 全域 JSONL 無鎖追加
- 命中條件：兩個以上 process 可同時對同一全域 JSONL 使用 `AppendAllText` 或 `Add-Content`，且沒有跨 process lock。
- 風險：sharing violation、interleaved record、索引漏寫，破壞 append-only 證據完整性。
- 驗證：多 process fault-injection，確認每筆 JSON 可解析、筆數完整、順序欄位可稽核。
- 建議：使用窄 scoped named mutex／lock file 與 bounded retry。

### RR-CI-003：Smoke gate 無階段回執並污染 runtime view
- 命中條件：完整 smoke 超過 bounded timeout 無 summary，且 fixture artifact 進入 runtime task/escalation 索引。
- 風險：無法判定 CI 結果；測試噪音增加人工待辦與 Queue 掃描成本。
- 驗證：每 suite 必須有 duration、exit code、artifact namespace；CI 與 runtime view 分離。
- 建議：拆分 suites、fixture 標記／namespace、保留方案需 Josh 精確核准。
```

## 下次檢視應追蹤事項

1. 22 項 operational drift 是否已按 task/artifact 分群並各自取得獨立驗證。
2. escalation 的 250 筆 `awaiting_josh` 是否已區分 CI fixture 與真實人工決策，且沒有刪除歷史。
3. Queue 是否新增 `scan_ms`／`directory_count` 指標；3×、10× synthetic metadata 下的 p95 latency。
4. 全域 JSONL 多 process fault-injection 是否達成零遺失、逐行可解析。
5. `agentos_ci_smoke.ps1` 是否能在明確 timeout 內輸出分段 summary；Python launcher／必要 dependencies 是否可重現。
6. README／ARCHITECTURE 是否停止手抄即時 governance status，改指向 fresh local evidence。
7. Dashboard 三個 plane 的文件、路由與 UI 名稱是否一致。

## 本次驗證證據

- governance gate：PASS；scanner_status=operational_review_required；policy drift=0；operational drift=22；task_execution_allowed=true。因 README 過時事實衝突，本報告的 audit_governance_status=review_required。
- targeted PASS：governance tiers、dispatch resilience（6 cases）、queue failure containment、queue reason propagation、Dashboard UX contract、PowerShell UTF-8 BOM regression。
- 未通過／未取得：完整 CI smoke 180 秒 timeout；系統預設 `python` launcher exit 103；bundled Python 無 pytest，故兩個 Python pytest suite 未實跑。
- 不可宣稱：production-ready、完整 CI PASS、Python test PASS。
- 完整命令、時間、exit code 與原始回執：`OUTPUTS\TEST_RESULT.md`。
- 獨立驗證：第三個全新 read-only Codex Verify session 判定 `PASS`；A01–A10 全為七欄，8 項核心驗收達成、0 項未達成。
