---
type: agentos-task
dispatch_id: "2026-07-02-dispatcher-upgrade-spec"
status: "等待中"
route_to: "Codex"
governance_version: "1.1.0"
updated_at: "2026-07-02 01:48"
source_of_truth: "E:\\AgentOS\\data\\codex_tasks\\2026-07-02-dispatcher-upgrade-spec\\TASK.md"
generated_read_only: true
---

# Task Packet: Upgrade dispatch_task_packet.ps1 to Canonical Execution Entry Point

> [!warning] 衍生檢視
> 本筆記由 AgentOS 自動產生。唯一真相來源是 `E:\AgentOS\data\codex_tasks\2026-07-02-dispatcher-upgrade-spec\TASK.md`，請勿以本筆記反向覆寫工單。

## 宇宙連結

- 中心：[[AgentOS 工單宇宙]]
- 狀態：[[狀態/等待中]]
- 路由：[[角色/Codex]]
- 治理：[[共同治理 v1.1.0]]

## 工單資料

- 工單號：`2026-07-02-dispatcher-upgrade-spec`
- 狀態：等待中
- 路由：Codex
- 更新時間：2026-07-02 01:48
- 原始工單：`E:\AgentOS\data\codex_tasks\2026-07-02-dispatcher-upgrade-spec\TASK.md`
- 結果檔案：`E:\AgentOS\data\codex_tasks\2026-07-02-dispatcher-upgrade-spec\OUTPUTS\RESULT.md`

## 原始工單

# Task Packet: Upgrade dispatch_task_packet.ps1 to Canonical Execution Entry Point

dispatch_id: 2026-07-02-dispatcher-upgrade-spec
assigned_to: Codex
route_to: Codex
codex_mode: build
impact_scope: core_script
target: E:\AgentOS\scripts\dispatch_task_packet.ps1
task_status: ready
source: claude_inspector_spec
created_by: Claude (Cowork, Inspector role)
created_at: 2026-07-02 01:47 Asia/Taipei
governance_version: 1.1.0
governance_hash: 5bb3d898432b05cbc03049eabe15ec8c39dd9fc92f67108d2353687d319e7e38

## Josh's Mandate (binding constraint)

Josh reviewed the Inspector diagnosis and approved this scope with one hard constraint:

> Do NOT create a second/parallel dispatcher. Upgrade the existing
> `scripts/dispatch_task_packet.ps1` into the single canonical execution entry
> point for the AgentOS Autonomous Coordination Mode.

Josh will review this spec against the actual current script contents himself
before authorizing implementation. Codex must independently re-verify every
claim below against the live file contents at execution time — scripts may
have changed since this spec was written, and this spec does not carry
implementation authority on its own; it is Inspector analysis pending Josh's
review.

## Author / Role Boundary

Written by Claude (Cowork) acting strictly as **Inspector**: read-only
analysis only. No files inside `E:\AgentOS` were modified to produce the
content below prior to this task packet. Implementation is Codex's
responsibility per AGENTS.md §2 (Claude default is reviewer; Codex is the
primary technical executor).

---

## 1. Evidence Base (verified by direct file read, not inferred)

