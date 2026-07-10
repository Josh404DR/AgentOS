# hermes_intake_menu.md
# v1.0 — 定義 Hermes 兩個固定輸入入口，讓 Josh 選單貼法開單，免記格式。

---

## Josh 怎麼用

不確定要不要成形就選【成形】；成形比直接開單多一輪確認但更準。
已經想清楚、不需要磨稿就選【直接工單】，貼了即執行。
兩種格式開頭不同（`[工單]` vs `[成形]`），Hermes 靠開頭分流，不混用。

---

## 選項一：直接工單（已想清楚，即執行）

**固定開頭：`[工單]`**

貼法：把下方空白樣板填完整，整塊貼給 Hermes。

```
[工單]
任務名稱：
執行者：
驗證者優先序：fresh Codex Verify → fresh Claude read-back
（說明：先跑 Codex Verify；不可用時降為 Claude read-back；兩者皆不可用才人工）

TASK
-----
目標：
步驟（可條列）：
預期產出：

限制
-----
- 不得改動範圍外檔案：
- 其他紅線：

回報格式
-----
changed_files: []
result_summary:
blockers:
```

---

## 選項二：需求成形（有毛坯，先磨再確認）

**固定開頭：`[成形]`**

貼法：四行填完即可，缺欄留空不擋。

```
[成形]
想要：
因為：
紅線：
急度：
```

**處理路徑：**
收到 `[成形]` 開頭，Hermes 派 Claude 依
`docs\claude_ops\36_RAW_INTAKE.md` 將毛坯磨成工單草稿，
設 `status: awaiting_josh_approval`，回 Josh 確認；
Josh 明確回覆核准前，不進入實作。
