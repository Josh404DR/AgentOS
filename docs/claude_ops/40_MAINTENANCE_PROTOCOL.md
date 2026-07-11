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
- [ ] `README.md`：移除硬編碼 `governance_status: aligned`，改指向 governance_status.json；
      Source of Truth 清單移除 planned-not-implemented 文件。
- [ ] `current_state.md` §3：Antigravity 段補「2026-07-08 起凍結，見 §7」；
      並建議 current_state 收斂為四節（Source of Truth／Blockers／Priority／Frozen），每項附日期。
- [ ] 新測試 fixture 改寫入 `tests\fixtures\escalations\`；ESCALATION_INDEX 新增 `is_fixture` 欄。
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

---

2026-07-09 v1.1 新增 §5「受治理路徑修改後的核准提醒」，強制 baseline 提醒行為 核准: Josh