| File | Verified role | Verified gap |
|---|---|---|
| `scripts/typed_dispatch.ps1` | Deterministic router + prompt assembler. Reads a `[TYPE: ...] [GOAL: ...]` typed request, maps `TYPE` to a route (`CODEX_BUILD`, `CODEX_VERIFY`, `CLAUDE_WORKER`, `CLAUDE_REVIEW`, `OLLAMA_TRIAGE`, `JOSH_APPROVAL`, `GEMINI_PREMIUM`, `STOP`), writes `data\routing_decisions\<id>\ROUTING_DECISION.md` and `ASSEMBLED_PROMPT.md`. Calls the governance gate (no `-TaskPath`) to stamp current `governance_version`/`governance_hash` into its own output (lines 17-21, 132-133). | Never invokes any model/CLI. Pure planning artifact. |
| `scripts/dispatch_task_packet.ps1` | Reads `data\codex_tasks\<DispatchId>\TASK.md`, parses `assigned_to` (regex, lines 24-37), resolves to one of `Claude Worker` / `Claude Inspector` / `Ollama` (lines 49-75), calls the governance gate **with** `-TaskPath` (lines 85-90, matches `assert_governance_ready.ps1`'s task-binding check). | No `Codex` route exists. Bridge invocation passes only a synthetic sentence (`"Process AgentOS task packet: $TaskPath"` / `"Inspect AgentOS task packet: $TaskPath"`, lines 54, 61) -- the actual TASK.md content is loaded into `$taskText` (line 92) but never passed to the invoked agent. Bridge output lands under `data\live_bridge\...`, never copied to `data\codex_tasks\<DispatchId>\OUTPUTS\RESULT.md`. |
| `scripts/hermes_claude_bridge.ps1` | Connectivity-test pipeline: Hermes drafts a message, `claude -p` answers, Hermes summarizes. | Hard-coded test prompt; no packet awareness; writes only to `data\live_bridge\claude_<id>\`. |
| `scripts/hermes_tripartite_bridge.ps1` | Connectivity-test pipeline: Hermes dispatch -> `codex exec --sandbox read-only` -> `claude -p` review -> Hermes summary (ASCII + zh-TW). | Hard-coded `-TaskSeed`; no packet awareness; `--sandbox read-only` is unconditional, which is only correct for verify/review-style work, not build work; writes only to `data\live_bridge\tripartite_<id>\`. |
| `scripts/assert_governance_ready.ps1` | When called with `-TaskPath`, regex-extracts `governance_version:` / `governance_hash:` from the task file and requires them to match the live baseline, else `governance_gate=blocked, reason=task_governance_binding_missing` (exit 24) or `reason=governance_version_mismatch` (exit 25). | Works correctly today, but only if the caller (TASK.md author) actually stamped those two fields at creation time. A prior example task (`data\codex_tasks\2026-06-30-local-file-telegram-...\TASK.md`) had no `governance_version`/`governance_hash` fields and used `route_to: Codex`, which could never have gone through `dispatch_task_packet.ps1` anyway (no Codex route exists) -- confirming real usage has been bypassing the formal dispatcher. |

## 2. Target End-to-End Flow

```
Josh / Hermes intent
  -> typed_dispatch.ps1  (classify + assemble; stamps governance_version/hash; writes ROUTING_DECISION.md + ASSEMBLED_PROMPT.md)
  -> [NEW] formal TASK.md creation step (see 3.1)
  -> dispatch_task_packet.ps1  (UPGRADED -- single execution entry point, see 3.2-3.6)
       -> Codex (build or verify sandbox) | Claude (worker or inspector) | Ollama
  -> data\codex_tasks\<DispatchId>\OUTPUTS\RESULT.md  (unified schema, see 3.5)
  -> [conditional] CLAUDE_REVIEW child dispatch  (deterministic rule, see 3.6)
  -> Hermes zh-TW standard report to Josh
```

No new top-level script is introduced. `typed_dispatch.ps1` keeps its current
job (planning only). `dispatch_task_packet.ps1` becomes the only script that
ever invokes an agent CLI.

## 3. Required Changes (7 items)

### 3.1 Formal TASK.md creation must precede dispatch, and must carry governance binding

- Whatever creates `data\codex_tasks\<DispatchId>\TASK.md` (Hermes, or a thin
  helper script) must call `assert_governance_ready.ps1` **without**
  `-TaskPath` first (same pattern already used inside `typed_dispatch.ps1`,
  lines 17-21) to obtain the current `governance_version` / `governance_hash`,
  then write them into the TASK.md as plain fields:
  ```
  governance_version: <value>
  governance_hash: <value>
  ```
- `dispatch_task_packet.ps1` already calls the gate with `-TaskPath` (line 86)
  -- this enforces the binding check correctly today. The missing piece is
  purely upstream: guarantee every TASK.md has these two fields before
  dispatch is attempted. Add a pre-check in `dispatch_task_packet.ps1` that
  fails fast with a clear message (not the generic gate error) if these
  fields are absent from `TASK.md`, since a missing field is a
  packet-authoring bug, not a governance drift.
- If `typed_dispatch.ps1`'s `ASSEMBLED_PROMPT.md` is used as the source for
  TASK.md content, the TASK.md author should copy `governance_version` /
  `governance_hash` straight from `ROUTING_DECISION.md` rather than
  re-querying the gate a second time, to avoid a race where the baseline
  changes between the two calls.

### 3.2 Add a Codex route, split by sandbox mode

- Extend `Resolve-Route` to accept `assigned_to: Codex` (currently only
  `Claude Worker` / `Claude Inspector` / `Ollama`, lines 49-75).
- A single `Codex` label is not enough -- build and verify work need
  different sandbox permissions. TASK.md must carry an explicit,
  deterministic mode field (do not infer from free text):
  ```
  codex_mode: build   # or: verify
  ```
  populated from the original `TYPE` (`CODEX_BUILD` vs `CODEX_VERIFY`) at
  TASK.md creation time, so the distinction survives from
  `typed_dispatch.ps1`'s decision through to execution.
- Mapping (confirm the exact accepted `--sandbox` values against the
  installed `codex` CLI's own help/docs before hardcoding -- do not assume
  the flag name below is final):
  - `codex_mode: verify` -> same pattern as the existing tripartite bridge:
    `codex exec --sandbox read-only ...`
  - `codex_mode: build` -> requires a sandbox mode that permits workspace
    writes. This is materially higher-risk than every other existing route,
    so treat `codex_mode: build` as requiring the same approval-evidence
    check as any other Josh-gated action (3.4), even if the route map does
    not otherwise mark it `approval_required`.

### 3.3 Pass real task content, not a path reference

- Today: `-ClaudePrompt "Process AgentOS task packet: $TaskPath"` /
  `-TaskSeed "Inspect AgentOS task packet: $TaskPath"` (lines 54, 61).
  Neither bridge script reads the file at that path -- the agent only ever
  sees a sentence naming a file, never the file's contents. `$taskText` is
  already loaded at line 92 and is currently unused for this purpose.
- Two options, pick one and document the choice:
  1. **Minimal patch**: pass `$taskText` itself as the value of
     `-ClaudePrompt` / `-TaskSeed` instead of the synthetic sentence. Lowest
     diff, but keeps the bridge's own "Hermes drafts a message about this"
     layer, which adds an extra model call and latency for no benefit when
     the task is already fully specified.
  2. **Preferred**: have `dispatch_task_packet.ps1` invoke the underlying
     CLIs directly (`codex exec ...` / `claude -p ...`) with the real
     TASK.md/`ASSEMBLED_PROMPT.md` content, bypassing the bridge scripts'
     redundant Hermes-drafting step entirely for packet-driven dispatch. The
     bridge scripts can remain as-is for their original purpose (ad-hoc
     connectivity smoke tests), separate from the packet path.

### 3.4 Approval gate must check `dispatch_status`, not the `requires_josh_approval` flag

- Evidence: `typed_dispatch.ps1` line 122 -- `requires_josh_approval` can
  remain `true` in `ROUTING_DECISION.md` even after Josh has approved,
  because approval is recorded via a separate `[APPROVAL: ...]` field that
  flips `dispatch_status` from `approval_required` to `ready_to_route`.
  Checking the flag alone would permanently block already-approved work;
  checking only for the flag's absence would under-gate.
- Required check in `dispatch_task_packet.ps1` before invoking any agent:
  1. `dispatch_status` (read from `ROUTING_DECISION.md`, or the equivalent
     field if carried into TASK.md) must equal `ready_to_route`.
  2. If the route requires approval (`requires_josh_approval=true` at
     decision time, or `codex_mode: build` per 3.2), a populated,
     non-empty approval evidence field must also be present (e.g.
     `approval:` field with a real value -- who/when approved, not just a
     boolean). Absence of either condition -> stop, do not invoke any CLI,
     emit `status=approval_required` and let Hermes surface it to Josh.
     This mirrors AGENTS.md's "核准前不得執行".

### 3.5 Unified `OUTPUTS/RESULT.md` regardless of route

- Every successful dispatch -- Codex, Claude, or Ollama -- must end with a
  write to `data\codex_tasks\<DispatchId>\OUTPUTS\RESULT.md`, replacing
  today's behavior where output only lands under `data\live_bridge\...`.
- Minimum required fields:
  ```
  dispatch_id: <id>
  route_to: <Codex|Claude|Ollama>
  codex_mode: <build|verify|n/a>
  governance_version: <carried through from TASK.md>
  governance_hash: <carried through from TASK.md>
  status: <completed|partial_failure|blocked>
  models_invoked: <true|false>
  scripts_executed: <true|false>
  cleanup_executed: false
  findings: <summary>
  caveats: <known gaps/risks>
  ```
- `dispatch_task_packet.ps1` should be the single place responsible for
  writing this file after the underlying CLI call returns, not each
  bridge/CLI path individually -- keeps one canonical writer, avoids format
  drift between routes.

### 3.6 Deterministic `CLAUDE_REVIEW` auto-trigger with anti-loop guarantees

- Trigger condition (deterministic, not inferred from prose): auto-create a
  `CLAUDE_REVIEW` child dispatch **only when both** are true:
  1. The just-completed dispatch's `route_to` was `Codex` with
     `codex_mode: build` (verify-only Codex work does not need a second
     review by default).
  2. TASK.md carries an explicit `impact_scope` field set at creation time --
     `client_facing` or `core_script` -- not inferred by keyword matching
     after the fact. `impact_scope: internal_only` never auto-triggers
     review.
- Anti-loop rules:
  - A dispatch whose own `route_to` is `Claude` (either `CLAUDE_WORKER` or
    `CLAUDE_REVIEW`) must **never** auto-trigger a further `CLAUDE_REVIEW` of
    itself, regardless of `impact_scope`. Review depth is capped at 1.
  - Every auto-created review dispatch must carry
    `parent_dispatch_id: <original id>`. Before creating one, check whether a
    dispatch with that `parent_dispatch_id` and `type: CLAUDE_REVIEW`
    already exists; if so, skip (idempotent).

Note: this TASK.md itself is `route_to: Codex`, `codex_mode: build`,
`impact_scope: core_script` -- per the rule above, its own completion SHOULD
auto-trigger exactly one `CLAUDE_REVIEW` child dispatch once the
`dispatch_task_packet.ps1` upgrade is implemented and this task's
`OUTPUTS/RESULT.md` is written. Until the upgrade itself exists, that
auto-trigger cannot run automatically for this task -- Josh may dispatch a
manual `CLAUDE_REVIEW` of the implementation once complete.

### 3.7 Reporting

- Final Hermes-to-Josh report should follow the format already defined in
  `prompts/context_packs/autonomous_coordination_prompt.md` Part A step 6
  (checkmark/folder/note/hourglass markers, Traditional Chinese), sourced
  from the unified `RESULT.md` written in 3.5 -- no new report format
  needed.

## 4. Explicit Non-Goals

- Do not create a second dispatcher script. `dispatch_task_packet.ps1` is the
  only execution entry point after this change.
- Do not remove or rename the existing `Claude Worker` / `Claude Inspector` /
  `Ollama` routes -- extend, do not replace.
- Do not change `typed_dispatch.ps1`'s core classification/assembly logic
  beyond what's needed to carry `codex_mode`, `impact_scope`, and governance
  fields through to TASK.md (3.1, 3.2, 3.6). It stays a planning-only
  script.
- Do not repurpose `hermes_claude_bridge.ps1` / `hermes_tripartite_bridge.ps1`
  as the packet-execution path if the direct-CLI option (3.3 option 2) is
  chosen -- leave them intact for their original ad-hoc smoke-test purpose.
- Do not hardcode a `--sandbox` flag value for Codex build mode without first
  confirming it against the installed `codex` CLI's actual accepted values.

## 5. Verification Checklist (8 items, run before declaring complete)

1. Dry-run: a `CODEX_VERIFY` TASK.md and a `CLAUDE_WORKER` TASK.md both route
   correctly and produce `OUTPUTS/RESULT.md` with no models invoked,
   confirming no accidental live calls during structural testing.
2. Confirm a TASK.md missing `governance_version`/`governance_hash` is
   rejected by `dispatch_task_packet.ps1` with a clear, distinct error (not
   the generic gate failure).
3. Confirm a dispatch with `dispatch_status: approval_required` and no
   approval evidence is blocked before any CLI is invoked.
4. Confirm a dispatch with `dispatch_status: ready_to_route` (post-approval)
   but `requires_josh_approval: true` still on the decision file is **not**
   blocked -- this is the specific regression this spec exists to prevent.
5. Confirm a `CODEX_BUILD` dispatch and a `CODEX_VERIFY` dispatch invoke
   Codex with different, correct sandbox modes.
6. Confirm a `codex_mode: build` + `impact_scope: client_facing` dispatch
   produces exactly one `CLAUDE_REVIEW` child, and that re-running the check
   against the same completed dispatch does not create a second one.
7. Confirm a `CLAUDE_REVIEW` dispatch's own completion never spawns another
   `CLAUDE_REVIEW`.
8. Confirm `data\live_bridge\...` output (if the bridge scripts are still
   used per 3.3 option 1) is mirrored into
   `data\codex_tasks\<DispatchId>\OUTPUTS\RESULT.md` in the unified schema
   from 3.5.

## Boundaries

- Work only inside E:\AgentOS.
- Read every file referenced above before changing it; re-verify line
  numbers and behavior against the live content, not this spec's quotes.
- Do not contact external services or clients.
- Do not delete evidence.
- Do not commit or push.
- Preserve unrelated user changes.
- Confirm the `codex` CLI's actual `--sandbox` flag values before
  hardcoding anything for build mode.
- Verify any modifications and report per AGENTS.md's completion-report
  requirements (artifact path, actual changes, verification evidence,
  unresolved risks, next steps).

## Output

Write results to:
`E:\AgentOS\data\codex_tasks\2026-07-02-dispatcher-upgrade-spec\OUTPUTS\RESULT.md`

Include, per the unified schema defined in section 3.5 above:
- dispatch_id, route_to, codex_mode, governance_version, governance_hash
- status, models_invoked, scripts_executed, cleanup_executed
- findings (what was actually changed, file by file)
- caveats (known gaps, anything from the 8-item checklist not fully verified)
- recommended next steps


## 進度與實際變更

尚未產生 RESULT.md。
