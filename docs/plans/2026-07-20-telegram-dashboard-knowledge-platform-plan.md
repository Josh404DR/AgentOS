# Telegram × Dashboard 知識工作平台計畫

日期：2026-07-20  
狀態：討論草案，尚未授權實作  
治理綁定：AgentOS governance 1.3.0  
目標：Telegram 保持單一、低摩擦的作業入口；Dashboard 成為可查詢、追溯、討論、決策及轉工單的完整工作平台。

## 1. 白話版結論

- **Telegram 是入口與通知器**：貼連結、交辦一句話、收到短摘要、必要時做決定。
- **Dashboard 是長期工作台**：保存完整結果，提供搜尋、知識節點、來源、關聯、討論、feedback、決策與工單追蹤。
- **聊天不是正式知識**：模型或人的討論先放在獨立 discussion；只有形成結論、取得核准並完成獨立驗證，才升格為正式知識。
- **外部服務不是生命線**：NotebookLM 或外部模型不可用時，本機查詢、討論和工單仍可運作；外部同步只標記延後，不讓主流程失敗。

## 2. 這個聊天串已完成的基礎更動

本段是現況盤點，不代表整個平台已完成。

### 工單 1346 與派工韌性

- 修正分類與 `route_to`，讓符合條件的工作可交給 Codex Builder。
- worker 失效時加入 bounded retry、fallback、root task recovery 與精確 failure reason，避免單一 worker 死亡就讓整條流程失敗。
- Builder 交付後仍要求不同、全新的 read-only Codex Verify session 驗證。
- 將政策 drift 與營運程式 drift 分開；已核准工單可在 operational drift 下繼續實作與驗證，政策 drift 仍 fail-closed。
- 外部 Codex workspace 資料傳送若受上層政策拒絕，不冒充成功，也不繞過；改用合規的本機 Builder 路徑。

### URL 與知識 intake

- Telegram 直接貼公開 URL 可建立知識候選工單。
- URL fetcher 已有基本 SSRF 防護：禁止私網、localhost、credentials，限制 redirect、內容型別與大小。
- 擷取結果會建立本機 knowledge node，保存來源、摘要、關聯建議與 AgentOS Value。
- 與既有 Knowledge Pool／系統內容做本機 deterministic 關聯比較；系統內部資料不會為此送往外部模型。
- NotebookLM 驗證或連線失敗時，知識先保存在本機並進 `pending_retry`，不再讓整張工單失敗。
- Telegram 完成回覆已朝短摘要、價值、關聯、節點與同步狀態調整。

### 已有驗證與仍待處理的狀態

- 最新 CI smoke：`data/ci_health/ci-smoke-20260720-125127.md`，結果 PASS。
- 治理正本：1.3.0，hash `0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1`。
- 現況仍為 `operational_review_required`，有 4 個營運檔 drift，不能因此宣稱 production-ready。
- NotebookLM 登入目前失效；本機知識成功保存，retry queue 有待同步項目。
- 現有 Dashboard 能看工單、流程與決策，但還沒有完整的知識搜尋、節點討論和永久 feedback。

## 3. 三個獨立模型視角的共識與分歧

### 共識

1. Telegram 不應承擔長篇瀏覽與討論；它應維持「收件、短摘要、必要通知」。
2. Dashboard 應成為 source-of-truth 的閱讀與互動介面，但 artifact 仍是可稽核正本，Dashboard 不是另一套真相。
3. discussion、feedback、candidate、正式 knowledge、ADR 與工單必須是不同物件，不能共用一段可直接覆寫的正文。
4. NotebookLM 是可選投影，不可成為建立、搜尋或討論本機知識的必要條件。
5. 所有會產生正式影響的動作，都應走同一 typed dispatch／governance gateway，而非由前端直接執行 PowerShell。
6. Dashboard 的搜尋 index、Obsidian 與 NotebookLM 都只是可重建投影；canonical artifacts 的 owner 與路徑維持唯一。

### 需要保留的張力

- 產品視角希望盡快開放完整互動；治理審查指出 Dashboard 現有寫入端點只有 localhost 保護，尚不能證明操作者是 Josh。
- 因此採取折衷：**先開本機唯讀搜尋＋隔離討論沙盒；補齊 owner authentication、CSRF、audit 與狀態機後，才開 promotion／approval／publish。**
- 關聯演算法目前只能稱為 `similarity_score` 或「建議關聯」，不能宣稱為已確認的知識關係。

