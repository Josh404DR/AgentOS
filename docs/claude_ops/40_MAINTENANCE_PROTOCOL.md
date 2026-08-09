# 制度檔維護協議（Maintenance Protocol v1.1）

governance_parent: E:\AgentOS\AGENTS.md
管轄範圍：`CLAUDE.md` 與 `docs\claude_ops\` 全部檔案。
本檔本身的修改規則見 §2（屬「先問 Josh」類）。

---

## 1. 修改權限分級

**模型可自行改（改完在回報中告知即可）：**
- `00_DIAGNOSIS.md` 的「Live 環境待確認清單」區（把 [推定] 改成事實）。
- `50_LESSONS.md`（教訓日誌，append-only，見 §4）。
- `30_DELEGATION_TEMPLATES.md`：新增模板、微調欄位措辭（不得刪既有模板或改通用約束段）。
- 各檔的錯字、失效路徑修正（修正本身要附證據：舊路徑 `test -f` 失敗、新路徑成功）。

**先問 Josh 才能改：**
- `CLAUDE.md`（每 session 載入，是最高槓桿也最高風險的檔）。
- `10_DISPATCH_RULES.md`、`20_JUDGMENT_RUBRICS.md` 的任何規則增刪（措辭修正除外）。
- 本檔的權限分級本身。
- 任何會放寬驗證要求或安全邊界的修改——這類提案要額外附「放寬後最壞情況」分析。

**模型永遠不准做：**
- 刪除任何制度檔或備份檔（AGENTS.md §3 刪除規則適用）。
- 修改 `AGENTS.md` 與角色檔（治理層，走治理變更流程）。
  （`current_state.md` 的狀態更新依既有治理照常進行，不受本檔管轄；本檔只管 claude_ops。）

## 2. 修改程序（適用所有允許的修改）

1. 改前備份：`copy <檔> <檔>.bak-<YYYY-MM-DD>`（同日多次改沿用同一備份）。
2. 改後由 fresh agent 用模板 T5 read-back（驗收條件＝本次修改意圖）。
3. 回報 Josh：改了哪檔哪節、動機、驗證結果。

## 3. 對既有正本的待辦修正案（需 Josh 逐項核准，證據見 00_DIAGNOSIS）

- [ ] `agents/roles/claude.md`：刪 "Read-Only by Default" 與舊 Inspector 職責段，改為引用 AGENTS.md §2。
      **2026-08-08 狀態**：仍未修。屬本輪(2026-08-08 治理 drift 清理)發現的 ~46 支已追蹤但修改中核心角色/治理檔案之一，故意留給下一輪專門稽核，不在本輪範圍。
- [x] `README.md`：移除硬編碼 `governance_status: aligned`部分已修好；
      Source of Truth 清單移除 planned-not-implemented 文件**尚未修**（`PRE_FLIGHT_TEST_PLAN.md` 仍列在清單，2026-08-08 docs 一致性稽核確認）。
- [ ] `current_state.md` §3：Antigravity 段補「2026-07-08 起凍結，見 §7」；
      並建議 current_state 收斂為四節（Source of Truth／Blockers／Priority／Frozen），每項附日期。
      **2026-08-08 狀態**：current_state.md 本身已於本輪首次進版控(commit `8e658d5`)，但內容結構未依此項建議收斂，僅同步了既有內容，此項仍待辦。
- [x] 新測試 fixture 改寫入 `tests\fixtures\escalations\`；ESCALATION_INDEX 新增 `is_fixture` 欄。
      **2026-08-08 已解**：`ci-queue-01-always-fail-*` 測試污染正式佇列問題已修復(commit `6836cc0`)，做法是貫穿既有 `write_escalation.ps1` 的 `-Environment`/`is_fixture` 機制，而非另建隔離 fixture 目錄，效果等同。
- [ ] `docs/temp_routing_rules.txt` 歸納進正式文件或標 historical。
- [ ] 治理變更提案：AGENTS.md §4 允許「明確標記 estimate 的 token 粗估」寫入 METRICS_LOG，
      以修復度量迴路（現行條文禁止估算值，未核准前一律填 unknown）。

## 4. 踩坑教訓寫哪裡、什麼格式

- 位置：`docs\claude_ops\50_LESSONS.md`（append-only；不存在就建立，首行寫本節格式說明）。
- 什麼算「坑」：花了 >15 分鐘才發現的錯誤前提、重複第二次的失敗、驗證漏抓的問題。
- 格式（一坑一段，全部欄位必填）：

```text
## <YYYY-MM-DD> <一句話標題>
症狀: <當時看到什麼>
根因: <真正原因>
修法: <當下怎麼解的>
制度化: <none | 已提案改哪個檔哪節>
```

- 「制度化」欄是重點：教訓若值得變成規則，走 §1 權限提案；只是個案就填 none。
  不是每個坑都要變規則——規則有載入成本。

## 5. 受治理路徑修改後的核准提醒（v1.1，2026-07-09 起強制）

任何工單的 `changed_file` 落在下列範圍，完成回報時必須附加提醒：

> ⚠️ 本次新增／修改了受治理檔案，若不先跑 baseline 核准，下一張工單會被 governance gate 擋下：
> ```powershell
> powershell -ExecutionPolicy Bypass -File "E:\AgentOS\scripts\sync_shared_governance.ps1" -ApproveBaseline
> ```

**觸發範圍：**
- `prompts\**\*.md`、`prompts\**\*.txt`
- `docs\claude_ops\**`
- `AGENTS.md`、`CLAUDE.md`、`current_state.md`
- `dashboard\` 下 `*.py`、`*.ts`、`*.tsx`

本條屬 §1「先問 Josh 才能改」類（改變了完成回報的必要內容）。
本次視為 Josh 已核准（2026-07-09 對話明確指示），直接生效，標 v1.1。

## 6. 精簡週期

- 觸發條件（任一）：`50_LESSONS.md` 超過 30 段、`docs\claude_ops\` 總量超過 40KB、
  或 Josh 說「制度檔太肥」。
- 做法：提案（不自行執行刪除）——哪些教訓已制度化可歸檔、哪些規則從未被引用可降級；
  歸檔去處 `archive\claude_ops\<日期>\`。Josh 核准後執行。
- 判斷「規則從未被引用」的方法：在 `docs\claude_ops\50_LESSONS.md` 與最近 30 天的 dispatch 回報
  （`data\metrics\METRICS_LOG.jsonl`）中 rg 該規則編號；零命中滿一個月即候選。

## 7. 版本標記

每個制度檔首部保留 `v<major>.<minor>`；規則增刪 +minor，權限或結構變動 +major。
改版時在該檔末尾追加一行 changelog：`<日期> v<版本> <一句話> <核准: Josh|self>`。

## 8. 收尾稽核義務（Close-the-Loop Duty，v1.2，2026-08-08 起強制）

**背景**：2026-08-08 一輪治理 drift 清理發現多起「已正確診斷、甚至寫進待辦清單或 escalation，但從未真正執行收尾」的案例（本檔 §3 至少 2 項卡逾一個月；`2026-07-26-operational-drift-triage` risky escalation 卡 12 天；`2026-07-06-python-runtime-repair` 卡逾一個月；`AGENTS.md`/`CLAUDE.md` 從未進版控卻沒人發現）。診斷與決策本身沒有問題，問題出在沒有任何機制強迫回頭檢查「這件事後來真的做了嗎」。

**規則**：任何 Claude/Codex session 執行下列任一類工作時，**開工前必須先做一次「已知未結案項目」掃描，並在完成回報中明確列出掃到的項目與其現況（處理／確認仍待辦／發現已過時可關閉）**，不得略過：

- 治理／drift／稽核類工單。
- 修改 `docs\claude_ops\**`、`AGENTS.md`、角色檔（`agents\roles\*.md`）的工單。
- 任何工單本身的動機是「處理某個先前發現的問題」。

**掃描範圍（至少涵蓋）**：
1. `docs\claude_ops\40_MAINTENANCE_PROTOCOL.md` §3 待辦清單中未打勾項目。
2. `docs\claude_ops\50_LESSONS.md` 中「制度化」欄不是 `已落地` 的條目。
3. `data\codex_tasks\**\TASK.md` 中 `task_status: approval_required` 且對應 `OUTPUTS\` 為空的工單。
4. `data\escalations\ESCALATION_INDEX.jsonl` 中 `status: awaiting_josh`、`is_fixture` 非 `true`、且對應資料夾無 `RESOLUTION.json` 的項目（注意 index 是 append-only 快照，須實際查資料夾，不能只信 index 的 status 欄位——這正是本次踩過的坑，見 50_LESSONS 對應條目）。

**不強制立即修復**：掃到的舊項目不必在本次工單一併處理完，但必須在回報中明確點名、附現況判斷；若判斷已過時/不再相關，要附理由才能標記關閉，不能靜默略過。

**待辦（尚未落地，需後續工單）**：本條目前是人工掃描義務，尚未有對應的確定性腳本（依 AGENTS.md §6 精神，應優先用腳本而非仰賴模型記得）。建議另開工單，在 `scripts\assert_governance_ready.ps1` 或新腳本中加入上述 4 項的自動掃描與計數，取代人工掃描，掃描結果算數值計算不呼叫模型。

---

2026-07-09 v1.1 新增 §5「受治理路徑修改後的核准提醒」，強制 baseline 提醒行為 核准: Josh
2026-08-08 v1.2 新增 §8「收尾稽核義務」，強制已知未結案項目掃描 核准: Josh（2026-08-08 對話明確指示：「寫進治理文件確保我們每次都會做這件事情」）
