# Test Result

dispatch_id: 2026-07-26-operational-drift-triage
executed_at: 2026-07-26T22:03:18+08:00..2026-07-26T22:05:08+08:00
environment: Windows PowerShell / CodexSandboxOffline
builder_role: Codex Builder
overall_status: PASS
self_verification_claimed: false

## Governance gate（重新執行）

完整指令：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\scripts\assert_governance_ready.ps1
```

Exit code: `0`

原始輸出：

```text
governance_gate=passed
governance_status=operational_review_required
governance_version=1.3.0
governance_hash=0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
governance_checked_at=2026-07-26T22:03:22.8365888+08:00
task_execution_allowed=true
token_cost=0
model_calls=0
operational_drift_count=22
```

結果：PASS；task execution allowed。數量與來源稽核相同。

## Task-bound governance gate（worker／Verify 前重比對）

完整指令：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\scripts\assert_governance_ready.ps1 -TaskPath E:\AgentOS\data\codex_tasks\2026-07-26-operational-drift-triage\TASK.md
```

執行時間：`2026-07-26T22:05:59+08:00`

Exit code: `0`

原始輸出：

```text
governance_gate=passed
governance_status=operational_review_required
governance_version=1.3.0
governance_hash=0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
governance_checked_at=2026-07-26T22:05:59.9054991+08:00
task_execution_allowed=true
token_cost=0
model_calls=0
operational_drift_count=22
```

結果：PASS；工單綁定版本與 hash 均與即時治理狀態一致。

## Scanner operational drift 原始清單

掃描完成後以 UTF-8 讀取：

```powershell
$s = Get-Content -Raw -LiteralPath 'data\governance\governance_status.json' -Encoding UTF8 | ConvertFrom-Json
$s.operational_drift | ConvertTo-Json -Depth 4
```

原始資料：

```text
hash_changed       current_state.md
not_in_baseline    dashboard\backend\dashboard_security.py
not_in_baseline    dashboard\backend\knowledge_workspace.py
hash_changed       dashboard\backend\main.py
not_in_baseline    dashboard\dashboard_orphan_guard.ps1
hash_changed       dashboard\DASHBOARD_SCOPE.md
hash_changed       dashboard\frontend\app\page.tsx
hash_changed       dashboard\frontend\components\ApprovalQueue.tsx
hash_changed       dashboard\frontend\components\DecisionMap.tsx
not_in_baseline    dashboard\frontend\components\KnowledgeWorkspace.tsx
not_in_baseline    dashboard\frontend\components\OwnerSession.tsx
not_in_baseline    dashboard\frontend\components\TodayWorkspace.tsx
hash_changed       dashboard\frontend\lib\api.ts
hash_changed       dashboard\start.ps1
hash_changed       integrations\hermes_plugins\agentos-typed-dispatch\__init__.py
hash_changed       scripts\hermes_claude_bridge.ps1
hash_changed       scripts\hermes_codex_bridge.ps1
hash_changed       scripts\publish_url_knowledge.ps1
hash_changed       scripts\task_queue_runner.ps1
hash_changed       scripts\typed_dispatch.ps1
hash_changed       scripts\url_intake_task_packet.ps1
hash_changed       scripts\url_intake_worker.ps1
```

## Exact-path Git porcelain

指令模板（對上述 22 個 scanner path 逐一執行）：

```powershell
git -c safe.directory=E:/AgentOS status --porcelain=v1 -uall -- <exact-path>
```

原始結果：

```text
 M current_state.md
?? dashboard/backend/dashboard_security.py
?? dashboard/backend/knowledge_workspace.py
?? dashboard/backend/main.py
?? dashboard/dashboard_orphan_guard.ps1
?? dashboard/DASHBOARD_SCOPE.md
?? dashboard/frontend/app/page.tsx
?? dashboard/frontend/components/ApprovalQueue.tsx
?? dashboard/frontend/components/DecisionMap.tsx
?? dashboard/frontend/components/KnowledgeWorkspace.tsx
?? dashboard/frontend/components/OwnerSession.tsx
?? dashboard/frontend/components/TodayWorkspace.tsx
?? dashboard/frontend/lib/api.ts
?? dashboard/start.ps1
 M integrations/hermes_plugins/agentos-typed-dispatch/__init__.py
 M scripts/hermes_claude_bridge.ps1
 M scripts/hermes_codex_bridge.ps1
?? scripts/publish_url_knowledge.ps1
 M scripts/task_queue_runner.ps1
 M scripts/typed_dispatch.ps1
 M scripts/url_intake_task_packet.ps1
 M scripts/url_intake_worker.ps1
```

歸納：modified 8、deleted 0、untracked 14，合計 22。

## Risk scan

讀取：

