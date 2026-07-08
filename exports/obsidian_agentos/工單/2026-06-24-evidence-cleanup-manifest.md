---
type: agentos-task
dispatch_id: "2026-06-24-evidence-cleanup-manifest"
status: "等待中"
route_to: "未標示"
governance_version: "legacy"
updated_at: "2026-06-24 08:41"
source_of_truth: "E:\\AgentOS\\data\\codex_tasks\\2026-06-24-evidence-cleanup-manifest\\TASK.md"
generated_read_only: true
---

# Task: Evidence Cleanup Manifest - Real Run

> [!warning] 衍生檢視
> 本筆記由 AgentOS 自動產生。唯一真相來源是 `E:\AgentOS\data\codex_tasks\2026-06-24-evidence-cleanup-manifest\TASK.md`，請勿以本筆記反向覆寫工單。

## 宇宙連結

- 中心：[[AgentOS 工單宇宙]]
- 狀態：[[狀態/等待中]]
- 路由：[[角色/未標示]]
- 治理：[[共同治理 vlegacy]]

## 工單資料

- 工單號：`2026-06-24-evidence-cleanup-manifest`
- 狀態：等待中
- 路由：未標示
- 更新時間：2026-06-24 08:41
- 原始工單：`E:\AgentOS\data\codex_tasks\2026-06-24-evidence-cleanup-manifest\TASK.md`
- 結果檔案：`E:\AgentOS\data\codex_tasks\2026-06-24-evidence-cleanup-manifest\OUTPUTS\RESULT.md`

## 原始工單

# Task: Evidence Cleanup Manifest - Real Run

## Objective
1. Inventory Git untracked / evidence folders / temp files.
2. Classify items (keep_canonical, keep_reference, archive_candidate, delete_candidate, ignore_by_gitignore_candidate, needs_josh_decision).
3. Produce a manifest (EVIDENCE_CLEANUP_MANIFEST.md).
4. NO deletion, NO moving, NO staging of unrelated evidence.
5. Update current_state.md and progress_log.md.
6. Real Git commit.

## Workflows
### Codex Builder Lane
- Run `git status --short`.
- List untracked files/dirs in specific areas.
- Output: `OUTPUTS\CODEX_INVENTORY.md`.

### Claude Worker Lane
- Propose classification for inventoried items.
- Output: `OUTPUTS\CLAUDE_CLASSIFICATION_PROPOSAL.md`.

### Claude Inspector Lane
- Review compliance (no deletions, no secret leaks).
- Output: `OUTPUTS\CLAUDE_INSPECTOR_REVIEW.md`.

## Constraints
- Do not delete anything.
- Do not move anything.
- Do not modify .gitignore.
- Do not stage unrelated evidence.


## 進度與實際變更

尚未產生 RESULT.md。
