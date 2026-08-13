# Escalation 分類整理

triage_date: 2026-07-08
triage_by: Claude

---

## 測試 Fixture（不是真實待辦，可忽略）

| task_id | 原因 |
|---|---|
| `2026-07-03-workflow-v1-2-risky-fixture` | 名稱含 "fixture"，為 workflow 測試資料 |
| `2026-07-03-workflow-v1-2-dedupe-fixture` | 名稱含 "fixture"，reason: fixture |
| `2026-07-03-workflow-v1-2-live-simple-smoke` | smoke test，非真實業務工單 |
| `2026-07-06-learning-collector-dedupe-fix` | 內部 worker contract 測試失敗，非客戶案 |

---

## 已超時 / 脈絡已消失（建議關閉）

| task_id | 原因 |
|---|---|
| `telegram-...-1183-20260703` | 6/3 的 deletion+credentials 攔截，距今已 5 週，脈絡消失 |
| `telegram-...-1186-20260703` | 同上，重複發送的同一批工單 |
| `telegram-...-1189-20260703` | invalid_or_missing_verify_verdict，源自 6/3 工單 |
| `telegram-...-1203-20260704-child-01-revision-1` | sandbox_blocks_required_live_evidence，無法自動解決 |
| `telegram-...-1203-20260704-child-01` | codex_verify_needs_human_decision，來源工單已超時 |

---

## 分類器誤判（今日已發生，已瞭解）

| task_id | 原因 |
|---|---|
| `telegram-...-1223-20260708` | risk: deletion，但工單明確禁止刪除，屬誤判 |
| `telegram-...-1228-20260708` | 同上，重新發送版本 |

---

## 真實待辦（需 Josh 決策）

| task_id | 原因 | 建議行動 |
|---|---|---|
| `telegram-...-1203-20260704` | Hermes gateway autostart audit 涉及 credentials | Josh 確認是否繼續這個 audit |
| `telegram-...-1216-20260706` | external_write 攔截 | Josh 確認該工單內容是否核准 |
| `telegram-...-1214-...-smoke-test` | revision_limit_reached，smoke test 兩輪 FAIL | 參考稽核報告 W05，建議關閉：smoke test 本身的 artifact 格式問題，非真實錯誤 |

---

## 建議

1. Fixture 四筆 → 可直接在 ESCALATION_INDEX.jsonl 標記 `status: closed_fixture`（需 Josh 核准寫入）
2. 超時五筆 → 標記 `status: closed_stale`
3. 誤判兩筆 → 今日已處理（工單已用改寫版重發）
4. 真實待辦三筆 → Josh 回到電腦後逐一決策
