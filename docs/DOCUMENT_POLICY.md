# AgentOS 文件治理政策（Document Policy v1.0）

created_at: 2026-08-11
created_by: Claude（Josh 2026-08-11 明確核准執行）
governance_parent: E:\AgentOS\AGENTS.md
status: active

本政策規範 `E:\AgentOS\docs\` 下所有文件的建立、歸屬與維護規則。
**目標：每份文件有明確歸屬、不重複、可追溯來源。**

---

## 1. 目錄分類規則（唯一歸屬）

每份新文件建立前，必須先確認類別。一份文件只屬於一個類別。

| 類別 | 路徑 | 判斷標準 |
|------|------|----------|
| **架構決策** | `docs/decisions/` | 為什麼這樣設計；影響長期方向；格式為 ADR-XXXX |
| **執行計畫** | `docs/plans/` | 某件事怎麼做、分幾個 phase；有明確目標與時間 |
| **操作規範** | `docs/governance/` | 誰能做什麼；哪些規則必須遵守；政策層文件 |
| **操作手冊** | `docs/guides/` | 怎麼用某個工具或流程；step-by-step 說明 |
| **評估報告** | `docs/reports/` | 某次評估/快照/調查結果；通常有日期戳記 |
| **長期路線圖** | `docs/roadmap/` | 超過一個月跨度的方向文件 |
| **Agent 行為規則** | `docs/claude_ops/` | 給 Agent 看的操作指引；僅限 Agent 行為規範 |
| **已完結/歷史** | `archive/docs/` | 被取代、計畫結束、不再參考的文件 |
| **核心參考** | `docs/` 根目錄 | 嚴格限制：只有被整個系統廣泛引用的少數文件 |

### 根目錄白名單（允許留在 docs/ 根的文件）

以下文件才能放在 `docs/` 根目錄，其餘一律進子目錄：

- `INDEX.md`（導航索引，指向所有子目錄）
- `ARCHITECTURE.md`（全系統架構參考）
- `DOCUMENT_POLICY.md`（本文件）

> 新增根目錄文件需要 Josh 明確核准，並更新本白名單。

---

## 2. 不重複規則

建立新文件前，**必須先查是否已有類似文件**：

1. 搜尋 `docs/` 下關鍵字（`rg <主題關鍵字> docs/`）
2. 確認沒有同主題文件存在
3. 如果有舊文件：
   - 若要**更新**：直接修改舊文件，不建立新文件
   - 若要**取代**：新文件加 `supersedes: <舊檔路徑>`，舊文件移至 `archive/docs/`
   - 若是**同主題不同面向**：在新文件 header 加 `related_to: <相關檔路徑>`

---

## 3. 可追溯標準（必填 Header）

每份新文件的開頭必須包含以下欄位：

```yaml
created_at: YYYY-MM-DD
created_by: Claude / Josh / Codex
source_task: <task_id 或 "manual">
status: active | reference | archived
supersedes: none          # 或填入被取代的舊文件路徑
related_to:               # 同主題相關文件（可選）
  - docs/xxx/yyy.md
```

**`status` 的意義：**
- `active`：正在使用、會被更新
- `reference`：穩定參考，不常更新但仍有效
- `archived`：已過時，移至 `archive/docs/` 時更新為此值

---

## 4. 命名規則

- **有日期的文件**（報告、計畫）：`YYYY-MM-DD-主題描述.md`，例如 `2026-08-11-hermes-lite-phase0-design.md`
- **常青文件**（規範、架構）：`全大寫-KEBAB-CASE.md`，例如 `ARCHITECTURE.md`、`DOCUMENT_POLICY.md`
- **ADR**：`ADR-XXXX-主題.md`，序號連續，不跳號

---

## 5. 維護義務

- **Agent 建立文件時**：必須先確認分類，填完 Header，放到正確路徑
- **文件過時時**：更新 `status: archived`，移至 `archive/docs/`，不得原地廢棄
- **不允許**：在根目錄白名單外建立根目錄文件、建立沒有 Header 的文件、建立與現有文件重複的文件

---

## 6. 版本歷史

- 2026-08-11 v1.0 建立，Josh 核准（2026-08-11 對話明確指示「可以執行」）