## 4. 目標操作流程

```text
Telegram 貼 URL／一句交辦
        ↓
同一 typed-dispatch gateway 建立唯一工單節點
        ├─ Telegram：三行內收據、完成摘要、需要決定時通知
        └─ Dashboard：完整工單、來源、結果、時間線與知識候選
                              ↓
                    搜尋／查看節點／提出 feedback
                              ↓
                    discussion session（不污染正式知識）
                              ↓
                  結論草案：轉知識候選或轉工單草稿
                              ↓
                 Josh 核准 → Builder → fresh Codex Verify
                              ↓
                    發布新版本並留下完整回鏈
```

## 5. Dashboard 資訊架構

### 今日

- 未讀完成項
- 待 Josh 決策
- 待處理 feedback
- 失敗但可恢復的項目
- 最近工單與知識候選

### 工作

- 目的、目前狀態、阻塞、下一步與負責角色
- dispatch、worker、retry、artifact 與原始 log 收進證據抽屜
- 單一 worker 失敗不等於整張工單失敗；UI 顯示 fallback／recovery 歷程

### 知識

- 全域搜尋與篩選
- 節點詳情：結論、來源證據、版本、審查、關聯、衍生工單
- 永久 feedback 與 discussion sessions
- 同步狀態：local source-of-truth、NotebookLM current／pending_retry／dead-letter

### 決策

- 保留 ADR／Decision Map
- 可反向看到引用決策的工單、知識與 discussion resolution
- `accepted`、`landed` 等正式狀態必須有 owner identity、證據與 audit receipt

## 6. 資料與狀態模型

### 核心物件

- `source_artifact`：原始來源、final URL、擷取時間、內容 hash。
- `knowledge_node`：經發布的版本化知識，不能被聊天直接覆寫。
- `relation_suggestion`：演算法提出的相似／支持／衝突候選，待確認。
- `feedback_annotation`：append-only 註解，指向節點版本或特定 claim。
- `discussion_session`：錨定「節點版本＋問題」的討論空間。
- `candidate_package`：從討論產生、但尚未成為正式知識或工單的草案。
- `resolution_record`：採納、不採納、待研究或轉工單的不可變結論。

### Discussion lifecycle

`open → active → triage → proposed → resolved → archived`

- 對話內容預設只是討論資料。
- `resolved` 後只能產生 candidate，不得直接 publish。
- 重開問題時建立新 session 並連回舊 session，不改寫歷史。

### 正式知識升格

`discussion → candidate → awaiting_josh → approved → verified_by_fresh_codex → published`

任一 API 都不得跳階。撤回使用 tombstone／supersedes，不刪除證據。

### Read model 與 index

- 以本機 SQLite／FTS 建立可刪除重建的 derived index，記錄 `source_ref`、SHA-256、mtime、`projection_as_of` 與 `stale`。
- API 使用 versioned、cursor-paginated 介面；artifact viewer 只接受 opaque ref，不接受前端傳入任意 filesystem path。
- 修正現有資料夾 `id` 與 `dispatch_id` lookup 不一致，避免 URL intake 的日期前綴導致節點打不開。
- Dashboard 不再每次 refresh 全掃約 7,500 個 task files；由 index 增量更新並定期 reconciliation。

## 7. 分期執行計畫

### Phase 0：安全與正確性地基

目的：先讓 Dashboard 的寫入邊界可信，並修掉會妨礙繁中使用的問題。

- 修正 Dashboard／知識輸出的 UTF-8 與亂碼。
- Dashboard bind `127.0.0.1`，加入 owner authentication、短效 session、CSRF、Origin allowlist。
- 現有 workflow、approval、ADR domain POST 在完成上述保護前先關閉或置於 feature flag 後。
- audit event 記錄真實 `actor_id`、驗證方式、request id、前後狀態與 artifact hash；禁止 API 固定自稱 Josh。
- 限制 `source_json_path` canonical path 必須位於該 dispatch 的 URL intake 目錄。
- Claude review 改用嚴格 schema，只接受明確 `PASS`；`PASS_WITH_CAVEATS` 返回 candidate。
- 補 fresh read-only Codex Verify 才能正式發布的 gate。
- 修正過時的 `current_state.md`、Knowledge Pool 說明與 scope 文件；不改共同治理正本，除非內容真的改變跨角色規則。

驗收：未登入、錯誤 session、跨 Origin、CSRF 與非 owner 寫入全部 fail；路徑越界與 review 格式錯誤 fail-closed；既有唯讀功能仍可使用。