```powershell
Get-Content -LiteralPath 'docs\governance\RISK_RULES.md' -Encoding UTF8
git -c safe.directory=E:/AgentOS diff --numstat -- scripts/task_queue_runner.ps1
(Get-FileHash -Algorithm SHA256 -LiteralPath 'scripts\task_queue_runner.ps1').Hash
```

結果：

```text
224     13      scripts/task_queue_runner.ps1
6A9918F37D7CAF5F81D1CB9D4C1458CB499AF5050B02EED893C9AAFDD51834B0
```

最近獨立 PASS artifact
`governance-v1.3-root-resilience-20260718-revision-3\OUTPUTS\RESULT.md`
記錄的 Queue hash 為 `721A4A12...865F`，與現況不同。依 Risk Rules
命中大型核心 Queue 重構且缺少可證實精確工單範圍，故建立 escalation：

```text
escalation_status=created
escalation_path=E:\AgentOS\data\escalations\2026-07-26-operational-drift-triage\20260726-220455-573.json
escalation_index=E:\AgentOS\data\escalations\ESCALATION_INDEX.jsonl
```

## Verified hash spot-check

```text
8D0B66CD5579C0964C92A5716669F67F226C3B498F96277D5844804CFD9A0CBD  dashboard\backend\dashboard_security.py
1A2F0C3EC1FD9FB7F2BA824462F7C1FA946A1BDAD7A3B1571F109CC8AB9AE6DD  dashboard\backend\knowledge_workspace.py
A85496801C6471A485E76B39E75FBE7B0E5E75B558CBD5BF03A05D9B90DA0316  dashboard\frontend\components\KnowledgeWorkspace.tsx
5573CE95FE5A05B49C45B63382EE32C23CC40B84C6ED9A9458C03EA7252EB1CC  dashboard\frontend\components\TodayWorkspace.tsx
1DE29323A9A5FBFCF310CD1075902885F8BCC465D282F9FD15652E41DA140761  dashboard\frontend\lib\api.ts
26ABF35409A93D1C246402EBB4C346A1DE81933C1D1CD5FBB89E9EC536925445  dashboard\DASHBOARD_SCOPE.md
B75A780A7525E5082686E25923E36AAB8A1799F7DC5C91CD6BD810B03D4EC388  dashboard\frontend\components\DecisionMap.tsx
A3449956B97B8B64AE611A898A9D944BF078DD3C660FBED9E5565A889CE18963  integrations\hermes_plugins\agentos-typed-dispatch\__init__.py
```

## Git mutation assertion

本工單未執行 `git add`、`git commit`、`git push`、`git reset`、
`git checkout`。只執行 read-only Git status/diff/hash 查詢並新增本工單
兩份 OUTPUTS；另依 Scope 透過既有介面追加 escalation artifact/index。

## Acceptance status

- AC1：PASS（22 項完整表格及數量口徑）。
- AC2：PASS（每群獨立 verified/unverified 結論）。
- AC3：PASS（verified 群逐檔 exact path，無 wildcard 或 `.`）。
- AC4：PASS（本檔保留完整 gate 指令、時間戳及原始輸出）。
- AC5：PASS（第三個全新 read-only Codex Verify session）。

## Independent Verify round 1

第一個全新隔離 read-only session 結論：

```text
verify_verdict: FAIL
```

Failure reasons：

- RESULT 宣稱 staging 9 個路徑，但實際為 8 個。
- 除 G1 外，G2/G3/G4 的舊 Verify artifacts 未將目前檔案 hash 綁回
  當時被驗證內容；不能據此建議 staging。
- 首次記錄的 gate 指令未帶 `-TaskPath`。

Builder correction：

- 修正 staging 數量為 1，並移除 G2/G3/G4 staging 建議。
- 將 G2/G3/G4 全部降為 `unverified`。
- 補記已實際執行且 PASS 的 task-bound governance gate 與原始輸出。

## Independent Verify round 2

第二個全新隔離 read-only session 結論：

```text
verify_verdict: FAIL
```

唯一 failure reason：分群摘要將 G7 寫成 7 個路徑，但完整表實際為
6 個；加上 G8 的 1 個 Queue 路徑後，原摘要合計誤為 23。

Builder correction round 2：只將 G7 路徑數由 7 修正為 6；8 群摘要
現合計 `1+5+1+1+6+1+6+1=22`。這是本工單允許的第二輪 Builder 修正。

## Independent Verify round 3

第三個全新隔離 read-only session 結論：

```text
verify_verdict: PASS
```

驗證確認：22 個唯一路徑各一次；8 群計數合計 22；Git 類型為
modified 8、deleted 0、untracked 14；僅 G1 有現況 hash 與獨立 Verify
artifact 精確綁定；唯一 staging 指令為 G1 單一 exact path；G8
escalation artifact/index 均為 `awaiting_josh`。
