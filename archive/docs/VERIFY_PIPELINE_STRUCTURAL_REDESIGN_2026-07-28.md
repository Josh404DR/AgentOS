# Verify Pipeline 結構性改善方案 — 2026-07-28

governance_source: E:\AgentOS\AGENTS.md
relates_to: docs\VERIFY_PIPELINE_CLOSEOUT_PLAN_2026-07-28.md（那份是把手上 7 張稽核票收尾；這份是解決讓它們一直卡住的根本設計問題）

## 為什麼會一直有問題（白話版）

不完全是「語法不同造成誤解」，是兩件事疊在一起：

1. **確實有一半是語法/措辭問題。** 現在的 bundle 產生器是拿 regex 去「猜」agent 寫的 Markdown 散文裡哪一段是檔案路徑、哪一段是「這張票有沒有改東西」。同一個意思，agent 這次用 `changed_file:`，下次用 `files_modified:`，再下次直接寫在「## Scope」的一句話裡——每一種新的寫法，猜測規則就會猜錯一次。這部分確實是「格式辨識」的問題。

2. **但另一半不是語法問題，是根本沒有查核機制。** 就算 agent 講得清清楚楚、格式完全正確，系統也只是「相信 agent 自己講的」，從來沒有自己去對照磁碟上真正發生了什麼。`operational-drift-triage` revision-2 那次就是這樣：agent 說「我已經把 22 筆表格完整寫進去了」，這句話本身格式、語法都沒問題，但它實際寫進檔案的只有摘要——系統沒有任何一層會自動發現這個落差，只能等一個全新的、真的去讀檔案的 Verify session 讀出來才抓到。這不是誤解，是「說了不算，寫了才算」這件事系統從來沒有真正落實。

用一句話講：現在的系統會聽 agent「說」了什麼，但不會自己去看 agent「做」了什麼。這是設計上的洞，不是措辭習慣的問題。

## 完整改善方案（三根支柱）

### 支柱 A — 用結構化 manifest 取代文字猜測（升級既有 Evidence Contract，不另創一套）

現況：`docs\EVIDENCE_AND_REPORTING_CONTRACT.md` 第 3 節其實**早就規定**每份任務報告要有 `files_modified:`/`files_created:` 等欄位的固定區塊——問題不是沒有規格，是這份規格從 2026-06-24 訂出來後幾乎沒被遵守（依既有記錄，95 張已完成工單只有 2 張真的照格式寫），而且從來沒有任何程式碼去驗證格式對不對、內容對不對。`create_codex_verify_task.ps1` 只好退而求其次，靠 regex 去猜散文裡的意思。

改法：不新創一個 `CHANGE_MANIFEST.json` 跟現有 Evidence Contract 平行存在（那樣只會製造第二套要對齊的規格）。而是把第 3 節「Required Evidence Block」升級：

1. **格式收斂**：`files_modified:`/`files_created:` 只能是逗號分隔的路徑清單或 `not_applicable`，不得省略、不得用「見上文」這類指代。
2. **強制驗證**：`assert_governance_ready.ps1` 或 `dispatch_task_packet.ps1` 收尾時，解析這個既有區塊，格式不符（欄位缺漏、值不合法）就不允許 `status: completed`，直接落地 `status: malformed_evidence_block` 並要求重寫，不是「猜一個備援值硬撐過去」。
3. `create_codex_verify_task.ps1` 改成優先讀這個已驗證過格式的區塊，只有在完全找不到這個區塊時才退回現有的散文挖字當 legacy fallback（給還沒升級的舊格式票用，新票不應該再靠這條路徑）。

### 支柱 B — 系統自己拍照，不聽 agent 自報（解決「說了不算」的根本問題）

現況：有沒有改東西、改了哪些檔案，完全來自 agent 自己寫的文字（不管是散文還是支柱 A 的 JSON），系統從未獨立查證。