### Phase 1：唯讀知識工作台＋隔離討論 MVP

目的：先解決「Telegram 訊息消失後去哪裡找、怎麼深入討論」。

- 建立本機 knowledge index 與搜尋 API。
- API 採 `/api/v1`、cursor pagination、opaque artifact refs；搜尋結果顯示 canonical path、hash、投影時間與 stale 狀態。
- Dashboard 增加「今日」與「知識」頁面。
- 節點頁顯示來源、摘要、AgentOS Value、版本、關聯建議、審查與同步狀態。
- discussion／feedback 存在獨立 append-only storage；不得改 ADR、Knowledge Pool、TASK 或治理文件。
- 可從討論匯出 `candidate_package` 或「工單草稿」，但不直接執行。
- Telegram 完成訊息提供對應 Dashboard deep link。

驗收：可用一次搜尋找到工單 1354 的知識節點、查看原始來源與永久 feedback；NotebookLM 離線時整套本機功能仍成功。

### Phase 2：受控互動與升格

目的：讓 Dashboard 能把討論真正轉成可執行工作與可信知識。

- 啟用完整 discussion lifecycle 與 resolution record。
- candidate 經 Josh 核准後，由同一 typed-dispatch gateway 建立治理綁定工單。
- Dashboard 可組合操作意圖；需要正式影響的動作送出 Telegram command/deep link，由已驗證的 Josh Telegram identity 最後確認並產生唯一 command receipt。
- Builder、reviewer、fresh verifier 身分分離。
- 正式發布形成新版本，保留 source、discussion、approval、task、diff、test 與 verify 回鏈。
- 以 feature flags 分別控制 `discussion_write`、`promote_candidate`、`external_sync`。

驗收：discussion 無法直接跳 published；每筆正式知識均可完整回溯；關閉任一 feature 不影響唯讀查詢。

### Phase 3：知識版圖與營運成熟度

目的：從「可使用」提升到「可持續管理」。

- 一跳關聯圖、支持／衝突／相似篩選與人工確認關係。
- 每週回顧、重複主題群組、待處理 feedback 與未解問題。
- NotebookLM retry 加入有限次數、指數退避、`next_attempt_at` 與 dead-letter。
- migration 採 dry-run manifest、canary、dual-read、feature kill switch；rollback 只切 reader／flag，不刪新證據。

驗收：外部同步故障不影響本機；relation suggestion 不會自動變正式邊；migration 與 rollback 均有逐筆 receipt。

## 8. 建議的第一個實作工單

先做一個有界工單，不同時重寫整個 Dashboard：

**「Knowledge Workspace Foundation」**

範圍：Phase 0 的安全前置＋Phase 1 的唯讀知識搜尋、節點詳情、append-only discussion storage 與 Telegram deep link。promotion、正式發布與 NotebookLM 寫入預設關閉。

完成標準：

1. 工單 1354 可在 Dashboard 搜尋、打開並回溯到 `source.json`、`RESULT.md` 與本機 knowledge node。
2. 可新增一則永久 feedback，重新啟動服務後仍存在，且不改 knowledge node 正文。
3. 可開 discussion、產生 candidate package；不能直接寫 ADR／Knowledge Pool／TASK。
4. Dashboard 寫入通過 owner auth、CSRF、Origin 與 audit 測試。
5. NotebookLM 登出或網路失敗時，上述功能全部仍可用。
6. CI 新增 Dashboard security、狀態跳階、path boundary 與離線降級測試。
7. 由另一個全新 read-only Codex Verify session 出具 PASS。
8. derived index 可清空後由 canonical artifacts 完整重建，重建前後 canonical file hash 不變。

## 9. 明確不做的事

- 不把 Telegram 變成完整知識瀏覽器。
- 不讓 Dashboard 自己成為另一個 source-of-truth。
- 不讓模型對話直接改正式知識、ADR 或治理文件。
- 不讓 NotebookLM、Claude 或任一單一 worker 的故障拖垮本機主流程。
- 不以刪除歷史作為 rollback。
- 不把目前 CI smoke PASS 說成完整平台已 production-ready。

## 10. 決策建議

建議核准「Knowledge Workspace Foundation」作為下一張父工單，依 Phase 0 → Phase 1 順序實作。Phase 2 的 promotion／publish 能力待安全驗收與獨立驗證通過後，再由 Josh 單獨啟用。