改法：`dispatch_task_packet.ps1` 在呼叫 agent **之前**自動執行一次 `git status --porcelain=v1 -uall`，存成 `BEFORE_SNAPSHOT.txt`；agent 執行**結束後**立刻再跑一次存成 `AFTER_SNAPSHOT.txt`。兩份快照的差異就是「系統自己驗證過的真實改動清單」，寫成 `git_verified_files_modified:`/`git_verified_files_created:` 兩個新欄位，直接追加在 Evidence Contract 第 3 節的既有區塊旁邊（不是另開一份平行檔案）。

如果 agent 自報的 `files_modified:`/`files_created:` 跟系統拍照算出來的 `git_verified_*` 對不上，`create_codex_verify_task.ps1` 直接在 bundle 裡標記 `evidence_manifest_mismatch: true`，並把差異列出來給 Verify session 看——這樣「agent 說做了 A，其實做的是 B」這種情況，第一時間就會被系統自己發現，不用再等一輪全新 Verify 去人工抓。

這個支柱是三個裡面影響最大的一個：它讓「驗證不自驗」這條硬規則第一次有機會被機器強制執行，而不是只能靠人或另一個 Verify session 事後抓漏。

### 支柱 C — 幫這條 pipeline 本身補上測試

現況：`create_codex_verify_task.ps1`、`dispatch_task_packet.ps1`、`task_queue_runner.ps1` 全部都是遇到真的卡住的工單才臨時補洞，從來沒有自己的測試。這是為什麼同一類 bug（scalar/array 退化、regex 跨行、路徑非法字元）會反覆用不同外貌出現。

改法：建立 `tests\test_verify_bundle_generation.ps1`，用一批 fixture TASK.md/RESULT.md/git 狀態組合（唯讀票、query-type 票、revision 票、有 Out-of-Scope 排除的票、untracked 新檔案票等，至少涵蓋這次踩過的每一種情境）跑過 `create_codex_verify_task.ps1`，斷言輸出的 `change_required`／`changed_files`／`diff_status` 符合預期。之後任何人改這支腳本，先跑這個測試，不必再拿真實工單當白老鼠。

## 建議的落地順序（2026-07-28 更新：Josh 已指示以此為優先，暫緩繼續手動收尾舊 7 張票）

1. 支柱 C 先做（風險最低，純新增測試，不改變現有行為），把這次踩過的每個 bug 都變成一個 fixture case，之後才不會又忘記。
2. 支柱 A 次之——`docs\EVIDENCE_AND_REPORTING_CONTRACT.md` 是「核心治理文件，異動需 Josh 明確核准」，這份文件本身不會自己去改它；上面支柱 A 寫的字段收斂／強制驗證規則，是**提案給 Josh 核准**的具體內容，核准後才由對應工單去改 `assert_governance_ready.ps1`／`dispatch_task_packet.ps1` 落地。
3. 支柱 B 最後做，因為它要改的是 `dispatch_task_packet.ps1` 的核心執行流程（在 agent 呼叫前後插入 git snapshot），影響面最大，且要先有支柱 A 的欄位收斂才有東西可以拿來對照。

舊的 7 張稽核票：先不繼續投入新的 revision 輪次或手動內容修補，維持現狀（已完成的兩張 PASS 不動；卡住的幾張保留現有 FAIL/pending 狀態）。等這三根支柱至少支柱 A 落地後，用新規格重新走一次會比繼續用舊工具修更划算。

## 範圍與代價的誠實說明

這是一次重新設計，不是「再修一個 bug」。三支柱都做完，保守估計是好幾張 Complex 工單的量級（新 schema、改三支核心腳本、補齊測試、更新所有 prompt 模板要求 agent 輸出 manifest），不是這個對話裡能一次改完的規模。我建議把這份文件本身當成一張新工單的規格書，正式派工（可以用 `codex_mode: plan` 先讓 Codex 出詳細實作計畫），而不是我在這個對話裡繼續手動 patch 下去——手動 patch 正是造成現在這堆散落 bug 的原因，不應該用同樣的方式來解決根本問題。
